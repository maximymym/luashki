local tab = Menu.Create("Scripts", "User Scripts", "AutoFarmer")
local group = tab:Create("Options"):Create("Main")

-- Бинды:
local botBind = group:Bind("Активировать Авто-фармер леса", Enum.ButtonCode.KEY_0, "panorama/images/spellicons/rattletrap_power_cogs_png.vtex_c")
local unitsPerCampSlider = group:Slider("Юнитов на 1 кемп", 1, 5, 1) -- Слайдер для выбора количества юнитов на кемп
local campsToQueueSlider = group:Slider("Кемпов в очередь", 1, 10, 3) -- Слайдер для выбора количества кемпов в очереди

-----------------------------------------------
-- Глобальные переменные управления ботом
-----------------------------------------------
local botActive = false
local wasBotBindPressed = false
local commandsQueued = false -- Флаг для отслеживания, были ли команды уже поставлены в очередь

-- Глобальный список уже назначенных кемпов для всех групп
local globalAssignedCamps = {}

-----------------------------------------------
-- Функции работы с Camp API
-----------------------------------------------
local function getBoxCenter(camp)
    if not camp then return nil end
    local box = Camp.GetCampBox(camp)
    if not box or not box.min or not box.max then return nil end
    local cx = (box.min:GetX() + box.max:GetX()) / 2
    local cy = (box.min:GetY() + box.max:GetY()) / 2
    local cz = (box.min:GetZ() + box.max:GetZ()) / 2
    return Vector(cx, cy, cz)
end

-- Функция для получения всех доступных кемпов
local function getAllAvailableCamps()
    local allCamps = Camps.GetAll()
    if not allCamps or #allCamps == 0 then return {} end
    
    local availableCamps = {}
    for i, camp in ipairs(allCamps) do
        local center = getBoxCenter(camp)
        if center then
            table.insert(availableCamps, {
                camp = camp,
                center = center,
                index = i
            })
        end
    end
    return availableCamps
end

-- Функция, которая находит ближайшие кемпы к указанной позиции
local function getNearestCamps(position, count, excludeCamps)
    local camps = getAllAvailableCamps()
    if #camps == 0 then return {} end
    
    -- Сортируем кемпы по расстоянию
    table.sort(camps, function(a, b)
        local distA = (a.center - position):Length2D()
        local distB = (b.center - position):Length2D()
        return distA < distB
    end)
    
    -- Выбираем необходимое количество ближайших кемпов, исключая те, что в excludeCamps
    local result = {}
    for _, camp in ipairs(camps) do
        if #result >= count then break end
        
        local exclude = false
        if excludeCamps then
            for _, excludeIdx in ipairs(excludeCamps) do
                if camp.index == excludeIdx then
                    exclude = true
                    break
                end
            end
        end
        
        if not exclude then
            table.insert(result, camp)
        end
    end
    
    return result
end

-----------------------------------------------
-- Функция для создания очереди команд на атаку кемпов для группы юнитов
-- Теперь команды сначала сохраняются в таблице, после чего таблица переворачивается.
-----------------------------------------------
local function queueCampCommands(units, startPosition, campsToQueue, excludeCamps)
    local player = Players.GetLocal()
    local orders = {}  -- Таблица для сохранения команд
    
    local numCamps = math.min(campsToQueueSlider:Get(), campsToQueue or 3)
    local currentPosition = startPosition
    
    for i = 1, numCamps do
        local nearestCamps = getNearestCamps(currentPosition, 1, excludeCamps)
        if #nearestCamps == 0 then break end
        
        local camp = nearestCamps[1]
        table.insert(excludeCamps, camp.index)
        
        table.insert(orders, {
            campIndex = camp.index,
            campCenter = camp.center
        })
        
        currentPosition = camp.center
        
        print(string.format("[AutoFarmer] Засечен кемп #%d (%.0f, %.0f)", 
            camp.index, camp.center:GetX(), camp.center:GetY()))
    end

    -- Переворачиваем таблицу команд
    local reversedOrders = {}
    for i = #orders, 1, -1 do
        table.insert(reversedOrders, orders[i])
    end

    -- Выдаем команды в обратном порядке
    for _, order in ipairs(reversedOrders) do
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
            nil,
            order.campCenter,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
            units,
            true,
            false,
            false,
            true,
            nil,
            true
        )
        print(string.format("[AutoFarmer] Группа юнитов отправлена на кемп #%d (%.0f, %.0f)", 
            order.campIndex, order.campCenter:GetX(), order.campCenter:GetY()))
    end

    -- Возвращаем список индексов кемпов (в исходном порядке)
    local usedCamps = {}
    for _, order in ipairs(orders) do
        table.insert(usedCamps, order.campIndex)
    end
    return usedCamps
end

-----------------------------------------------
-- Функция для инициализации и отправки юнитов фармить
-----------------------------------------------
local function startFarming()
    local player = Players.GetLocal()
    local units = Player.GetSelectedUnits(player) or {}
    if #units == 0 then
        print("[AutoFarmer] Нет выбранных юнитов.")
        return false
    end
    
    -- Очищаем глобальный список назначенных кемпов
    globalAssignedCamps = {}
    
    -- Количество юнитов в группе для каждого кемпа
    local unitsPerCamp = unitsPerCampSlider:Get()
    
    -- Группируем юнитов
    local unitGroups = {}
    for i = 1, #units, unitsPerCamp do
        local group = {}
        for j = i, math.min(i + unitsPerCamp - 1, #units) do
            table.insert(group, units[j])
        end
        table.insert(unitGroups, group)
    end
    
    -- Для каждой группы назначаем кемпы (одна группа получает единый маршрут)
    for _, group in ipairs(unitGroups) do
        local startPos = Entity.GetAbsOrigin(group[1])
        local usedCamps = queueCampCommands(group, startPos, campsToQueueSlider:Get(), globalAssignedCamps)
        for _, campIdx in ipairs(usedCamps) do
            table.insert(globalAssignedCamps, campIdx)
        end
    end
    
    commandsQueued = true
    print("[AutoFarmer] Команды поставлены в очередь, скрипт деактивирован.")
    
    return true
end

-----------------------------------------------
-- OnUpdate: основная логика авто-фарма
-----------------------------------------------
function OnUpdate()
    local player = Players.GetLocal()

    -- Обработка переключения бота
    local nowPressed = botBind:IsPressed()
    if nowPressed and not wasBotBindPressed then
        botActive = not botActive
        print("[AutoFarmer] Bot toggled:", botActive)
        
        if botActive then
            commandsQueued = false
        end
    end
    wasBotBindPressed = nowPressed

    if not botActive then return end
    
    if commandsQueued then
        botActive = false
        return
    end
    
    if startFarming() then
        botActive = false
    else
        print("[AutoFarmer] Не удалось поставить команды в очередь, выключаем бот.")
        botActive = false
    end
end

return {
    OnUpdate = OnUpdate
}
