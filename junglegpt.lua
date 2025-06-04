-- auto_farm_camps_grouped_chain_debug.lua
-----------------------------------------------
-- Скрипт: Auto Farm Camps Grouped (цепочка кемпов) - версия с доработками
-- Логика:
-- 1. Выбранные (живые) юниты делятся на группы по значению "Максимальное количество юнитов на кэмп".
-- 2. Для каждой группы стартовая позиция берётся как средняя позиция юнитов (groupAnchor).
-- 3. Для каждого номера очереди (от 1 до значения Camp Queue) для группы ищется ближайший кемп относительно
--    группы (всегда от groupAnchor, чтобы избежать «скачков» цепочки).
-- 4. Кандидаты, уже выбранные (локально или глобально для этого номера) исключаются.
-- 5. Выдаётся цепочка ордеров: первый ордер выдаётся сразу, остальные – добавляются в очередь (queue=true, execute_fast=true).
-----------------------------------------------

local tab = Menu.Create("Scripts", "User Scripts", "AutoFarmCampsGroupedChain")
local group = tab:Create("Options"):Create("Main")

-- Биндинг для запуска скрипта
local botBind = group:Bind("Activate Farm Camps", Enum.ButtonCode.KEY_0, "panorama/images/spellicons/rattletrap_power_cogs_png.vtex_c")
-- Ползунок для количества кемпов (число ордеров в цепочке)
local campQueueSlider = group:Slider("Camp Queue", 1, 10, 3)
-- Ползунок для максимального количества юнитов на кэмп (размер группы)
local maxUnitsPerCampSlider = group:Slider("Максимальное количество юнитов на кэмп", 1, 10, 2)

----------------------------------------------------------
-- Вспомогательная функция: проверка наличия значения в таблице
----------------------------------------------------------
local function containsValue(tbl, value)
    for _, v in ipairs(tbl or {}) do
        if v == value then 
            return true 
        end
    end
    return false
end

----------------------------------------------------------
-- Функция для вычисления 2D-дистанции между двумя позициями
----------------------------------------------------------
local function getDistance2D(pos1, pos2)
    local dx = pos1:GetX() - pos2:GetX()
    local dy = pos1:GetY() - pos2:GetY()
    return math.sqrt(dx * dx + dy * dy)
end

----------------------------------------------------------
-- Функция получения центра кемпа через bounding box (используем проверенную логику)
----------------------------------------------------------
local function getBoxCenter(camp)
    if not camp then return nil end
    local box = Camp.GetCampBox(camp)
    if not box or not box.min or not box.max then return nil end
    local cx = (box.min:GetX() + box.max:GetX()) / 2
    local cy = (box.min:GetY() + box.max:GetY()) / 2
    local cz = (box.min:GetZ() + box.max:GetZ()) / 2
    return Vector(cx, cy, cz)
end

----------------------------------------------------------
-- Получение списка всех доступных кемпов (каждому присваивается уникальный индекс)
----------------------------------------------------------
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

----------------------------------------------------------
-- Функция, возвращающая ближайшие кемпы к позиции pos с учетом исключений.
-- Параметр excludeCamps – массив индексов кемпов, которые уже использованы.
----------------------------------------------------------
local function getNearestCamps(pos, count, excludeCamps)
    local camps = getAllAvailableCamps()
    if #camps == 0 then return {} end

    table.sort(camps, function(a, b)
        return getDistance2D(a.center, pos) < getDistance2D(b.center, pos)
    end)

    -- Выводим лог для отладки до 28 кандидатов
    for i, camp in ipairs(camps) do
        local d = getDistance2D(camp.center, pos)
        print(string.format("Candidate %d: индекс %d, дистанция %.2f", i, camp.index, d))
        if i >= 28 then break end
    end

    local result = {}
    for _, camp in ipairs(camps) do
        if not containsValue(excludeCamps, camp.index) then
            table.insert(result, camp)
            if #result >= count then break end
        end
    end

    if #result > 0 then
        local d = getDistance2D(result[1].center, pos)
        print(string.format("Выбран кемп с индексом %d на расстоянии %.2f от позиции (%.0f, %.0f, %.0f)",
            result[1].index, d, pos:GetX(), pos:GetY(), pos:GetZ()))
    end
    return result
end

----------------------------------------------------------
-- Вычисление средней (якорной) точки группы юнитов
----------------------------------------------------------
local function computeGroupAnchor(units)
    if not units or #units == 0 then 
        print("Ошибка: нет юнитов для вычисления центра")
        return nil
    end
    local sum = Vector(0, 0, 0)
    for _, unit in ipairs(units) do
        local pos = Entity.GetAbsOrigin(unit)
        if pos then
            sum = sum + pos
        else
            print("Предупреждение: не удалось получить позицию юнита")
        end
    end
    local anchor = sum / #units
    print(string.format("Вычисленный центр группы: (%.0f, %.0f, %.0f)", anchor:GetX(), anchor:GetY(), anchor:GetZ()))
    return anchor
end

----------------------------------------------------------
-- Разделение юнитов на группы по размеру maxUnits
----------------------------------------------------------
local function divideUnitsIntoGroups(units, maxUnits)
    local groups = {}
    local currentGroup = {}
    for _, unit in ipairs(units) do
        table.insert(currentGroup, unit)
        if (#currentGroup >= maxUnits) then
            table.insert(groups, currentGroup)
            currentGroup = {}
        end
    end
    if #currentGroup > 0 then
        table.insert(groups, currentGroup)
    end
    return groups
end

----------------------------------------------------------
-- Формирование цепочки (очереди) ордеров для каждой группы.
-- Для каждой группы:
--   groupAnchor := вычисленный центр группы (фиксирован для всей цепочки)
--   localExcludes := список уже выбранных кемпов для группы
--   Для orderIdx = 1 до Camp Queue:
--     Ищем ближайший кемп от groupAnchor, исключая те, что уже использованы локально или глобально.
----------------------------------------------------------
local function formOrderQueues(groups, orderCount)
    local groupsOrders = {}  -- groupsOrders[groupIdx] = {pos1, pos2, ...}
    local globalExcludes = {}
    for i = 1, orderCount do 
        globalExcludes[i] = {} 
    end

    for groupIdx, group in ipairs(groups) do
        groupsOrders[groupIdx] = {}
        local groupAnchor = computeGroupAnchor(group)
        local localExcludes = {}
        for orderIdx = 1, orderCount do
            local combinedExcludes = {}
            for _, ex in ipairs(localExcludes) do 
                table.insert(combinedExcludes, ex) 
            end
            for _, ex in ipairs(globalExcludes[orderIdx]) do 
                if not containsValue(combinedExcludes, ex) then
                    table.insert(combinedExcludes, ex)
                end
            end

            local candidateList = getNearestCamps(groupAnchor, 28, combinedExcludes)
            local candidate = candidateList[1]
            if not candidate then
                print(string.format("[AutoFarmCampsGroupedChain] Группа %d: не найден кандидат для orderIdx = %d", groupIdx, orderIdx))
                break
            end
            table.insert(groupsOrders[groupIdx], candidate.center)
            table.insert(localExcludes, candidate.index)
            table.insert(globalExcludes[orderIdx], candidate.index)
            print(string.format("[AutoFarmCampsGroupedChain] Группа (size=%d) получает ордер %d на (%.0f, %.0f, %.0f)",
                #group, orderIdx, candidate.center:GetX(), candidate.center:GetY(), candidate.center:GetZ()))
        end
    end
    return groupsOrders
end

----------------------------------------------------------
-- Выдача ордеров для группы юнитов.
-- Первый ордер выдаётся сразу, остальные – добавляются в очередь (queue=true, execute_fast=true).
----------------------------------------------------------
local function issueOrdersForGroup(player, groupUnits, orders)
    for orderIdx, pos in ipairs(orders) do
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
            nil,
            pos,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
            groupUnits,
            true,
            false,
            false,
            true,
            nil,
            true
        )
        print(string.format("[AutoFarmCampsGroupedChain] Группа (size=%d) получает ордер %d на (%.0f, %.0f, %.0f)",
            #groupUnits, orderIdx, pos:GetX(), pos:GetY(), pos:GetZ()))
    end
end

----------------------------------------------------------
-- Флаг однократного выполнения (на одно нажатие биндинга)
----------------------------------------------------------
local executed = false
local wasBotBindPressed = false

----------------------------------------------------------
-- Основная функция OnUpdate
----------------------------------------------------------
function OnUpdate()
    local player = Players.GetLocal()
    local nowPressed = botBind:IsPressed()
    if nowPressed and not wasBotBindPressed and not executed then
        executed = true

        -- Получаем выбранные юниты и фильтруем живых
        local units = Player.GetSelectedUnits(player) or {}
        if #units == 0 then
            print("[AutoFarmCampsGroupedChain] Нет выбранных юнитов.")
            return
        end

        local aliveUnits = {}
        for _, unit in ipairs(units) do
            if Entity.IsAlive(unit) then
                table.insert(aliveUnits, unit)
            end
        end
        if #aliveUnits == 0 then
            print("[AutoFarmCampsGroupedChain] Нет живых юнитов.")
            return
        end

        -- Разбиваем юнитов на группы по значению maxUnitsPerCampSlider
        local maxUnitsPerCamp = maxUnitsPerCampSlider:Get()
        local groups = divideUnitsIntoGroups(aliveUnits, maxUnitsPerCamp)
        local orderCount = campQueueSlider:Get()

        -- Формируем цепочки ордеров для каждой группы
        local groupsOrders = formOrderQueues(groups, orderCount)

        -- Выдаем сформированные ордера каждой группе
        for groupIdx, groupUnits in ipairs(groups) do
            issueOrdersForGroup(player, groupUnits, groupsOrders[groupIdx])
        end

        print("[AutoFarmCampsGroupedChain] Ордеры выданы.")
    end
    wasBotBindPressed = nowPressed
    if not nowPressed then
        executed = false
    end
end

----------------------------------------------------------
-- Завершаем скрипт
----------------------------------------------------------
return {
    OnUpdate = OnUpdate
}
