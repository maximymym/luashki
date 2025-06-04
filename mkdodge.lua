local script = {}
local myHero = nil
local lastFortifyTime = 0
local FORTIFY_COOLDOWN = 5  -- минимальный интервал между активациями (секунд)

--#region UI
local tab = Menu.Create("Scripts", "User Scripts", "Auto Fortify")
tab:Icon("\u{f00c}")
local group = tab:Create("Settings"):Create("Group")

local ui = {}
ui.enabled = group:Switch("Enable Auto Fortify", true, "\u{f00c}")
ui.tickThreshold = group:Slider("Tick Threshold", 1, 12, 10, function (value)
    if value == 0 then return "Disabled" end
    return tostring(value)
end)
--#endregion UI

-- Функция для получения локального героя (если он ещё не получен)
local function GetMyHero()
    if not myHero then
        myHero = Heroes.GetLocal()
    end
    return myHero
end

-- Функция для проверки, находится ли по линии удара Monkey King хотя бы один союзный крип
local function IsAllyCreepOnLine(mkHero, refHero)
    local mkPos = Entity.GetAbsOrigin(mkHero)
    local refPos = Entity.GetAbsOrigin(refHero)
    local dir = (refPos - mkPos):Normalized()  -- направление от Monkey King к нашему герою
    local maxLength = 1250       -- приблизительная дальность действия Boundless Strike
    local halfWidth = 150        -- половина допустимой ширины линии удара

    local creeps = NPCs.GetAll(function(npc)
        return NPC.IsLaneCreep(npc) and Entity.IsSameTeam(npc, refHero) and Entity.IsAlive(npc)
    end)

    for _, creep in pairs(creeps) do
        local creepPos = Entity.GetAbsOrigin(creep)
        local vecToCreep = creepPos - mkPos
        local proj = vecToCreep:Dot(dir)  -- проекция вектора на направление удара
        local perp = (vecToCreep - (dir * proj)):Length()  -- поперечное отклонение от линии
        if proj > 0 and proj < maxLength and perp < halfWidth then
            return true
        end
    end

    return false
end

-- Функция для активации Glyph (Fortify)
local function ActivateFortify()
    local now = GameRules.GetGameTime()
    if now - lastFortifyTime < FORTIFY_COOLDOWN then
        return false  -- если Glyph недавно активирован, выходим
    end

    Player.PrepareUnitOrders(
        Players.GetLocal(),
        Enum.UnitOrder.DOTA_UNIT_ORDER_GLYPH,
        nil, nil, nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        myHero
    )
    lastFortifyTime = now
    print("Fortify activated!")
    return true
end

local castData = {}  -- Таблица для хранения данных кастования для каждого enemy

function script.OnUpdate()
    if not ui.enabled:Get() then
        return
    end

    local hero = GetMyHero()
    if not hero or not Entity.IsAlive(hero) then
        return
    end

    for _, enemy in pairs(Heroes.GetAll()) do
        if not Entity.IsSameTeam(hero, enemy) and Entity.IsAlive(enemy) then
            -- Сначала проверяем наличие модификатора Jingu Mastery
            if NPC.HasModifier(enemy, "modifier_monkey_king_quadruple_tap_bonuses") then
                -- Затем убеждаемся, что это Monkey King
                if NPC.GetUnitName(enemy) == "npc_dota_hero_monkey_king" then
                    local ability = NPC.GetAbility(enemy, "monkey_king_boundless_strike")
                    if ability and Ability.IsInAbilityPhase(ability) then
                        if not castData[enemy] then
                            castData[enemy] = { tickCount = 0, fortifyActivated = false }
                        end
                        castData[enemy].tickCount = castData[enemy].tickCount + 1
                        print("Monkey King casting tick: " .. castData[enemy].tickCount)
                        
                        if castData[enemy].tickCount >= ui.tickThreshold:Get() and not castData[enemy].fortifyActivated then
                            if IsAllyCreepOnLine(enemy, hero) then
                                ActivateFortify()
                                castData[enemy].fortifyActivated = true
                            end
                        end
                    else
                        castData[enemy] = nil
                    end
                else
                    castData[enemy] = nil
                end
            else
                -- Если у enemy нет нужного модификатора, сбрасываем данные
                castData[enemy] = nil
            end
        end
    end
end

return script
