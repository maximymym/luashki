-- Pick Analyzer Lua Script
local debug = {}

-- Меню и UI
local tab = Menu.Create("General", "Main", "Pick Analyzer")
local counterpick_group = tab:Create("Main"):Create("Pick Analyzer")
tab:Icon("\u{e2ca}")
ui = ui or {}
ui.team = ui.team or {}
ui.team.show_opponents   = counterpick_group:Switch("Показать контрпики", false)
ui.team.show_opponents:Icon("\u{f00c}")
ui.team.hero_count       = counterpick_group:Slider("Количество героев", 2, 15, 10)
ui.team.hero_count:Icon("\u{f0c0}")
ui.team.counterButtons   = {}
ui.team.lastHeroes       = {}
ui.team.meta_heroes      = {}

-- Логирование единоразово
local logged_bans  = {}
local logged_skips = {}

-- MultiSelect для позиций с картинками
ui.team.position_filter = counterpick_group:MultiSelect(
  "Позиция", {
    {"All","panorama/images/rank_tier_icons/handicap/handicap_background_png.vtex_c",true },
    {"Carry","panorama/images/rank_tier_icons/handicap/safelaneicon_psd.vtex_c",false },
    {"Middle","panorama/images/rank_tier_icons/handicap/midlaneicon_psd.vtex_c",false },
    {"Offlaine","panorama/images/rank_tier_icons/handicap/offlaneicon_psd.vtex_c",false },
    {"Support","panorama/images/rank_tier_icons/handicap/softsupporticon_psd.vtex_c",false },
    {"Full Support","panorama/images/rank_tier_icons/handicap/hardsupporticon_psd.vtex_c",false },
  },
  true
)

ui.team.position_filter:Icon("\u{f00d}")
ui.team.position_filter:OneItemSelection(true)

-- === 1) Словари для позиций и рангов ===
local positionValues = {
	[1] = "all-pick",
	[2] = "core-safe",
	[3] = "core-mid",
	[4] = "core-off",
	[5] = "support-safe",
	[6] = "support-off",
  }
  
  local rankKeys = {
	"All","Herald","Guardian","Crusader","Archon","Legend","Ancient","Divine","Immortal"
  }
  local rankToSlug = {
	All      = "",
	Herald   = "herald",
	Guardian = "guardian",
	Crusader = "crusader",
	Archon   = "archon",
	Legend   = "legend",
	Ancient  = "ancient",
	Divine   = "divine",
	Immortal = "immortal",
  }
  
  -- === 2) Новый MultiSelect для рангов (рядом с позицией) ===
  ui.team.rank_filter = counterpick_group:MultiSelect(
	"Ранг", {
	  {"All",      "panorama/images/rank_tier_icons/rank0_psd.vtex_c", true },
	  {"Herald",   "panorama/images/rank_tier_icons/rank1_psd.vtex_c",            false},
	  {"Guardian", "panorama/images/rank_tier_icons/rank2_psd.vtex_c",          false},
	  {"Crusader", "panorama/images/rank_tier_icons/rank3_psd.vtex_c",          false},
	  {"Archon",   "panorama/images/rank_tier_icons/rank4_psd.vtex_c",            false},
	  {"Legend",   "panorama/images/rank_tier_icons/rank5_psd.vtex_c",            false},
	  {"Ancient",  "panorama/images/rank_tier_icons/rank6_psd.vtex_c",           false},
	  {"Divine",   "panorama/images/rank_tier_icons/rank7_psd.vtex_c",            false},
	  {"Immortal", "panorama/images/rank_tier_icons/rank8a_psd.vtex_c",          false},
	},
	true
  )
  ui.team.rank_filter:OneItemSelection(true)
  ui.team.rank_filter:Icon("\u{f06d}")

-- Преобразование slug ↔ ID
local slug_to_id = {}
do
  for id = 0, 1000 do
    local name = Engine.GetHeroNameByID(id)
    if name and #name > 0 then
      local slug = name:gsub("^npc_dota_hero_", ""):gsub("_", "-")
      slug_to_id[slug] = id
    end
  end
end

local image_slug_overrides = {
  underlord = "abyssal_underlord", centaur_warrunner = "centaur",
  anti_mage = "antimage", doom = "doom_bringer", natures_prophet = "furion",
  lifestealer = "life_stealer", magnus = "magnataur", necrophos = "necrolyte",
  shadow_fiend = "nevermore", outworld_destroyer = "obsidian_destroyer",
  queen_of_pain = "queenofpain", clockwerk = "rattletrap", timbersaw = "shredder",
  wraith_king = "skeleton_king", treant_protector = "treant",
  vengeful_spirit = "vengefulspirit", windranger = "windrunner",
  io = "wisp", zeus = "zuus"
}

local function GetInternalForImage(hero_slug)
  local key = hero_slug:gsub("-","_")
  local override = image_slug_overrides[key]
  if override then
    return "npc_dota_hero_" .. override
  end
  local id = slug_to_id[hero_slug]
  if id then return Engine.GetHeroNameByID(id) end
  return "npc_dota_hero_" .. key
end

-- Парсинг контрпиков и меты
local function parse_counters_section(html)
  local block = html:match("Невыгодное положение.-Обновлено") or ""
  local list = {}
  for slug, val in block:gmatch('href=".-/heroes/([%w%-]+)".-([%-]?[%d%.]+)%%') do
    list[slug] = tonumber(val)
  end
  return list
end

local function parse_meta_heroes(html)
  local heroes = {}
  local block = html:match("Позиция.-Последнее") or ""
  local seen = {}
  for slug in block:gmatch('href=".-/heroes/([%w%-]+)"') do
    if not seen[slug] then table.insert(heroes, slug); seen[slug] = true end
    if #heroes >= 25 then break end
  end
  return heroes
end

-- Получаем забаненных героев с логом
local function get_banned_hero_slugs()
  local bans = {}
  local banned = GameRules.GetBannedHeroes()
  if banned then
    for _, id in pairs(banned) do
      if id and id > 0 then
        local name = Engine.GetHeroNameByID(id)
        if name and #name > 0 then
          local slug = name:gsub("^npc_dota_hero_", ""):gsub("_", "-")
          bans[slug] = true
          if not logged_bans[slug] then
            logged_bans[slug] = true
            Log.Write(string.format("[Pick Analyzer] Banned hero: %s", slug))
          end
        end
      end
    end
  end
  return bans
end

-- Получаем уже выбранных героев
local function get_picked_hero_slugs()
  local picks = {}
  for i = 0, Players.Count() - 1 do
    local ply = Players.Get(i)
    if ply then
      local data = Player.GetTeamData(ply)
      if data and data.selected_hero_id then
        local name = Engine.GetHeroNameByID(data.selected_hero_id)
        if name and #name > 0 then
          local slug = name:gsub("^npc_dota_hero_", ""):gsub("_", "-")
          picks[slug] = true
        end
      end
    end
  end
  return picks
end

-- Фильтрация с учётом MultiSelect:Get(itemId)
local positionKeys = {"All","Carry","Middle","Offlaine","Support","Full Support"}
local positionToIndex = { All = 1, Carry = 2, Middle = 3, Offlaine = 4, Support = 5, ["Full Support"] = 6 }
local function filter_available_heroes(counter_scores)
	local bans   = get_banned_hero_slugs()
	local picks  = get_picked_hero_slugs()
	local res    = {}
	local function skip(hero, reason)
	  local key = hero .. "|" .. reason
	  if not logged_skips[key] then
		logged_skips[key] = true
		Log.Write(string.format("[Pick Analyzer] Hero %s skipped (%s)", hero, reason))
	  end
	end
  
	-- Собираем набор «meta» героев по выбранным позициям и рангам
	local allowed   = {}
	local selPos    = ui.team.position_filter:ListEnabled()  -- e.g. {"All"} или {"Carry","Middle"}
	local selRanks  = ui.team.rank_filter:ListEnabled()      -- e.g. {"All"} или {"Legend"}
  
	local function add_meta(cacheKey)
	  local list = ui.team.meta_heroes[cacheKey]
	  if list then
		for _, slug in ipairs(list) do
		  allowed[slug] = true
		end
	  end
	end
  
	-- Если выбрана «All» по позициям, обходим все реальные позиции
	if #selPos == 1 and selPos[1] == "All" then
	  for _, posKey in ipairs(positionKeys) do
		if posKey ~= "All" then
		  local idx = positionToIndex[posKey]
		  for _, rankKey in ipairs(selRanks) do
			local rankSlug = rankToSlug[rankKey] or ""
			local cacheKey = idx .. "_" .. (rankSlug ~= "" and rankSlug or "all")
			add_meta(cacheKey)
		  end
		end
	  end
  
	else
	  -- Иначе — по каждой выбранной позиции
	  for _, posKey in ipairs(selPos) do
		if posKey ~= "All" then
		  local idx = positionToIndex[posKey]
		  for _, rankKey in ipairs(selRanks) do
			local rankSlug = rankToSlug[rankKey] or ""
			local cacheKey = idx .. "_" .. (rankSlug ~= "" and rankSlug or "all")
			add_meta(cacheKey)
		  end
		end
	  end
	end
  
	-- Если meta‑фильтр пуст (нет данных), разрешаем всё
	if not next(allowed) then
	  for h in pairs(counter_scores) do
		allowed[h] = true
	  end
	end
  
	-- Применяем итоговый фильтр с учётом банов и уже пикнутых героев
	for hero, score in pairs(counter_scores) do
	  if allowed[hero] then
		if not bans[hero] and not picks[hero] then
		  res[hero] = score
		else
		  skip(hero, bans[hero] and "banned" or "picked")
		end
	  end
	end
  
	return res
  end
  

-- HTTP-запросы для мета-героев и контрпиков
local dotabuff_base = "https://ru.dotabuff.com/heroes/"
local headers = { ["User-Agent"] = "Umbrella/1.0" }
local fetched_counters = {}
local scraped_counters = {}

-- глобально
-- === 1) Храним мету по ключу positionIndex_rankSlug ===
ui.team.meta_heroes = {}   -- вместо массива по idx

-- Кеш, чтобы не дергать одну и ту же пару дважды
local fetched_meta = {}

local function fetch_meta_heroes(idx, rankSlug)
  local cacheKey = idx .. "_" .. (rankSlug ~= "" and rankSlug or "all")
  if fetched_meta[cacheKey] then return end
  fetched_meta[cacheKey] = true

  local url = string.format(
    "%s?show=facets&view=meta&mode=all-pick&date=7d&position=%s%s",
    dotabuff_base,
    positionValues[idx],                                   -- ваш словарь позиций
    (rankSlug ~= "") and ("&rankTier="..rankSlug) or ""
  )

  HTTP.Request("GET", url, { headers = headers },
    function(r)
      ui.team.meta_heroes[cacheKey] = parse_meta_heroes(r.response or "")
    end,
    "meta_heroes_" .. cacheKey
  )
end

local function fetch_opponent_counters(internal)
  local slug = internal:gsub("npc_dota_hero_", ""):gsub("_", "-")
  if fetched_counters[slug] then return end
  fetched_counters[slug] = true
  scraped_counters[slug] = {}

  HTTP.Request("GET", dotabuff_base..slug.."/counters", { headers = headers }, function(r)
    scraped_counters[slug] = parse_counters_section(r.response or "")
  end, slug .. "_counters")
end


-- Вспомогательная проверка списков
local function lists_equal(a, b)
  if #a ~= #b then return false end
  for i=1,#a do if a[i] ~= b[i] then return false end end
  return true
end

-- Процесс рекомендаций
local function process_and_recommend()
	if not ui.team.show_opponents:Get() then
	  for _, btn in ipairs(ui.team.counterButtons) do btn:Visible(false) end
	  return
	end
  
	local me = Players.GetLocal()
	if not me then return end
  
	local slot = Player.GetPlayerSlot(me)
	local team = (slot < 5) and Enum.TeamNum.TEAM_RADIANT or Enum.TeamNum.TEAM_DIRE
	local enemy = (team == Enum.TeamNum.TEAM_RADIANT) and Enum.TeamNum.TEAM_DIRE or Enum.TeamNum.TEAM_RADIANT
  
	-- Сюда будем складывать только корректные internal-имена
	local opponents = {}
  
	for i = 0, Players.Count() - 1 do
	  local ply = Players.Get(i)
	  if ply then
		local s = Player.GetPlayerSlot(ply)
		local t = (s < 5) and Enum.TeamNum.TEAM_RADIANT or Enum.TeamNum.TEAM_DIRE
		if t == enemy then
		  local data = Player.GetTeamData(ply)
		  
		  -- 1) Берём hero_id и проверяем, что он есть и > 0
		  local hero_id = data and data.selected_hero_id
		  if hero_id and hero_id > 0 then
			-- 2) Запрашиваем internal-имя и убеждаемся, что оно не nil и не пустое
			local internal = Engine.GetHeroNameByID(hero_id)
			if internal and #internal > 0 then
			  table.insert(opponents, internal)
			  fetch_opponent_counters(internal)
			end
		  end
		end
	  end
	end
  
	-- 3) Если никто из оппонентов ещё не пикнул, прерываем функцию
	if #opponents == 0 then
	  for _, btn in ipairs(ui.team.counterButtons) do btn:Visible(false) end
	  return
	end
  
	-- Дальше — старая логика подсчёта и фильтрации
	local scores = {}
	for _, internal in ipairs(opponents) do
	  local slug = internal:gsub("npc_dota_hero_", ""):gsub("_", "-")
	  for h, v in pairs(scraped_counters[slug] or {}) do
		scores[h] = (scores[h] or 0) + v
	  end
	end
  
	local filtered = filter_available_heroes(scores)
	local sorted = {}
	for h, v in pairs(filtered) do
	  table.insert(sorted, { hero = h, score = v })
	end
	table.sort(sorted, function(a, b) return a.score > b.score end)
  
	local count = ui.team.hero_count:Get()
	local heroes = {}
	for i = 1, math.min(count, #sorted) do
	  heroes[i] = sorted[i].hero
	end
  
	if not lists_equal(heroes, ui.team.lastHeroes) then
	  ui.team.lastHeroes = heroes
	  for _, btn in ipairs(ui.team.counterButtons) do btn:Visible(false) end
	  ui.team.counterButtons = {}
		for i, slug in ipairs(heroes) do
			-- Получаем внутреннее имя через GetInternalForImage (с учётом overrides)
			local internal = GetInternalForImage(slug)
		
			-- Получаем отображаемое имя для кнопки
			local display_name = GameLocalizer.FindNPC(internal)
			if not display_name or display_name == "" then
			display_name = slug:gsub("-", " ")
			end
			display_name = display_name:sub(1,1):upper() .. display_name:sub(2)
		
			-- Создаём кнопку, в колбэке используем suggest_hero_pick с internal
			local btn = counterpick_group:Button(display_name, function()
			Engine.ExecuteCommand("suggest_hero_pick " .. internal:gsub("npc_dota_hero_", "") .. " 0")
			end)
		
			-- Настраиваем изображение кнопки и подсказку
			pcall(function()
			btn:Image("panorama/images/heroes/" .. internal .. "_png.vtex_c")
			end)
			btn:ToolTip(string.format("Контрпик: %.1f%%", sorted[i].score))
			btn:Visible(true)
			table.insert(ui.team.counterButtons, btn)
		end
	end
  end
  

-- Обновление каждый кадр
debug.OnUpdateEx = function()
	local selRanks = ui.team.rank_filter:ListEnabled()       -- e.g. {"All"} или {"Legend"}
	for _, posKey in ipairs(positionKeys) do
	  if posKey ~= "All" and ui.team.position_filter:Get(posKey) then
		local idx = positionToIndex[posKey]
		for _, rankKey in ipairs(selRanks) do
		  local rankSlug = rankToSlug[rankKey] or ""         -- ваш словарь рангов
		  fetch_meta_heroes(idx, rankSlug)
		end
	  end
	end
	process_and_recommend()
  end

return debug