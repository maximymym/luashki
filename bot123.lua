-- Создаём вкладку и бинд
local tab = Menu.Create("Scripts", "User Scripts", "AutoBotGroup")
local group = tab:Create("Options"):Create("Main")
local botBind = group:Bind("Activate Bot", Enum.ButtonCode.KEY_0, "panorama/images/spellicons/rattletrap_power_cogs_png.vtex_c")

local botActive = false
local wasBotBindPressed = false

-----------------------------------------------
-- Точки линий Radiant (как в вашем скрипте)

local radiantTop = {
    Vector(-6633, -3412, 256),
    Vector(-6688, -3085, 256),
    Vector(-6688, -2812, 128),
    Vector(-6633, -2484, 137),
    Vector(-6633, -2156, 128),
    Vector(-6633, -1993, 128),
    Vector(-6688, -1665, 128),
    Vector(-6579, -1338, 128),
    Vector(-6524, -901, 128),
    Vector(-6469, -573, 128),
    Vector(-6469, -300, 128),
    Vector(-6469, 27, 128),
    Vector(-6469, 300, 128),
    Vector(-6360, 628, 128),
    Vector(-6415, 955, 128),
    Vector(-6415, 1392, 128),
    Vector(-6360, 1829, 128),
    Vector(-6360, 2320, 128),
    Vector(-6360, 2702, 128),
    Vector(-6306, 3030, 128),
    Vector(-6251, 3685, 128),
    Vector(-6251, 4231, 128),
    Vector(-6251, 4613, 128),
    Vector(-6087, 5105, 128),
    Vector(-5814, 5487, 128),
    Vector(-5487, 5650, 128),
    Vector(-5050, 5978, 128),
    Vector(-4449, 6033, 128),
    Vector(-3958, 6033, 128),
    Vector(-3521, 6033, 128),
    Vector(-3030, 6196, 128),
    Vector(-2539, 6087, 128),
    Vector(-1938, 6142, 0),
    Vector(-1447, 6142, 45),
    Vector(-1119, 6142, 128),
    Vector(-573, 6142, 128),
    Vector(-136, 5978, 128),
    Vector(246, 5978, 128),
    Vector(573, 5978, 128),
    Vector(901, 5978, 128),
    Vector(1283, 5923, 128),
    Vector(1665, 5923, 128),
    Vector(2102, 5869, 128),
    Vector(2320, 5814, 136),
    Vector(2539, 5760, 128),
    Vector(2812, 5814, 128),
    Vector(3194, 5814, 256),
    Vector(3467, 5814, 256)
}
local radiantMid = {
    Vector(-4613, -4067, 256),
    Vector(-4449, -3903, 256),
    Vector(-4176, -3740, 128),
    Vector(-3958, -3576, 134),
    Vector(-3740, -3467, 128),
    Vector(-3576, -3303, 128),
    Vector(-3358, -3139, 128),
    Vector(-3139, -2975, 128),
    Vector(-2975, -2812, 128),
    Vector(-2866, -2593, 128),
    Vector(-2757, -2429, 128),
    Vector(-2648, -2320, 128),
    Vector(-2429, -2047, 128),
    Vector(-2211, -1883, 128),
    Vector(-1993, -1665, 128),
    Vector(-1774, -1447, 128),
    Vector(-1556, -1228, 128),
    Vector(-1338, -1065, 128),
    Vector(-1174, -901, 128),
    Vector(-1065, -737, 128),
    Vector(-628, -300, 0),
    Vector(-136, 191, 128),
    Vector(191, 409, 128),
    Vector(519, 573, 128),
    Vector(901, 955, 128),
    Vector(1228, 1283, 128),
    Vector(1556, 1501, 128),
    Vector(1829, 1665, 128),
    Vector(2156, 1883, 128),
    Vector(2375, 2102, 128),
    Vector(2648, 2320, 128),
    Vector(2921, 2593, 128),
    Vector(3139, 2812, 128),
    Vector(3358, 2975, 135),
    Vector(3576, 3139, 128),
    Vector(3849, 3358, 148),
    Vector(4122, 3685, 256)
}
local radiantBot = {
    Vector(-3958, -6142, 256),
    Vector(-3576, -6087, 252),
    Vector(-3194, -6087, 128),
    Vector(-2921, -6142, 137),
    Vector(-2593, -6142, 128),
    Vector(-2266, -6196, 128),
    Vector(-2047, -6142, 128),
    Vector(-1720, -6196, 128),
    Vector(-1501, -6251, 128),
    Vector(-1283, -6251, 128),
    Vector(-1065, -6251, 128),
    Vector(-792, -6251, 128),
    Vector(-573, -6251, 128),
    Vector(-409, -6251, 128),
    Vector(-136, -6196, 128),
    Vector(82, -6196, 128),
    Vector(246, -6196, 128),
    Vector(409, -6251, 128),
    Vector(1174, -6306, 0),
    Vector(2211, -6196, 128),
    Vector(2702, -6196, 128),
    Vector(3139, -6142, 128),
    Vector(3521, -6142, 128),
    Vector(3958, -6142, 128),
    Vector(4449, -6142, 128),
    Vector(4832, -6087, 128),
    Vector(5105, -5923, 128),
    Vector(5487, -5869, 128),
    Vector(5541, -5596, 128),
    Vector(5760, -5377, 128),
    Vector(5814, -5050, 128),
    Vector(5869, -4777, 128),
    Vector(6033, -4449, 128),
    Vector(6033, -4231, 128),
    Vector(6033, -4067, 128),
    Vector(5978, -3849, 128),
    Vector(6033, -3576, 128),
    Vector(6033, -3248, 128),
    Vector(6033, -3030, 128),
    Vector(5978, -2812, 128),
    Vector(5978, -2484, 128),
    Vector(6033, -2266, 128),
    Vector(6033, -1883, 128),
    Vector(6087, -1556, 128),
    Vector(6087, -1338, 128),
    Vector(6087, -1119, 128),
    Vector(6087, -901, 128),
    Vector(6087, -682, 128),
    Vector(6087, -519, 128),
    Vector(6087, -409, 128),
    Vector(6087, -191, 128),
    Vector(6087, -27, 128),
    Vector(6142, 246, 128),
    Vector(6087, 464, 128),
    Vector(6087, 737, 128),
    Vector(6087, 1010, 128),
    Vector(6087, 1338, 128),
    Vector(6142, 1556, 128),
    Vector(6142, 1829, 128),
    Vector(6196, 2102, 128),
    Vector(6196, 2375, 164),
    Vector(6251, 3085, 256)
}

-----------------------------------------------
-- Функция для реверса массива (для Dire)
-----------------------------------------------
local function reverseLine(arr)
    local newArr = {}
    for i = #arr, 1, -1 do
        table.insert(newArr, arr[i])
    end
    return newArr
end

-----------------------------------------------
-- Выбор линии по позиции и команде
-----------------------------------------------
local function pickLinePointsByPosition(pos, team)
    local function lineDistance(arr)
        local minD = math.huge
        for _, p in ipairs(arr) do
            local d = (p - pos):Length2D()
            if d < minD then
                minD = d
            end
        end
        return minD
    end
    local distTop = lineDistance(radiantTop)
    local distMid = lineDistance(radiantMid)
    local distBot = lineDistance(radiantBot)
    local bestDist = math.min(distTop, distMid, distBot)

    local chosenLine
    if bestDist == distTop then
        chosenLine = radiantTop
    elseif bestDist == distMid then
        chosenLine = radiantMid
    else
        chosenLine = radiantBot
    end

    if team == 2 then
        return chosenLine
    else
        return reverseLine(chosenLine)
    end
end

-----------------------------------------------
-- Строим маршрут от startPos до трона
-----------------------------------------------
local function computeAugmentedRouteFromPoint(startPos, team)
    local enemyAncient
    if team == 2 then
        enemyAncient = Vector(5595, 5104, 256)   -- Dire
    elseif team == 3 then
        enemyAncient = Vector(-6087, -5268, 256) -- Radiant
    else
        return nil
    end

    local roadPoints = pickLinePointsByPosition(startPos, team)
    if not roadPoints or #roadPoints == 0 then return nil end

    local function findNearestIndex(pos, arr)
        local bestIndex, minDist = 1, math.huge
        for i, p in ipairs(arr) do
            local d = (p - pos):Length2D()
            if d < minDist then
                minDist = d
                bestIndex = i
            end
        end
        return bestIndex
    end

    local startIndex = findNearestIndex(startPos, roadPoints)
    local entryPoint = roadPoints[startIndex]
    local enemyIndex = findNearestIndex(enemyAncient, roadPoints)
    local exitPoint = roadPoints[enemyIndex]

    local subPathA = GridNav.BuildPath(startPos, entryPoint, false, nil)
    if not subPathA or #subPathA < 1 then
        return nil
    end

    local subRoad = {}
    if startIndex <= enemyIndex then
        for i = startIndex, enemyIndex do
            table.insert(subRoad, roadPoints[i])
        end
    else
        for i = startIndex, enemyIndex, -1 do
            table.insert(subRoad, roadPoints[i])
        end
    end

    local subPathC = GridNav.BuildPath(exitPoint, enemyAncient, false, nil)
    if not subPathC or #subPathC < 1 then
        return nil
    end

    local fullRoute = {}
    for _, p in ipairs(subPathA) do
        table.insert(fullRoute, p)
    end
    for i = 2, #subRoad do
        table.insert(fullRoute, subRoad[i])
    end
    for i = 2, #subPathC do
        table.insert(fullRoute, subPathC[i])
    end

    return fullRoute
end

-----------------------------------------------
-- [НОВОЕ] Универсальная функция, возвращающая
-- позицию для Attack Move: либо "союзные крипы дерутся",
-- либо "просто ближайшие вражеские крипы" на линии.
-----------------------------------------------
local function getAttackMovePosition(leader)
    if not leader then return nil end

    local team = Entity.GetTeamNum(leader)
    local leaderPos = Entity.GetAbsOrigin(leader)
    local radius = 5000

    -- 1) Пытаемся найти союзных крипов, дерущихся с врагами
    local allyCreeps = NPCs.InRadius(leaderPos, radius, team, Enum.TeamType.TEAM_FRIEND)
    local fightingPos = nil
    local fightingDist = math.huge

    if allyCreeps and #allyCreeps > 0 then
        for _, creep in ipairs(allyCreeps) do
            if creep and NPC.IsLaneCreep(creep) and Entity.IsAlive(creep) then
                -- Есть ли враги рядом
                local enemiesNear = NPCs.InRadius(Entity.GetAbsOrigin(creep), 600, team, Enum.TeamType.TEAM_ENEMY)
                if enemiesNear and #enemiesNear > 0 then
                    local dist = (Entity.GetAbsOrigin(creep) - leaderPos):Length2D()
                    if dist < fightingDist then
                        fightingDist = dist
                        fightingPos = Entity.GetAbsOrigin(creep)
                    end
                end
            end
        end
    end

    if fightingPos then
        -- Нашли бой с участием союзных крипов
        return fightingPos
    end

    -- 2) Если не нашли бой союзных крипов,
    --    ищем ближайших вражеских крипов.
    local enemyCreeps = NPCs.InRadius(leaderPos, radius, team, Enum.TeamType.TEAM_ENEMY)
    local closestEnemyPos = nil
    local closestDist = math.huge

    if enemyCreeps and #enemyCreeps > 0 then
        for _, creep in ipairs(enemyCreeps) do
            if creep and NPC.IsLaneCreep(creep) and Entity.IsAlive(creep) then
                local dist = (Entity.GetAbsOrigin(creep) - leaderPos):Length2D()
                if dist < closestDist then
                    closestDist = dist
                    closestEnemyPos = Entity.GetAbsOrigin(creep)
                end
            end
        end
    end

    return closestEnemyPos
end

-----------------------------------------------
-- OnUpdate
-----------------------------------------------
function OnUpdate()
    local player = Players.GetLocal()

    local currentPressed = botBind:IsPressed()
    if currentPressed and not wasBotBindPressed then
        botActive = not botActive
        print("[DEBUG] Bot toggled:", botActive)

        if botActive then
            local controlledUnits = Player.GetSelectedUnits(player) or {}
            if not controlledUnits or #controlledUnits == 0 then
                print("[DEBUG] No units selected, turning bot off.")
                botActive = false
            else
                local leader = controlledUnits[1]
                if leader then
                    local leaderPos = Entity.GetAbsOrigin(leader)
                    local team = Entity.GetTeamNum(leader)

                    -- 1) Ищем позицию для атаки (ближайший бой, или просто враж. крипы)
                    local fightOrEnemyPos = getAttackMovePosition(leader)
                    if fightOrEnemyPos then
                        print("[DEBUG] Found target for Attack Move. Adding immediate order.")
                        
                        -- Ставим приказ Attack Move первым
                        Player.PrepareUnitOrders(
                            player,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                            nil,
                            fightOrEnemyPos,
                            nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                            controlledUnits,
                            false -- НЕ в очередь, сразу
                        )

                        -- 2) Сразу строим маршрут от этой точки
                        local route = computeAugmentedRouteFromPoint(fightOrEnemyPos, team)
                        if route and #route > 0 then
                            print("[DEBUG] Building route from fight/enemy pos.")
                            for _, p in ipairs(route) do
                                Player.PrepareUnitOrders(
                                    player,
                                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                                    nil,
                                    p,
                                    nil,
                                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                                    controlledUnits,
                                    true  -- добавляем в очередь
                                )
                            end
                        else
                            print("[DEBUG] Failed to build route from fight/enemy pos.")
                        end
                    else
                        -- Если совсем нет цели для боя, строим маршрут от текущей позиции
                        local route = computeAugmentedRouteFromPoint(leaderPos, team)
                        if route and #route > 0 then
                            print("[DEBUG] No fight or enemy creeps found. Building route from hero pos.")
                            -- Можно первым приказом тоже AttackMove (на всякий случай),
                            -- а можно просто всё добавлять в очередь.
                            -- Ниже сделано как в предыдущих примерах — первый без очереди:
                            for i, p in ipairs(route) do
                                Player.PrepareUnitOrders(
                                    player,
                                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                                    nil,
                                    p,
                                    nil,
                                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                                    controlledUnits,
                                    (i > 1)  -- первый приказ без очереди, остальные в очередь
                                )
                            end
                        else
                            print("[DEBUG] Failed to build route from hero position.")
                        end
                    end
                end

                -- Всё сделали — выключаемся, чтобы не спамить
                botActive = false
            end
        end
    end

    wasBotBindPressed = currentPressed
end

return { OnUpdate = OnUpdate }