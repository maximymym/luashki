-- Скрипт для отображения оптимального пути фарма с плавным обновлением контрольных точек и специальным стеком
local script = {}
local myHero = nil
local teamNum = nil

-- постоянные для анимации
local alpha = 0                -- текущая прозрачность (0-255)
local fadeStep = 10            -- шаг изменения alpha за кадр

-- плавность обновления контрольных точек
local smoothingSpeed = 0.2                       -- чем ближе к 1, тем быстрее догоняет цель
local smoothedCheckpointSegments = {}             -- текущие (плавно обновляемые) точки
local targetCheckpointSegments = {}               -- целевые точки после пересчёта

--#region UI
local tab    = Menu.Create("Scripts", "User Scripts", "Farm Pattern")
tab:Icon("\u{f6b6}")
local group  = tab:Create("Options"):Create("Main")
local ui = {}
ui.enabled         = group:Switch("Show Farm Route", true,  "\u{f0e7}")
ui.ctrlToDrag      = group:Switch("Ctrl-Drag Stats Text", true, "\u{f0a9}")
ui.optimized       = group:Switch("Show Optimal Path", true,  "\u{f126}")
ui.algorithm       = group:Combo("Algorithm", {"Greedy", "Optimal (Advanced)"}, 1)
ui.algorithm:Icon("\u{f0c7}")
ui.searchRadius    = group:Slider("Search Radius", 500, 6000, 1500, function(v) return tostring(v) end)
ui.allyRadius      = group:Slider("Ally Exclusion Radius", 300, 1000, 600, function(v) return tostring(v) end)
ui.pointsCount     = group:Slider("Points to Calculate", 2, 10, 4, function(v) return tostring(v) end)
ui.showVisualization   = group:Switch("Toggle Visualization", true, "\u{f021}")
ui.visualColor     = group:ColorPicker("Visual Color", Color(0,255,128), "\u{f06e}")
ui.circleSize      = group:Slider("Point Size", 5, 30, 10, function(v) return tostring(v) end)
ui.farmTimePerCreep= group:Slider("Farm Time/Creep (s)", 0.5, 3.0, 1.0, function(v) return string.format("%.1f", v) end)
ui.minEfficiency   = group:Slider("Min Efficiency (g/s)", 0, 50, 10, function(v) return tostring(v) end)
ui.goldWeight      = group:Slider("Gold Weight", 0.5, 2.0, 1.0, function(v) return string.format("%.1f", v) end)
ui.xpWeight        = group:Slider("XP Weight", 0.0, 2.0, 0.7, function(v) return string.format("%.1f", v) end)
ui.dynamicUpdate   = group:Switch("Dynamic Route Updates", true, "\u{f021}")
ui.checkpointCount = group:Slider("Checkpoints per Path", 1, 10, 5, function(v) return tostring(v) end)
--#endregion

db.farmRouteIndicator = db.farmRouteIndicator or {}
local info = db.farmRouteIndicator
info.x = info.x or 10    -- стартовая X
info.y = info.y or 320   -- стартовая Y

local dragging   = false
local dragOffset = Vec2(0,0)

-- internal data
local route = {}
local optimalRoute = {}
local lastUpdateTime = 0
local currentSegment = 1 -- текущий сегмент маршрута
local lastPosition = nil -- последняя позиция героя для отслеживания движения

-- функция получения игрового времени в секундах
local function getIngameTime()
    local rawTime = GameRules.GetGameTime() - GameRules.GetGameStartTime()
    if rawTime < 0 then rawTime = 0 end
    return rawTime
end

-- get local hero
local function GetMyHero()
    if not myHero then myHero = Heroes.GetLocal() end
    return myHero
end

-- determine local player's team number
local function GetLocalTeamNum()
    if not teamNum then
        local me = Players.GetLocal()
        local slot = Player.GetPlayerSlot(me)
        teamNum = (slot < 5) and Enum.TeamNum.TEAM_RADIANT or Enum.TeamNum.TEAM_DIRE
    end
    return teamNum
end

-- count elements
local function CountTableElements(tbl)
    local c = 0
    if tbl then for _ in pairs(tbl) do c = c + 1 end end
    return c
end

-- улучшенный расчет времени фарма с учетом урона героя
local function CalculateImprovedFarmTime(entry)
    local hero = GetMyHero()
    local creepCount = entry.creepCount or 0
    if creepCount == 0 then
        if entry.gold > 150 then creepCount = 5
        elseif entry.gold > 100 then creepCount = 4
        else creepCount = 3 end
    end
    
    -- Учитываем урон героя и скорость атаки
    local attackDamage = NPC.GetTrueDamage(hero)
    local attackSpeed = NPC.GetAttackSpeed(hero)
    local dps = attackDamage * attackSpeed
    local creepHP = 300
    
    -- Проверяем основные способности для фарма
    local farmAbilityList = {
        "juggernaut_blade_fury",
        "axe_counter_helix",
        "antimage_blink",
        "phantom_assassin_stifling_dagger",
        "luna_moon_glaive",
        "sven_great_cleave"
    }
    local hasAbility = false
    for _, abilityName in ipairs(farmAbilityList) do
        local ability = NPC.GetAbility(hero, abilityName)
        if ability and Ability.IsReady(ability) then
            hasAbility = true
            break
        end
    end
    
    local baseTime = creepCount * (creepHP / math.max(50, dps))
    if hasAbility then baseTime = baseTime * 0.6 end
    return math.max(baseTime, creepCount * ui.farmTimePerCreep:Get())
end

-- Создаем контрольные точки между двумя позициями
local function CreateCheckpoints(start, target, count)
    local result = {}
    for i = 1, count do
        local t = i / (count + 1)
        local x = start.x + (target.x - start.x) * t
        local y = start.y + (target.y - start.y) * t
        local z = start.z + (target.z - start.z) * t
        table.insert(result, Vector(x, y, z))
    end
    return result
end

-- Проверка наличия союзников рядом
local function IsAllyNearby(pos, radius)
    local my = GetMyHero()
    if not my then return false end
    local tNum = GetLocalTeamNum()
    local allies = Heroes.InRadius(pos, radius, tNum, Enum.TeamType.TEAM_FRIEND)
    for _, ally in ipairs(allies) do
        if ally ~= my and Entity.IsAlive(ally) then return true end
    end
    return false
end

-- Создаем все контрольные точки для маршрута
local function CreateAllCheckpoints(hero, routePoints, checkpointCount)
    local result = {}
    local heroPos = Entity.GetAbsOrigin(hero)
    if #routePoints > 0 then
        table.insert(result, CreateCheckpoints(heroPos, routePoints[1].pos, checkpointCount))
    end
    for i = 1, #routePoints - 1 do
        table.insert(result, CreateCheckpoints(routePoints[i].pos, routePoints[i+1].pos, checkpointCount))
    end
    return result
end

-- Сглаживание перехода контрольных точек
local function SmoothCheckpoints()
    for i, seg in ipairs(targetCheckpointSegments) do
        smoothedCheckpointSegments[i] = smoothedCheckpointSegments[i] or {}
        for j, target in ipairs(seg) do
            local cur = smoothedCheckpointSegments[i][j] or Vector(target.x, target.y, target.z)
            cur.x = cur.x + (target.x - cur.x) * smoothingSpeed
            cur.y = cur.y + (target.y - cur.y) * smoothingSpeed
            cur.z = cur.z + (target.z - cur.z) * smoothingSpeed
            smoothedCheckpointSegments[i][j] = cur
        end
    end
end

-- Жадный алгоритм расчета маршрута
local function CalculateGreedyRoute()
    local hero = GetMyHero()
    if not hero then return {} end
    local startPos = Entity.GetAbsOrigin(hero)
    local moveSpeed = NPC.GetMoveSpeed(hero)
    local spots = {}
    for _, e in ipairs(route) do
        local xp = e.gold * 0.8
        table.insert(spots, { pos = e.pos, gold = e.gold, xp = xp, creepCount = e.creepCount, isJungle = e.isJungle })
    end
    local result = {}
    local curPos = startPos
    local minEff = ui.minEfficiency:Get()
    local maxPoints = ui.pointsCount:Get()
    local goldWeight = ui.goldWeight:Get()
    local xpWeight = ui.xpWeight:Get()

    while #spots > 0 and #result < maxPoints do
        local bestIdx, bestEff = nil, 0
        for i, e in ipairs(spots) do
            local travel = GridNav.GetTravelTime(curPos, e.pos, false, nil, moveSpeed)
            local farm = CalculateImprovedFarmTime(e)
            local weightedValue = (e.gold * goldWeight + e.xp * xpWeight)
            local eff = weightedValue / (travel + farm)
            if eff >= minEff and eff > bestEff then bestEff, bestIdx = eff, i end
        end
        if not bestIdx then break end
        table.insert(result, spots[bestIdx])
        curPos = spots[bestIdx].pos
        table.remove(spots, bestIdx)
    end
    return result
end

-- Оптимальный алгоритм через полный перебор
local function CalculateOptimalRouteFull()
    local hero = GetMyHero()
    if not hero then return {} end
    local startPos = Entity.GetAbsOrigin(hero)
    local moveSpeed = NPC.GetMoveSpeed(hero)
    local spots = {}
    local goldWeight = ui.goldWeight:Get()
    local xpWeight = ui.xpWeight:Get()
    for _, e in ipairs(route) do
        local xp = e.gold * 0.8
        local travel = GridNav.GetTravelTime(startPos, e.pos, false, nil, moveSpeed)
        local farm = CalculateImprovedFarmTime({ pos = e.pos, gold = e.gold, creepCount = e.creepCount, isJungle = e.isJungle })
        local eff = (e.gold * goldWeight + xp * xpWeight) / (travel + farm)
        if eff >= ui.minEfficiency:Get() then
            table.insert(spots, { pos = e.pos, gold = e.gold, xp = xp, creepCount = e.creepCount, eff = eff, isJungle = e.isJungle })
        end
    end
    local maxCandidates = math.min(8, #spots)
    table.sort(spots, function(a, b) return a.eff > b.eff end)
    if #spots > maxCandidates then
        local temp = {}
        for i = 1, maxCandidates do temp[i] = spots[i] end
        spots = temp
    end
    local function CalculateRouteScore(rt, totalTime)
        if totalTime <= 0 then return 0 end
        local totalGold, totalXP = 0, 0
        for _, s in ipairs(rt) do totalGold = totalGold + s.gold; totalXP = totalXP + s.xp end
        return (totalGold * goldWeight + totalXP * xpWeight) / totalTime
    end
    local function FindBestRoute(rem, curPos, curRoute, curTime, depth)
        if depth >= ui.pointsCount:Get() or #rem == 0 then
            return curRoute, CalculateRouteScore(curRoute, curTime)
        end
        local bestR, bestS = curRoute, CalculateRouteScore(curRoute, math.max(0.1, curTime))
        for i, spot in ipairs(rem) do
            local newRem = {}
            for j, ss in ipairs(rem) do if i ~= j then table.insert(newRem, ss) end end
            local travel = GridNav.GetTravelTime(curPos, spot.pos, false, nil, moveSpeed)
            local farm = CalculateImprovedFarmTime(spot)
            local newTime = curTime + travel + farm
            local newRoute = { table.unpack(curRoute) }
            table.insert(newRoute, spot)
            local r, s = FindBestRoute(newRem, spot.pos, newRoute, newTime, depth+1)
            if s > bestS then bestR, bestS = r, s end
        end
        return bestR, bestS
    end
    local bestRoute, _ = FindBestRoute(spots, startPos, {}, 0, 0)
    return bestRoute
end

local function CalculateOptimalRoute()
    if ui.algorithm:Get() == 1 then return CalculateGreedyRoute() else return CalculateOptimalRouteFull() end
end

local KEY_CTRL = Enum.ButtonCode.KEY_LCONTROL
local KEY_LMB  = Enum.ButtonCode.KEY_MOUSE1

function script.OnUpdate()
    if not ui.enabled:Get() then return end
    local hero = GetMyHero()
    if not hero or not Entity.IsAlive(hero) then return end
    local now = GameRules.GetGameTime()
    local heroPos = Entity.GetAbsOrigin(hero)
    -- Пересчёт маршрута
    if now - lastUpdateTime >= 0.1 then
        lastUpdateTime = now
        route = {}
        local seen = {}
        local searchR, allyR = ui.searchRadius:Get(), ui.allyRadius:Get()
        -- lane creeps
        if LIB_HEROES_DATA and LIB_HEROES_DATA.lane_creeps_groups then
            for _, grp in ipairs(LIB_HEROES_DATA.lane_creeps_groups) do
                local pos = grp.position
                if (pos - heroPos):Length2D() <= searchR then
                    local gold = 0
                    for _, npc in pairs(grp.creeps) do gold = gold + NPC.GetGoldBounty(npc) end
                    local key = tostring(pos)
                    if gold > 0 and not seen[key] and not IsAllyNearby(pos, allyR) then
                        seen[key] = true
                        table.insert(route, {pos=pos, gold=gold, isJungle=false, creepCount=CountTableElements(grp.creeps)})
                    end
                end
            end
        end
        -- jungle spots
        if LIB_HEROES_DATA and LIB_HEROES_DATA.jungle_spots then
            for _, spot in ipairs(LIB_HEROES_DATA.jungle_spots) do
                local pos = spot.pos or ((spot.box.min + spot.box.max)*0.5)
                if (pos - heroPos):Length2D() <= searchR then
                    local gold = Camp.GetGoldBounty(spot, true)
                    local key = tostring(pos)
                    if gold>0 and not seen[key] and not IsAllyNearby(pos, allyR) then
                        seen[key] = true
                        table.insert(route, {pos=pos, gold=gold, isJungle=true})
                    end
                end
            end
        end
        if ui.optimized:Get() then
            optimalRoute = CalculateOptimalRoute()
            -- Обновляем контрольные точки
            targetCheckpointSegments = CreateAllCheckpoints(hero, optimalRoute, ui.checkpointCount:Get())
            if #smoothedCheckpointSegments ~= #targetCheckpointSegments then
                smoothedCheckpointSegments = {}
                for i, seg in ipairs(targetCheckpointSegments) do
                    smoothedCheckpointSegments[i] = {}
                    for j, pt in ipairs(seg) do
                        smoothedCheckpointSegments[i][j] = Vector(pt.x, pt.y, pt.z)
                    end
                end
            end
            currentSegment = 1
            lastPosition = heroPos
        else
            optimalRoute = {}
            targetCheckpointSegments = {}
            smoothedCheckpointSegments = {}
            currentSegment = 1
        end
    end
end

function script.OnDraw()
    if not ui.enabled:Get() then return end
    local hero = GetMyHero()
    if not hero or not Entity.IsAlive(hero) then return end
    if not ui.optimized:Get() or #optimalRoute == 0 then return end

    -- 1) Сглаживаем контрольные точки
    SmoothCheckpoints()

    -- 2) Внутриигровое время
    local rawTime = getIngameTime()
    local sec     = math.floor(rawTime % 60)

    -- 3) Позиция героя и альфа
    local heroPos      = Entity.GetAbsOrigin(hero)
    local heroScreen, heroOn = Render.WorldToScreen(heroPos)
    local desiredAlpha = ui.showVisualization:Get() and 255 or 0
    if alpha < desiredAlpha then
        alpha = math.min(alpha + fadeStep, desiredAlpha)
    elseif alpha > desiredAlpha then
        alpha = math.max(alpha - fadeStep, desiredAlpha)
    end
    if alpha <= 0 then return end
    local a = math.floor(alpha)

    -- 4) Текст статистики
    local count     = math.min(ui.pointsCount:Get(), #optimalRoute)
    local totalGold = 0
    for i = 1, count do
        totalGold = totalGold + optimalRoute[i].gold
    end
    local statsTxt = string.format("Farm Path: %d point(s), ~%d gold", count, math.floor(totalGold))
    local tw, th   = Renderer.GetTextSize(1, statsTxt)

    -- 5) Получаем позицию курсора как Vec2
    local mx, my = Input.GetCursorPos()
    local m      = Vec2(mx, my)

    -- 6) Drag & drop статистики (Ctrl+LMB)
    local topLeft  = Vec2(info.x, info.y)
    local botRight = Vec2(info.x + tw, info.y + th)
    if ui.ctrlToDrag:Get()
       and Input.IsKeyDown(KEY_CTRL)
       and Input.IsKeyDownOnce(KEY_LMB)
       and m.x >= topLeft.x and m.x <= botRight.x
       and m.y >= topLeft.y and m.y <= botRight.y then
        dragging   = true
        dragOffset = topLeft - m
    end
    if dragging and Input.IsKeyDown(KEY_LMB) then
        local cx, cy = Input.GetCursorPos()
        info.x = cx + dragOffset.x
        info.y = cy + dragOffset.y
    end
    if dragging and not Input.IsKeyDown(KEY_LMB) then
        dragging = false
    end

    -- 7) Рисуем статистику
    Renderer.SetDrawColor(255, 255, 255, a)
    Renderer.DrawText(1, info.x, info.y, statsTxt)

    -- 8) Рисуем контрольные точки
    if ui.dynamicUpdate:Get() then
        local segs = smoothedCheckpointSegments
        if currentSegment <= #segs then
            for _, cp in ipairs(segs[currentSegment]) do
                local cpScreen, on = Render.WorldToScreen(cp)
                if on then
                    Renderer.SetDrawColor(255, 165, 0, a)
                    Renderer.DrawFilledCircle(cpScreen.x, cpScreen.y, 5)
                end
            end
        end
        for iSeg = currentSegment + 1, #segs do
            for _, cp in ipairs(segs[iSeg]) do
                local cpScreen, on = Render.WorldToScreen(cp)
                if on then
                    Renderer.SetDrawColor(255, 165, 0, math.floor(a * 0.5))
                    Renderer.DrawFilledCircle(cpScreen.x, cpScreen.y, 3)
                end
            end
        end
    end

    -- 9) Цвет для маршрута
    local uiCol         = ui.visualColor:Get()
    local baseR, baseG, baseB = math.floor(uiCol.r), math.floor(uiCol.g), math.floor(uiCol.b)

    -- 10) Рисуем маршрут и STACK!
    local prevScreen, prevOn
    for i = 1, count do
        local pt      = optimalRoute[i]
        local pScreen, pOn = Render.WorldToScreen(pt.pos)

        -- Цвет и флаг STACK
        local colR, colG, colB = baseR, baseG, baseB
        local drawStack, countdownText = false, nil
        if i == 1 and pt.isJungle and sec >= 45 and sec <= 56 then
            drawStack = true
            colR = 255 - baseR
            colG = 255 - baseG
            colB = 255 - baseB
            if sec <= 53 then
                countdownText = tostring(53 - sec)
            end
        end

        if pOn then
            local radius = ui.circleSize:Get()
            -- Круг
            Renderer.SetDrawColor(colR, colG, colB, a)
            Renderer.DrawFilledCircle(pScreen.x, pScreen.y, radius)
            -- Номер
            local numTxt = tostring(i)
            local tw2, th2 = Renderer.GetTextSize(1, numTxt)
            Renderer.SetDrawColor(255,255,255,a)
            Renderer.DrawText(1,
                pScreen.x - tw2*0.5,
                pScreen.y - th2*0.5,
                numTxt
            )
            -- STACK! сверху
            if drawStack then
                local stTxt = "STACK!"
                if countdownText then stTxt = stTxt.." "..countdownText end
                local tws, ths = Renderer.GetTextSize(1, stTxt)
                Renderer.SetDrawColor(colR, colG, colB, a)
                Renderer.DrawText(1,
                    pScreen.x - tws*0.5,
                    pScreen.y - radius - ths - 2,
                    stTxt
                )
            end
            -- Золото снизу
            local goldTxt = tostring(math.floor(pt.gold))
            local twg, thg = Renderer.GetTextSize(1, goldTxt)
            Renderer.SetDrawColor(255,215,0,a)
            Renderer.DrawText(1,
                pScreen.x - twg*0.5,
                pScreen.y + radius + 2,
                goldTxt
            )
        end

        -- Линия
        local drawLine
        if i == 1 then
            drawLine = heroOn or pOn
            if drawLine then
                Renderer.SetDrawColor(colR, colG, colB, a)
                Renderer.DrawLine(heroScreen.x, heroScreen.y,
                                  pScreen.x, pScreen.y)
            end
        else
            drawLine = prevOn or pOn
            if drawLine then
                Renderer.SetDrawColor(colR, colG, colB, a)
                Renderer.DrawLine(prevScreen.x, prevScreen.y,
                                  pScreen.x, pScreen.y)
            end
        end

        prevScreen, prevOn = pScreen, pOn
    end
end




return { OnUpdate = script.OnUpdate, OnDraw = script.OnDraw }
