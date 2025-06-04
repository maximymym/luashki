local Event = require("game_events")

-- ваш обработчик
local function OnHeroPick(evt)
    if Event.IsEmpty(evt) then return end
    local pid  = Event.GetInt(evt,    "player_id")
    local hero = Event.GetString(evt, "hero")        -- "npc_dota_hero_axe"
    local ply  = Players.GetPlayer(pid)
    if not ply then return end

    if Player.GetTeam(ply) ~= Player.GetTeam(Players.GetLocal()) then
        local shortName = hero:match("npc_dota_hero_(.+)")
        print(string.format("[AutoFarmer] Opponent picked: %s", shortName))
    end
end

-- теперь можно подписаться с двумя аргументами:
Event.AddListener("dota_player_pick_hero", OnHeroPick)
