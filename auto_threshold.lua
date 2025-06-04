local script = {}

-- Создание переключателей для каждого героя
local oracle_menu = Menu.Find("Heroes", "Hero List", "Oracle", "Auto Usage", "False Promise")
if oracle_menu then
    local switch = oracle_menu:Switch("AI Threshold", false)
    switch:Icon("\u{f72b}")
end

local dazzle_menu = Menu.Find("Heroes", "Hero List", "Dazzle", "Main Settings", "Shallow Grave")
if dazzle_menu then
    local switch = dazzle_menu:Switch("AI Threshold", false)
    switch:Icon("\u{f72b}")
end

-- Функция для получения текущего уровня героя
local function GetHeroLevel()
    local hero = Heroes.GetLocal()
    if not hero then return 1 end
    return NPC.GetCurrentLevel(hero)
end

-- Функция для установки порогового значения HP
local function SetHPThreshold(hero_name, threshold)
    if hero_name == "npc_dota_hero_oracle" then
        local menu = Menu.Find("Heroes", "Hero List", "Oracle", "Auto Usage", "False Promise", "HP% Threshold")
        if menu then
            menu:Set(threshold)
        end
    elseif hero_name == "npc_dota_hero_dazzle" then
        local menu = Menu.Find("Heroes", "Hero List", "Dazzle", "Main Settings", "Shallow Grave", "HP Threshold")
        if menu then
            menu:Set(threshold)
        end
    end
end

-- Функция для проверки включен ли AI Threshold
local function IsAIThresholdEnabled(hero_name)
    if hero_name == "npc_dota_hero_oracle" then
        local menu = Menu.Find("Heroes", "Hero List", "Oracle", "Auto Usage", "False Promise", "AI Threshold")
        return menu and menu:Get()
    elseif hero_name == "npc_dota_hero_dazzle" then
        local menu = Menu.Find("Heroes", "Hero List", "Dazzle", "Main Settings", "Shallow Grave", "AI Threshold")
        return menu and menu:Get()
    end
    return false
end

-- Функция для расчета порогового значения на основе уровня
local function CalculateThreshold(level)
    -- Линейная интерполяция от 20 до 30 в зависимости от уровня (1-18)
    local min_level = 1
    local max_level = 18
    local min_threshold = 20
    local max_threshold = 30
    
    -- Ограничиваем уровень в допустимом диапазоне
    level = math.max(min_level, math.min(max_level, level))
    
    -- Вычисляем пороговое значение и округляем до целого числа
    local threshold = math.floor(min_threshold + (max_threshold - min_threshold) * (level - min_level) / (max_level - min_level))
    return threshold
end

-- Основная функция обновления
function script.OnUpdate()
    local hero = Heroes.GetLocal()
    if not hero then return end
    
    local hero_name = NPC.GetUnitName(hero)
    if hero_name ~= "npc_dota_hero_oracle" and hero_name ~= "npc_dota_hero_dazzle" then return end
    
    -- Проверяем, включен ли AI Threshold для текущего героя
    if not IsAIThresholdEnabled(hero_name) then return end
    
    local level = GetHeroLevel()
    local threshold = CalculateThreshold(level)
    
    if hero_name == "npc_dota_hero_oracle" then
        SetHPThreshold("npc_dota_hero_oracle", threshold)
    elseif hero_name == "npc_dota_hero_dazzle" then
        SetHPThreshold("npc_dota_hero_dazzle", threshold)
    end
end

-- Регистрация скрипта
function script.OnLoad()
    print("Auto Threshold script loaded!")
end

return script 