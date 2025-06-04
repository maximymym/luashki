local debug = {}

local tab = Menu.Create("General", "Debug", "Debug", "Debug")

--#region UI
local inworld_group               = tab:Create("In-World")
local callbacks_group             = tab:Create("Callbacks")
local inworld_settings_group      = tab:Create("In-World Settings", 1)
local callbacks_settings_group    = tab:Create("Callbacks Settings", 2)

-- ... (other UI switches) ...

--#region Team Data UI
local team_group = tab:Create("Team Data")
ui = ui or {}
ui.team = ui.team or {}
ui.team.show_opponents = team_group:Switch("Show Opponent Heroes", false)
--#endregion

--#region Helper: Process Opponent Team Data
local function process_team_data()
    if not ui.team.show_opponents:Get() then return end

    -- Local player and inferred team by slot
    local localPlayer = Players.GetLocal()
    if not localPlayer then return end
    local mySlot = Player.GetPlayerSlot(localPlayer)
    local myTeam = (mySlot < 5) and Enum.TeamNum.TEAM_RADIANT or Enum.TeamNum.TEAM_DIRE
    local enemyTeam = (myTeam == Enum.TeamNum.TEAM_RADIANT) and Enum.TeamNum.TEAM_DIRE or Enum.TeamNum.TEAM_RADIANT

    -- Iterate through all players on server
    for i = 0, Players.Count() - 1 do
        local ply = Players.Get(i)
        if ply then
            local plySlot = Player.GetPlayerSlot(ply)
            local plyTeam = (plySlot < 5) and Enum.TeamNum.TEAM_RADIANT or Enum.TeamNum.TEAM_DIRE
            if plyTeam == enemyTeam then
                local data = Player.GetTeamData(ply)
                if data then
                    local heroId      = data.selected_hero_id
                    local kills       = data.kills
                    local deaths      = data.deaths
                    local assists     = data.assists
                    local streak      = data.streak
                    local respawnTime = data.respawnTime

                    -- Resolve hero name if possible
                    local heroName = (Hero.GetNameById and Hero.GetNameById(heroId)) or tostring(heroId)

                    print(string.format(
                        "Opponent [Slot %d]: %s (ID %d) | K/D/A: %d/%d/%d | Streak: %d | Respawn: %ds",
                        plySlot, heroName, heroId, kills, deaths, assists, streak, respawnTime
                    ))
                end
            end
        end
    end
end
--#endregion

--#region Callbacks
function debug.OnUpdateEx()
    -- ... existing in-world logic ...
    process_team_data()
end


return debug
