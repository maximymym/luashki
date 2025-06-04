local hoodwink = {}

--#region UI
local tab = Menu.Create("Heroes", "Hero List", "Hoodwink Combo")
local group = tab:Create("Main")
local ui = {}
ui.enabled = group:Switch("Enable Script", true, "\u{f0e7}")
ui.hotkey = group:Bind("Combo Key", Enum.ButtonCode.KEY_NONE)
--#endregion UI

local castState = 0
local nextTime = 0
local target = nil
local W_SPEED = 1500 -- approximate projectile speed of Bushwhack
local Q_SPEED = 2500 -- approximate projectile speed of Acorn Shot

local function PredictPosition(t, speed)
    if not t then return nil end
    local origin = Entity.GetAbsOrigin(t)
    local dir = Entity.GetAbsRotation(t):GetForward():Normalized()
    local ms = NPC.GetMoveSpeed(t)
    local hero = GetMyHero()
    if not hero then return origin end
    local distance = (origin - Entity.GetAbsOrigin(hero)):Length2D()
    local travel = distance / speed
    return origin + dir * ms * travel
end

local function GetMyHero()
    return Heroes.GetLocal()
end

local function FindTarget(range)
    local cursor = Input.GetWorldCursorPos()
    local me = GetMyHero()
    if not me then return nil end
    local best, bestDist = nil, range
    for _, hero in pairs(Heroes.GetAll()) do
        if not Entity.IsSameTeam(hero, me) and Entity.IsAlive(hero) and not NPC.IsIllusion(hero) then
            local dist = (Entity.GetAbsOrigin(hero) - cursor):Length2D()
            if dist < bestDist then
                bestDist = dist
                best = hero
            end
        end
    end
    return best
end

function hoodwink.OnUpdate()
    if not ui.enabled:Get() then return end

    local hero = GetMyHero()
    if not hero or NPC.GetUnitName(hero) ~= "npc_dota_hero_hoodwink" or not Entity.IsAlive(hero) then
        return
    end

    local w = NPC.GetAbility(hero, "hoodwink_bushwhack")
    local q = NPC.GetAbility(hero, "hoodwink_acorn_shot")
    if not w or not q then return end

    local now = os.clock()

    if castState == 0 then
        if ui.hotkey:IsDown() then
            target = FindTarget(1000)
            if target and Ability.IsCastable(w, NPC.GetMana(hero)) then
                local pos = PredictPosition(target, W_SPEED)
                Ability.CastPosition(w, pos)
                castState = 1
                nextTime = now + 0.1
            end
        end
    elseif castState == 1 then
        if now >= nextTime then
            if target and Ability.IsCastable(q, NPC.GetMana(hero)) then
                local pos = PredictPosition(target, Q_SPEED)
                Ability.CastPosition(q, pos)
            end
            castState = 0
            target = nil
        end
    end
end

return hoodwink
