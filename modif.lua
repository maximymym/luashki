local script = {}
local myHero = nil
local lastPrintTime = 0

--#region UI
local tab = Menu.Create("Modifier Debug", "Modifier Debug", "Modifier Debug")
tab:Icon("\u{f02d}")
local group = tab:Create("Settings"):Create("Group")

local ui = {}
ui.debugEnabled = group:Switch("Enable Modifier Debug", true, "\u{f00c}")
ui.printInterval = group:Slider("Print Interval (sec)", 1, 10, 5, function(value)
    return tostring(value)
end)
--#endregion UI

-- Функция для получения локального героя
local function GetMyHero()
    if not myHero then
        myHero = Heroes.GetLocal()
    end
    return myHero
end

-- Функция для преобразования модификатора в строку.
-- Если доступна функция Modifier.GetName, используем её; иначе пробуем поле name.
local function ModifierToString(mod)
    if type(mod) == "userdata" then
        if Modifier and Modifier.GetName then
            local name = Modifier.GetName(mod)
            if name and type(name) == "string" then
                return name
            end
        end
        if mod.name and type(mod.name) == "string" then
            return mod.name
        end
        return "<modifier>"
    else
        return tostring(mod)
    end
end

-- Функция для получения списка модификаторов героя.
-- Если доступна NPC.GetModifiers, используем её; иначе обходим через NPC.GetModifierCount.
local function GetModifiersList(hero)
    local modifiers = {}
    if NPC.GetModifiers then
        modifiers = NPC.GetModifiers(hero) or {}
    elseif NPC.GetModifierCount and NPC.GetModifier then
        local count = NPC.GetModifierCount(hero) or 0
        for i = 1, count do
            local mod = NPC.GetModifier(hero, i)
            if mod then
                table.insert(modifiers, mod)
            end
        end
    end
    return modifiers
end

function script.OnUpdate()
    if not ui.debugEnabled:Get() then 
        return 
    end

    local currentTime = GameRules.GetGameTime()
    if currentTime - lastPrintTime < ui.printInterval:Get() then
        return
    end
    lastPrintTime = currentTime

    for _, hero in pairs(Heroes.GetAll()) do
        local heroName = NPC.GetUnitName(hero) or "unknown"
        local team = Entity.GetTeamNum(hero) or 0
        local modifiers = GetModifiersList(hero)

        local modStrings = {}
        for i, mod in ipairs(modifiers) do
            modStrings[i] = ModifierToString(mod)
        end
        local modList = table.concat(modStrings, ", ")

        print(string.format("Hero: %s | Team: %d | Modifiers: %s", heroName, team, modList))
    end
end

return script
