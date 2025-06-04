local debug = {};
local tab = Menu.Create("General", "Main", "Pick Analyzer", "Pick Analyzer");
tab:Icon("\u{f1ce}");
local counterpick_group = tab:Create("Pick Analyzer");
ui = ui or {};
ui.team = ui.team or {};
ui.team.show_opponents = counterpick_group:Switch("Показать контрпики", false);
ui.team.position_filter = counterpick_group:Combo("Позиция", {"All","Carry","Middle","Offlaine","Support","Full Support"}, 0);
ui.team.hero_count = counterpick_group:Slider("Количество героев", 2, 15, 10);
ui.team.counterButtons = {};
ui.team.lastHeroes = {};
ui.team.meta_heroes = {};
ui.team.last_position = 0;
local function lists_equal(a, b)
	if (#a ~= #b) then
		return false;
	end
	for i = 1, #a do
		if (a[i] ~= b[i]) then
			return false;
		end
	end
	return true;
end
local function capitalize_first_letter(str)
	if (not str or (str == "")) then
		return str;
	end
	return str:sub(1, 1):upper() .. str:sub(2);
end
local slug_to_id = {};
do
	for id = 0, 1000 do
		local name = Engine.GetHeroNameByID(id);
		if (name and (name ~= "")) then
			local slug = name:gsub("^npc_dota_hero_", ""):gsub("_", "-");
			slug_to_id[slug] = id;
		end
	end
end
local image_slug_overrides = {underlord="abyssal_underlord",centaur_warrunner="centaur",anti_mage="antimage",doom="doom_bringer",natures_prophet="furion",lifestealer="life_stealer",magnus="magnataur",necrolyte="necrophos",shadow_fiend="nevermore",outworld_destroyer="obsidian_destroyer",queen_of_pain="queenofpain",clockwerk="rattletrap",timbersaw="shredder",wraith_king="skeleton_king",treant_protector="treant",vengeful_spirit="vengefulspirit",windranger="windrunner",io="wisp",zeus="zuus"};
local function GetInternalForImage(hero_slug)
	local key = hero_slug:gsub("-", "_");
	local engine_suffix = image_slug_overrides[key];
	if engine_suffix then
		return "npc_dota_hero_" .. engine_suffix;
	end
	local id = slug_to_id[hero_slug];
	if id then
		return Engine.GetHeroNameByID(id);
	end
	return "npc_dota_hero_" .. key;
end
local dotabuff_url_base = "https://ru.dotabuff.com/heroes/";
local headers = {["User-Agent"]="Umbrella/1.0",Connection="Keep-Alive"};
local scraped_counters, fetched_counters = {}, {};
local position_urls = {[0]="https://ru.dotabuff.com/heroes?show=heroes&view=meta&mode=all-pick&date=7d&position=",[1]="https://ru.dotabuff.com/heroes?show=heroes&view=meta&mode=all-pick&date=7d&position=core-safe",[2]="https://ru.dotabuff.com/heroes?show=heroes&view=meta&mode=all-pick&date=7d&position=core-mid",[3]="https://ru.dotabuff.com/heroes?show=heroes&view=meta&mode=all-pick&date=7d&position=core-off",[4]="https://ru.dotabuff.com/heroes?show=heroes&view=meta&mode=all-pick&date=7d&position=support-safe",[5]="https://ru.dotabuff.com/heroes?show=heroes&view=meta&mode=all-pick&date=7d&position=support-off"};
local function parse_counters_section(html)
    local block = html:match("Невыгодное положение.-Обновлено") or ""
    local list = {}
    for hero_slug, val in block:gmatch('href=".-/heroes/([%w%-]+)".-([%-]?[%d%.]+)%%') do
        list[hero_slug] = tonumber(val)
    end
    return list
end
local function parse_meta_heroes(html)
	local heroes = {};
	local block = html:match("Позиция.-Последнее") or "";
	local count = 0;
	for hero_slug in block:gmatch('href=".-/heroes/([%w%-]+)"') do
		if ((count < 25) and not heroes[hero_slug]) then
			heroes[hero_slug] = true;
			table.insert(heroes, hero_slug);
			count = count + 1;
		end
	end
	return heroes;
end
local function fetch_meta_heroes(position_index)
	local url = position_urls[position_index];
	if not url then
		return;
	end
	HTTP.Request("GET", url, {headers=headers}, function(r)
		ui.team.meta_heroes[position_index] = parse_meta_heroes(r.response or "");
	end, "meta_heroes_" .. position_index);
end
local function fetch_opponent_counters(internal_name)
	local slug = internal_name:gsub("^npc_dota_hero_", ""):gsub("_", "-");
	if fetched_counters[slug] then
		return;
	end
	fetched_counters[slug] = true;
	scraped_counters[slug] = {};
	HTTP.Request("GET", dotabuff_url_base .. slug .. "/counters", {headers=headers}, function(r)
		scraped_counters[slug] = parse_counters_section(r.response or "");
	end, slug .. "_counters");
end
local function fetch_all_meta_heroes()
	for i = 0, 5 do
		fetch_meta_heroes(i);
	end
end
local function filter_by_position(counter_scores)
	local position = ui.team.position_filter:Get();
	if ((position == 0) or not ui.team.meta_heroes[position]) then
		return counter_scores;
	end
	local filtered = {};
	for _, hero_slug in ipairs(ui.team.meta_heroes[position]) do
		if counter_scores[hero_slug] then
			filtered[hero_slug] = counter_scores[hero_slug];
		end
	end
	return filtered;
end
local function process_and_recommend()
	local current_position = ui.team.position_filter:Get();
	if (current_position ~= ui.team.last_position) then
		if not ui.team.meta_heroes[current_position] then
			fetch_meta_heroes(current_position);
		end
		ui.team.last_position = current_position;
	end
	if not ui.team.show_opponents:Get() then
		for _, b in ipairs(ui.team.counterButtons) do
			b:Visible(false);
		end
		return;
	end
	local me = Players.GetLocal();
	if not me then
		return;
	end
	local slot = Player.GetPlayerSlot(me);
	local team = ((slot < 5) and Enum.TeamNum.TEAM_RADIANT) or Enum.TeamNum.TEAM_DIRE;
	local enemy = ((team == Enum.TeamNum.TEAM_RADIANT) and Enum.TeamNum.TEAM_DIRE) or Enum.TeamNum.TEAM_RADIANT;
	local opponents = {};
	for i = 0, Players.Count() - 1 do
		local ply = Players.Get(i);
		if ply then
			local s = Player.GetPlayerSlot(ply);
			local t = ((s < 5) and Enum.TeamNum.TEAM_RADIANT) or Enum.TeamNum.TEAM_DIRE;
			if (t == enemy) then
				local data = Player.GetTeamData(ply);
				if (data and data.selected_hero_id) then
					local internal = Engine.GetHeroNameByID(data.selected_hero_id);
					if (internal and (internal ~= "")) then
						table.insert(opponents, internal);
						fetch_opponent_counters(internal);
					end
				end
			end
		end
	end
	local counter_scores = {};
	for _, internal in ipairs(opponents) do
		local slug = internal:gsub("^npc_dota_hero_", ""):gsub("_", "-");
		for hero_slug, adv in pairs(scraped_counters[slug] or {}) do
			counter_scores[hero_slug] = (counter_scores[hero_slug] or 0) + adv;
		end
	end
	counter_scores = filter_by_position(counter_scores);
	local sorted, heroes = {}, {};
	for h, score in pairs(counter_scores) do
		table.insert(sorted, {hero=h,score=score});
	end
	table.sort(sorted, function(a, b)
		return a.score > b.score;
	end);
	local hero_count = ui.team.hero_count:Get();
	for i = 1, math.min(hero_count, #sorted) do
		heroes[i] = sorted[i].hero;
	end
	if not lists_equal(heroes, ui.team.lastHeroes) then
		ui.team.lastHeroes = heroes;
		for _, b in ipairs(ui.team.counterButtons) do
			b:Visible(false);
		end
		ui.team.counterButtons = {};
		for i, hero_slug in ipairs(heroes) do
			local v = sorted[i];
			local internal = GetInternalForImage(hero_slug);
			local name = GameLocalizer.FindNPC(internal);
			if (name == "") then
				name = hero_slug:gsub("-", " ");
			end
			name = capitalize_first_letter(name);
			local btn = counterpick_group:Button(name, function()
				Log.Write("Selected counter hero: " .. name);
			end);
			pcall(function()
				btn:Image("panorama/images/heroes/" .. internal .. "_png.vtex_c");
			end);
			btn:Visible(true);
			btn:ToolTip(string.format("Контрпик: %.1f%%", v.score));
			table.insert(ui.team.counterButtons, btn);
		end
	end
end
fetch_all_meta_heroes();
debug.OnUpdateEx = function()
	process_and_recommend();
end;
return debug;