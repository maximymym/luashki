-----------------------------------------------
-- auto_stacker_distribute_with_visual_debug.lua
-----------------------------------------------

local tab = Menu.Create("Scripts", "User Scripts", "AutoStacker")
local group = tab:Create("Options"):Create("Main")

-- Бинды:
local botBind = group:Bind("Activate Distributed Auto Stacker", Enum.ButtonCode.KEY_0, "panorama/images/spellicons/rattletrap_power_cogs_png.vtex_c")
local debugVisualToggle = group:Switch("Визуальная отладка", false, "")
local fontSizeSlider = group:Slider("Размер шрифта отладки", 12, 36, 16)

-----------------------------------------------
-- Глобальные переменные управления ботом
-----------------------------------------------
local botActive = false
local wasBotBindPressed = false
-- В начале файла (глобально или в разделе отладки) объявляем переменные для перетаскивания
local debugLabelX = 10
local debugLabelY = 10
local draggingLabel = false
local dragOffsetX = 0
local dragOffsetY = 0

-- Сохраняем выбранных юнитов (AssignedUnits) – они сохраняются при включении скрипта.
local AssignedUnits = {}

-- Локальная таблица с данными по лагерям (здесь вы задаёте координаты вручную)
local campStackData = {
    [1] = {
        wait = Vector(-750, 4493, 136),
        pull = Vector(-682, 3881, 236)
    },
    [2] = {
        wait = Vector(3050, -853, 256),
        pull = Vector(2795, -177, 256)
    },
    [3] = {
        wait = Vector(3949, -4921, 128),
        pull = Vector(4200, -4323, 128)
    },
    [4] = {
        wait = Vector(8183, -666, 256),
        pull = Vector(8204, -1369, 256)
    },
    [5] = {
        wait = Vector(-4756, 4353, 128),
        pull = Vector(-4713, 4958, 128)
    },
    [6] = {
        wait = Vector(4318, -4110, 128),
        pull = Vector(3640, -4309, 128)
    },
    [7] = {
        wait = Vector(-1147, -3948, 144),
        pull = Vector(-625, -4432, 136)
    },
    [8] = {
        wait = Vector(257, -4751, 136),
        pull = Vector(333, -4101, 254)
    },
    [9] = {
        wait = Vector(-4452, 292, 256),
        pull = Vector(-4891, 1201, 128)
    },
    [10] = {
        wait = Vector(4077, -301, 256),
        pull = Vector(4154, -1364, 128)
    },
    [11] = {
        wait = Vector(-1588, -4850, 128),
        pull = Vector(-528, -4853, 130)
    },
    [12] = {
        wait = Vector(1742, 8205, 128),
        pull = Vector(792, 8152, 128)
    },
    [13] = {
        wait = Vector(738, 3996, 133),
        pull = Vector(-78, 3932, 136)
    },
    [14] = {
        wait = Vector(-4213, 821, 256),
        pull = Vector(-5012, 1234, 128)
    },
    [15] = {
        wait = Vector(220, -7914, 136),
        pull = Vector(954, -8538, 136)
    },
    [16] = {
        wait = Vector(-2517, -8010, 136),
        pull = Vector(-2690, -7154, 128)
    },
    [17] = {
        wait = Vector(-463, 7879, 136),
        pull = Vector(-551, 6961, 128)
    },
    [18] = {
        wait = Vector(-4744, 7736, 8),
        pull = Vector(-4820, 7121, 0)
    },
    [19] = {
        wait = Vector(1294, 2985, 128),
        pull = Vector(1683, 3710, 128)
    },
    [20] = {
        wait = Vector(8148, 1209, 256),
        pull = Vector(7681, 695, 256)
    },
    [21] = {
        wait = Vector(-7835, -183, 256),
        pull = Vector(-7436, 685, 256)
    },
    [22] = {
        wait = Vector(-3544, 7570, 0),
        pull = Vector(-4521, 7474, 8)
    },
    [23] = {
        wait = Vector(-2599, 4254, 256),
        pull = Vector(-2651, 5138, 256)
    },
    [24] = {
        wait = Vector(3522, -8186, 8),
        pull = Vector(4028, -7376, 0)
    },
    [25] = {
        wait = Vector(1501, -4208, 256),
        pull = Vector(657, -3909, 256)
    },
    [26] = {
        wait = Vector(-4338, 4903, 128),
        pull = Vector(-5198, 4877, 128)
    },
    [27] = {
        wait = Vector(-7781, -1344, 256),
        pull = Vector(-7538, -550, 256)
    },
    [28] = {
        wait = Vector(4781, -7812, 8),
        pull = Vector(4464, -7166, 128)
    },
}


-- Таблицы для хранения распределения и strike‑центров
local UnitAssignments = {}   -- ключ: unit, значение: индекс из campStackData
local UnitActionsDone = {}   -- ключ: unit, значение: таблица по минутам (флаги: waitDone, attackDone, pullDone)
local CampStrikeCenters = {} -- ключ: campStackData индекс, значение: strikeCenter (Vector)

-----------------------------------------------
-- Функция получения внутриигрового времени (начиная с 0)
-----------------------------------------------
local function getIngameTime()
    local rawTime = GameRules.GetGameTime() - GameRules.GetGameStartTime()
    if rawTime < 0 then rawTime = 0 end
    return rawTime
end

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

local function findRealCampByWait(waitPos)
    local allCamps = Camps.GetAll()
    if not allCamps or #allCamps == 0 then return nil end
    local bestCamp = nil
    local bestDist = math.huge
    for _, camp in ipairs(allCamps) do
        local center = getBoxCenter(camp)
        if center then
            local dist = (center - waitPos):Length2D()
            if dist < bestDist then
                bestDist = dist
                bestCamp = camp
            end
        end
    end
    return bestCamp
end

-----------------------------------------------
-- Распределение юнитов по ближайшим лагерям (из campStackData)
-----------------------------------------------
local function assignUnitsToCamps(units)
    local assignments = {}
    local available = {}
    for k, _ in pairs(campStackData) do
        table.insert(available, k)
    end

    if #units <= #available then
        for _, unit in ipairs(units) do
            local bestIndex, bestDist = nil, math.huge
            local unitPos = Entity.GetAbsOrigin(unit)
            for i, campIndex in ipairs(available) do
                local data = campStackData[campIndex]
                local d = (data.wait - unitPos):Length2D()
                if d < bestDist then
                    bestDist = d
                    bestIndex = campIndex
                end
            end
            if bestIndex then
                assignments[unit] = bestIndex
                for i, v in ipairs(available) do
                    if v == bestIndex then
                        table.remove(available, i)
                        break
                    end
                end
            end
        end
    else
        for _, unit in ipairs(units) do
            local bestIndex, bestDist = nil, math.huge
            local unitPos = Entity.GetAbsOrigin(unit)
            for campIndex, data in pairs(campStackData) do
                local d = (data.wait - unitPos):Length2D()
                if d < bestDist then
                    bestDist = d
                    bestIndex = campIndex
                end
            end
            assignments[unit] = bestIndex
        end
    end
    return assignments
end

-----------------------------------------------
-- Инициализация: сохраняем выбранных юнитов и распределяем их
-----------------------------------------------
local function initializeAssignments()
    local player = Players.GetLocal()
    local units = Player.GetSelectedUnits(player) or {}
    if #units == 0 then
        print("[AutoStacker] Нет выбранных юнитов.")
        return false
    end

    AssignedUnits = {}
    for _, unit in ipairs(units) do
        table.insert(AssignedUnits, unit)
    end

    UnitAssignments = assignUnitsToCamps(AssignedUnits)
    for _, unit in ipairs(AssignedUnits) do
        local campIdx = UnitAssignments[unit]
        if campIdx then
            local campData = campStackData[campIdx]
            if not CampStrikeCenters[campIdx] then
                local realCamp = findRealCampByWait(campData.wait)
                if realCamp then
                    local center = getBoxCenter(realCamp)
                    if center then
                        CampStrikeCenters[campIdx] = center
                        print(string.format("[AutoStacker] Для лагеря #%d вычислен strike center: (%.0f, %.0f, %.0f)",
                              campIdx, center:GetX(), center:GetY(), center:GetZ()))
                    else
                        print("[AutoStacker] Невозможно вычислить strike center для лагеря #" .. campIdx)
                    end
                else
                    print("[AutoStacker] Не найден реальный лагерь для лагеря #" .. campIdx)
                end
            end
        else
            print("[AutoStacker] Не назначен лагерь для юнита.")
        end
    end

    UnitActionsDone = {}  -- ключ: unit, значение: таблица по минутам
    return true
end

-----------------------------------------------
-- OnUpdate: основная логика автостака
-----------------------------------------------
function OnUpdate()
    local player = Players.GetLocal()

    -- Обработка переключения бота
    local nowPressed = botBind:IsPressed()
    if nowPressed and not wasBotBindPressed then
        botActive = not botActive
        print("[AutoStacker] Bot toggled:", botActive)
        if botActive then
            if not initializeAssignments() then
                botActive = false
            end
        else
            UnitAssignments = {}
            UnitActionsDone = {}
            AssignedUnits = {}
        end
    end
    wasBotBindPressed = nowPressed

    -- Если бот не активен, выходим
    if not botActive then return end

    -- Используем сохранённый список AssignedUnits, а не текущее выделение
    local units = AssignedUnits or {}
    if #units == 0 then
        print("[AutoStacker] Нет сохранённых юнитов, выключаем бот.")
        botActive = false
        return
    end

    -- Фильтруем живых юнитов из AssignedUnits
    local aliveUnits = {}
    for _, unit in ipairs(units) do
        if Entity.IsAlive(unit) then
            table.insert(aliveUnits, unit)
        end
    end
    if #aliveUnits == 0 then
        print("[AutoStacker] Все юниты умерли, выключаем бот.")
        botActive = false
        return
    end

    local currentTime = getIngameTime()
    local minute = math.floor(currentTime / 60)
    local sec = math.floor(currentTime % 60)

    -- Инициализируем флаги для каждой минуты для каждого юнита
    for _, unit in ipairs(aliveUnits) do
        if not UnitActionsDone[unit] then
            UnitActionsDone[unit] = {}
        end
        if not UnitActionsDone[unit][minute] then
            UnitActionsDone[unit][minute] = { waitDone = false, attackDone = false, pullDone = false }
        end
    end

    for _, unit in ipairs(aliveUnits) do
        local campIdx = UnitAssignments[unit]
        if campIdx then
            local campData = campStackData[campIdx]
            if campData then
                local flags = UnitActionsDone[unit][minute]
                local strikeCenter = CampStrikeCenters[campIdx]
                if not strikeCenter then
                    print("[AutoStacker] Нет strike center для лагеря #" .. campIdx)
                    goto continue_unit
                end

                local controlledUnits = { unit }
                if sec < 53 then
                    if not flags.waitDone then
                        flags.waitDone = true
                        print(string.format("[Stacker] Юнит %s в %d:%02d -> WAIT (%.0f, %.0f, %.0f)",
                            unit, minute, sec,
                            campData.wait:GetX(), campData.wait:GetY(), campData.wait:GetZ()))
                        Player.PrepareUnitOrders(
                            player,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                            nil,
                            campData.wait,
                            nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                            controlledUnits,
                            false
                        )
                    end
                else
                    if sec >= 53 and sec < 54 and not flags.attackDone then
                        flags.attackDone = true
                        print(string.format("[Stacker] Юнит %s в %d:%02d -> ATTACK (%.0f, %.0f, %.0f)",
                            unit, minute, sec,
                            strikeCenter:GetX(), strikeCenter:GetY(), strikeCenter:GetZ()))
                        Player.PrepareUnitOrders(
                            player,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                            nil,
                            strikeCenter,
                            nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                            controlledUnits,
                            false
                        )
                    end
                    if sec >= 55 and sec < 56 and not flags.pullDone then
                        flags.pullDone = true
                        print(string.format("[Stacker] Юнит %s в %d:%02d -> PULL (%.0f, %.0f, %.0f)",
                            unit, minute, sec,
                            campData.pull:GetX(), campData.pull:GetY(), campData.pull:GetZ()))
                        Player.PrepareUnitOrders(
                            player,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                            nil,
                            campData.pull,
                            nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                            controlledUnits,
                            false
                        )
                    end
                end
            end
        else
            print("[AutoStacker] Назначение юнита отсутствует.")
        end
        ::continue_unit::
    end

end

function OnDraw()
    -- Если визуальная отладка выключена, ничего не рисуем
    if not debugVisualToggle:Get() then 
        return 
    end

    -- Пример статуса (только статус бота)
    local statusText = ""
    if botActive then
        statusText = "AUTO STACKER ACTIVE"
    else
        statusText = "AUTO STACKER INACTIVE"
    end

    -- Выбор цвета: зелёный, если бот активен, иначе красный
    local r, g, b = 255, 0, 0  -- красный по умолчанию
    if botActive then
        r, g, b = 0, 255, 0   -- зелёный
    end

    -- Получаем выбранный размер шрифта из слайдера
    local fontSize = fontSizeSlider:Get()
    local debugFont = Renderer.LoadFont("Tahoma", fontSize, Enum.FontWeight.BOLD)
    
    -- Вычисляем размеры надписи через Renderer.GetTextSize
    local labelWidth, labelHeight = Renderer.GetTextSize(debugFont, statusText)
    
    -- Получаем текущие экранные координаты курсора
    local cursorX, cursorY = Input.GetCursorPos()
    
    -- Реализуем перетаскивание:
    -- Если зажаты левый Ctrl и левая кнопка мыши
    if Input.IsKeyDown(Enum.ButtonCode.KEY_LCONTROL) and Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
        if not draggingLabel then
            -- Если ещё не в режиме перетаскивания, проверяем, находится ли курсор в области надписи
            if cursorX >= debugLabelX and cursorX <= (debugLabelX + labelWidth) and
               cursorY >= debugLabelY and cursorY <= (debugLabelY + labelHeight) then
                draggingLabel = true
                dragOffsetX = cursorX - debugLabelX
                dragOffsetY = cursorY - debugLabelY
            end
        else
            -- Если уже перетаскиваем, обновляем позицию надписи с учетом сохранённого смещения
            debugLabelX = cursorX - dragOffsetX
            debugLabelY = cursorY - dragOffsetY
        end
    else
        draggingLabel = false
    end

    -- Рисуем надпись
    Renderer.SetDrawColor(r, g, b, 255)
    Renderer.DrawText(debugFont, debugLabelX, debugLabelY, statusText)
    
    -- Подсвечиваем кемп, который будет стакаться.
    -- В данном примере берём назначение первого юнита из AssignedUnits.
    if botActive and AssignedUnits and #AssignedUnits > 0 then
        for i, unit in ipairs(AssignedUnits) do
            local campIdx = UnitAssignments[unit]
            if campIdx then
                local campData = campStackData[campIdx]
                if campData then
                    local sx, sy, onScreen = Renderer.WorldToScreen(campData.wait)
                    if onScreen then
                        Renderer.SetDrawColor(0, 0, 255, 255)  -- синий цвет для подсветки
                        Renderer.DrawText(debugFont, sx - 20, sy - 20, ">>")
                    end
                end
            end
        end
    end    
end

return {
    OnUpdate = OnUpdate,
    OnDraw = OnDraw
}
