-- Rubick Auto-Ult Script with Improved Blink Logic for Cast-to-Position Spells

local script = {}

-- Debug function
local debug_enabled = true
local function DebugPrint(message)
    if debug_enabled then
        print("[RubickUlt] " .. message)
    end
end

-- Список украденных способностей для комбинации
local stolen_spells = {
    "axe_berserkers_call",
    "earthshaker_echo_slam",
    "tidehunter_ravage",
    "treant_overgrowth",
    "obsidian_destroyer_sanity_eclipse",
    "puck_dream_coil",
    "storm_spirit_electric_vortex",
    "enigma_black_hole",
    "magnataur_reverse_polarity",
}

-- Сопоставление технических имен и дружественных имен спеллов
local spell_friendly_names = {
    ["axe_berserkers_call"] = "Berserker's Call",
    ["earthshaker_echo_slam"] = "Echo Slam",
    ["tidehunter_ravage"] = "Ravage",
    ["treant_overgrowth"] = "Overgrowth",
    ["obsidian_destroyer_sanity_eclipse"] = "Sanity's Eclipse",
    ["puck_dream_coil"] = "Dream Coil",
    ["storm_spirit_electric_vortex"] = "Electric Vortex",
    ["enigma_black_hole"] = "Black Hole",
    ["magnataur_reverse_polarity"] = "Reverse Polarity"
}

-- Специальные ключи радиуса для некоторых способностей
local radius_keys = {
    magnataur_reverse_polarity = "pull_radius",
    puck_dream_coil            = "coil_radius",    -- <<< добавлено для Dream Coil
}

-- UI
local tab = Menu.Create("Heroes", "Hero List", "Rubick", "Auto Use Ultis")
local group = tab:Create("Main")
local ui = {}
ui.enable        = group:Switch("Enable Script", false, "\u{f0e7}")
ui.mode          = group:Combo("Use Mode", {"Manual","Auto"}, 0)
ui.cast_key      = group:Bind("Cast Bind", Enum.ButtonCode.KEY_T)
ui.min_targets   = group:Slider("Min Targets", 1, 5, 1, function(v) return tostring(v) end)
ui.visual_debug  = group:Switch("Visual Debug", false, "\u{f075}")
ui.radius_color  = group:ColorPicker("In Range Color", Color(0,255,0), "\u{f53f}")
ui.out_of_range_color = group:ColorPicker("Out of Range Color", Color(255,0,0), "\u{f53f}")
ui.use_refresher = group:Switch("Use Refresher Orb", false, "\u{f021}")

-- Spell selector
local spell_group = tab:Create("Spell Selection")
ui.spell_select = spell_group:MultiSelect(
    "Spells to Use", {
        {"Berserker's Call", "panorama/images/spellicons/axe_berserkers_call_png.vtex_c", true},
        {"Echo Slam", "panorama/images/spellicons/earthshaker_echo_slam_png.vtex_c", true},
        {"Ravage", "panorama/images/spellicons/tidehunter_ravage_png.vtex_c", true},
        {"Overgrowth", "panorama/images/spellicons/treant_overgrowth_png.vtex_c", true},
        {"Sanity's Eclipse", "panorama/images/spellicons/obsidian_destroyer_sanity_eclipse_png.vtex_c", true},
        {"Dream Coil", "panorama/images/spellicons/puck_dream_coil_png.vtex_c", true},
        {"Electric Vortex", "panorama/images/spellicons/storm_spirit_electric_vortex_png.vtex_c", true},
        {"Black Hole", "panorama/images/spellicons/enigma_black_hole_png.vtex_c", true},
        {"Reverse Polarity", "panorama/images/spellicons/magnataur_reverse_polarity_png.vtex_c", true},
    },
    true
)

-- Переменные состояния и частица
local particle, need_update_particle, need_update_color = nil, false, false
local currentAOE = 0
local blinkDelay   = 0.03   -- задержка после блинка перед кастом
local spellDelay   = 0.5   -- задержка между кастами заклинаний
local castState    = 0      -- 0: начальное состояние, 1: после блинка, 2: после первых скиллов, 3: после рефрешера, 4: после повторных скиллов
local stateTime    = 0
local stored       = {}     -- хранит данные между шагами
local myHero       = nil
local inBlinkRange = false  -- флаг для отслеживания, в рендже ли точка для блинка
local ordersExecuted = false -- флаг для контроля отправки ордеров
local castDelay = 0.5       -- задержка перед переходом к следующему состоянию (в секундах)
local executionMode = 0     -- 0: нет активного выполнения, 1: выполняем близкую логику, 2: выполняем логику блинка
local secondaryTimer = 0    -- таймер для каста второго заклинания

-- UI callbacks
ui.enable:SetCallback(function(enabled)
    if enabled then
        print("[RubickUlt] СКРИПТ АКТИВИРОВАН")
    else
        print("[RubickUlt] СКРИПТ ДЕАКТИВИРОВАН")
    end
end)
ui.visual_debug:SetCallback(function() need_update_particle = true end)
ui.radius_color:SetCallback(function() need_update_color = true end)
ui.out_of_range_color:SetCallback(function() need_update_color = true end)
ui.mode:SetCallback(function(mode) 
    print("[RubickUlt] РЕЖИМ ИЗМЕНЕН: " .. (mode == 0 and "Ручной" or "Автоматический"))
end)
ui.min_targets:SetCallback(function(val)
    print("[RubickUlt] НАСТРОЙКА: Минимальное количество целей = " .. val)
end)
ui.use_refresher:SetCallback(function(enabled)
    print("[RubickUlt] НАСТРОЙКА: Использование Refresher Orb " .. (enabled and "включено" or "выключено"))
end)

-- Проверка типов спеллов
local function isNoTargetSpell(name)
    return name == "axe_berserkers_call"
        or name == "earthshaker_echo_slam"
        or name == "treant_overgrowth"
        or name == "tidehunter_ravage"
        or name == "magnataur_reverse_polarity"
        or name == "storm_spirit_electric_vortex"
end

local function isChannelSpell(name)
    return name == "enigma_black_hole"
end

-- Поиск оптимальной точки AOE
local function FindBestAOEPoint(radius, minCount)
    local me = myHero
    local enemies = {}
    for _, h in pairs(Heroes.GetAll()) do
        if h~=me and Entity.IsAlive(h) and not Entity.IsSameTeam(h, me) and not NPC.IsIllusion(h) then
            table.insert(enemies, h)
        end
    end
    if #enemies == 0 then return nil, nil, 0 end

    local positions = {}
    for _, h in ipairs(enemies) do
        table.insert(positions, {pos=Entity.GetAbsOrigin(h)})
    end
    for i=1,#enemies-1 do
        for j=i+1,#enemies do
            local p1 = Entity.GetAbsOrigin(enemies[i])
            local p2 = Entity.GetAbsOrigin(enemies[j])
            local mid = Vector((p1.x+p2.x)/2, (p1.y+p2.y)/2, (p1.z+p2.z)/2)
            table.insert(positions, {pos=mid})
        end
    end

    local bestPos, bestCount = nil, 0
    for _, cand in ipairs(positions) do
        local cnt = 0
        for _, h in ipairs(enemies) do
            local p = Entity.GetAbsOrigin(h)
            if (Vector(cand.pos.x, cand.pos.y,0) - Vector(p.x, p.y,0)):Length2D() <= radius then
                cnt = cnt + 1
            end
        end
        if cnt >= minCount and cnt > bestCount then
            bestCount, bestPos = cnt, cand.pos
        end
    end
    if not bestPos then return nil, nil, 0 end

    -- ближайший герой к bestPos
    local bestHero, bestDist = nil, math.huge
    for _, h in ipairs(enemies) do
        local p = Entity.GetAbsOrigin(h)
        local d = (Vector(p.x,p.y,0) - Vector(bestPos.x,bestPos.y,0)):Length2D()
        if d < bestDist then
            bestDist, bestHero = d, h
        end
    end
    return bestHero, bestPos, bestCount
end

-- Отрисовка радиуса (не меняется)
local function custom_radius_point(origin, radius, inRange)
    if not ui.visual_debug:Get() or radius <= 0 or not origin then
        if particle then
            Particle.Destroy(particle)
            particle = nil
        end
        return
    end
    local color = inRange and ui.radius_color:Get() or ui.out_of_range_color:Get()
    if not particle or need_update_particle then
        if particle then Particle.Destroy(particle) end
        particle = Particle.Create("particles/ui_mouseactions/drag_selected_ring.vpcf", Enum.ParticleAttachment.PATTACH_CUSTOMORIGIN)
        Particle.SetControlPoint(particle, 1, Vector(color.r, color.g, color.b))
        need_update_particle = false
    end
    Particle.SetControlPoint(particle, 0, Vector(origin.x, origin.y, origin.z))
    Particle.SetControlPoint(particle, 2, Vector(radius, 255, 255))
    if need_update_color or inBlinkRange ~= inRange then
        Particle.SetControlPoint(particle, 1, Vector(color.r, color.g, color.b))
        need_update_color = false
        inBlinkRange = inRange
    end
end

-- Сброс состояния (не меняется)
local function resetAll()
    if castState > 0 or executionMode > 0 then
        print("[RubickUlt] RESET: Сброс состояния из castState=" .. castState .. ", executionMode=" .. executionMode)
    end
    castState = 0
    stored = {}
    custom_radius_point(nil, 0, true)
    currentAOE = 0
    inBlinkRange = false
    ordersExecuted = false
    executionMode = 0  -- Сбрасываем режим выполнения
end

-- Основная логика OnUpdate с улучшенным блинком и разделением логик
function script.OnUpdate()
    if not myHero then myHero = Heroes.GetLocal() end
    if not ui.enable:Get() or not Entity.IsAlive(myHero) or NPC.GetUnitName(myHero) ~= "npc_dota_hero_rubick" then
        resetAll()
        return
    end

    ui.cast_key:Visible(ui.mode:Get() == 0)
    local mode   = ui.mode:Get()
    local keyDown = ui.cast_key:IsDown()

    if mode == 0 and not keyDown and castState ~= 0 then
        resetAll()
        return
    end
    
    -- Проверка для каста второго спелла в режиме прямого каста
    if executionMode == 1 and stored.secondary and os.clock() - secondaryTimer >= spellDelay then
        local s2, name2 = stored.secondary.ability, stored.secondary.name
        if isNoTargetSpell(name2) then
            print("[RubickUlt] КАСТ 2/ПРЯМОЙ: " .. spell_friendly_names[name2] .. " (NoTarget)")
            Ability.CastNoTarget(s2, false)
        else
            print("[RubickUlt] КАСТ 2/ПРЯМОЙ: " .. spell_friendly_names[name2] .. " (CastPosition)")
            Ability.CastPosition(s2, stored.castPt, false)
        end
        -- После каста второго спелла, сбрасываем состояние
        resetAll()
        return
    end

    -- Собираем доступные украденные спеллы
    -- Reverse mapping friendly -> technical names for priority lookup
    local friendly_to_technical = {} 
    for tech, friendly in pairs(spell_friendly_names) do 
        friendly_to_technical[friendly] = tech 
    end 

    -- Сбор доступных спеллов в порядке приоритета UI
    local castable = {} 
    local selected = ui.spell_select:ListEnabled() 
    for _, friendly in ipairs(selected) do 
        local tech = friendly_to_technical[friendly] 
        if tech then 
            local ab = NPC.GetAbility(myHero, tech) 
            if ab and Ability.IsCastable(ab, NPC.GetMana(myHero)) then 
                if tech == "storm_spirit_electric_vortex" then 
                    -- проверка Aghs/Shard для Electric Vortex
                    local aghs       = NPC.GetItem(myHero, "item_ultimate_scepter", true) 
                    local aghs_bless = NPC.HasModifier(myHero, "modifier_item_ultimate_scepter_consumed") 
                    local shard      = NPC.GetItem(myHero, "item_aghanims_shard", true) 
                    if aghs or aghs_bless or (shard and NPC.HasModifier(myHero, "modifier_item_aghanims_shard")) then 
                        table.insert(castable, {ability=ab, name=tech}) 
                    end 
                else 
                    table.insert(castable, {ability=ab, name=tech}) 
                end 
            end 
        end 
    end 

    if #castable == 0 then resetAll(); return end

    local primary, secondary = castable[1], castable[2]
    local spell, spellName  = primary.ability, primary.name

    -- Проверяем Blink
    local blink = NPC.GetItem(myHero, "item_blink", true)
    local blinkAvailable = blink and Ability.IsCastable(blink, NPC.GetMana(myHero))
    local blinkRange = 0
    
    if blinkAvailable then
        blinkRange = Ability.GetLevelSpecialValueFor(blink, "blink_range")
        if not blinkRange or blinkRange == 0 then blinkRange = Ability.GetCastRange(blink) end
    end

    -- Вычисляем AOE радиус спелла
    local key = radius_keys[spellName] or "radius"
    local aoe = Ability.GetLevelSpecialValueFor(spell, key)
    if aoe == 0 then aoe = Ability.GetLevelSpecialValueFor(spell, "area_of_effect") end
    if not aoe or aoe == 0 then aoe = Ability.GetCastRange(spell) end
    if not aoe or aoe == 0 then aoe = 300 end
    if aoe ~= currentAOE then currentAOE = aoe; need_update_particle = true end

    -- Ищем оптимальную точку и считаем расстояние
    local targetHero, pt, count = FindBestAOEPoint(currentAOE, ui.min_targets:Get())
    if not pt then resetAll(); return end

    local mePos = Entity.GetAbsOrigin(myHero)
    local dx, dy = pt.x - mePos.x, pt.y - mePos.y
    local dist    = math.sqrt(dx*dx + dy*dy)
    local castRange = isNoTargetSpell(spellName) and 0 or Ability.GetCastRange(spell)
    
    -- Подсчет эффективной дистанции в зависимости от типа спелла
    local effectiveRange = isNoTargetSpell(spellName) and currentAOE or castRange
    local inBlink = blinkAvailable and dist <= blinkRange + effectiveRange
    custom_radius_point(pt, currentAOE, inBlink)

    -- Определение пороговой дистанции в зависимости от типа спелла
    local directCastThreshold
    if isNoTargetSpell(spellName) then
        directCastThreshold = currentAOE - 150
        directCastThreshold = directCastThreshold > 0 and directCastThreshold or currentAOE/2
    else
        directCastThreshold = (castRange or 0) + 150
    end
    
    -- ОСНОВНАЯ ЛОГИКА ВЫПОЛНЕНИЯ КОМБО
    -- Проверяем, начата ли уже последовательность логики блинка
    if castState > 0 then
        -- Если начали логику блинка, продолжаем её выполнять
        
        -- После Blink: кастуем в ORIGINAL оптимальную точку stored.castPt
        if castState == 1 and os.clock() - stateTime >= blinkDelay then
            if not ordersExecuted then
                ordersExecuted = true
                
                print("[RubickUlt] БЛИНК ПОСЛЕДОВАТЕЛЬНОСТЬ: Шаг 1 - каст заклинаний после блинка")
                
                -- primary
                if isNoTargetSpell(stored.primaryName) then
                    print("[RubickUlt] КАСТ 1/ПОСЛЕ БЛИНКА: " .. spell_friendly_names[stored.primaryName] .. " (NoTarget)")
                    Ability.CastNoTarget(stored.primary, false) -- Первый после блинка без очереди
                else
                    print("[RubickUlt] КАСТ 1/ПОСЛЕ БЛИНКА: " .. spell_friendly_names[stored.primaryName] .. " (CastPosition)")
                    Ability.CastPosition(stored.primary, stored.castPt, false) -- Первый после блинка без очереди
                end
                
                -- Запоминаем время для каста второго спелла с задержкой
                secondaryTimer = os.clock()
                stateTime = os.clock()
                return
            end
            
            -- Проверяем, пора ли кастовать второй спелл
            if stored.secondary and os.clock() - secondaryTimer >= spellDelay and not stored.secondaryCasted then
                local s2, name2 = stored.secondary.ability, stored.secondary.name
                if isNoTargetSpell(name2) then
                    print("[RubickUlt] КАСТ 2/ПОСЛЕ БЛИНКА: " .. spell_friendly_names[name2] .. " (NoTarget)")
                    Ability.CastNoTarget(s2, false) -- Второй спелл с задержкой
                else
                    print("[RubickUlt] КАСТ 2/ПОСЛЕ БЛИНКА: " .. spell_friendly_names[name2] .. " (CastPosition)")
                    Ability.CastPosition(s2, stored.castPt, false) -- Второй спелл с задержкой
                end
                stored.secondaryCasted = true -- отмечаем, что второй спелл уже кастован
            end
            
            -- Проверяем, пора ли переходить к следующему состоянию
            if os.clock() - stateTime >= castDelay then
                ordersExecuted = false
                stored.secondaryCasted = false -- сбрасываем флаг для следующего состояния
                stateTime = os.clock()
                if stored.useRef then
                    castState = 2
                else
                    resetAll()
                end
            end
            return
        end

        -- каст Refresher Orb
        if castState == 2 and os.clock() - stateTime >= blinkDelay then
            -- Проверяем, не каналит ли герой в данный момент (например, Black Hole)
            if NPC.IsChannellingAbility(myHero) then
                -- Если уже каналим, не используем refresher - это прервет канал
                print("[RubickUlt] ПРОПУСК REFRESHER: Герой каналит " .. spell_friendly_names[stored.primaryName] .. ". Пропускаем Refresher Orb.")
                resetAll()
                return
            end
            
            if not ordersExecuted then
                ordersExecuted = true
                
                print("[RubickUlt] БЛИНК ПОСЛЕДОВАТЕЛЬНОСТЬ: Шаг 2 - использование Refresher Orb")
                
                local refresher = NPC.GetItem(myHero, "item_refresher", true)
                if refresher and Ability.IsCastable(refresher, NPC.GetMana(myHero)) then
                    print("[RubickUlt] КАСТ REFRESHER: Использую Refresher Orb")
                    Ability.CastNoTarget(refresher, false) -- Рефрешер без очереди
                    stateTime = os.clock()
                    return
                else
                    print("[RubickUlt] ОШИБКА REFRESHER: Refresher недоступен или нет маны")
                    resetAll()
                    return
                end
            end
            
            -- Простая задержка перед переходом к следующему состоянию
            if os.clock() - stateTime >= castDelay then
                ordersExecuted = false
                stateTime = os.clock()
                castState = 3
            end
            return
        end

        -- вторая волна после Refresher
        if castState == 3 and os.clock() - stateTime >= blinkDelay then
            -- Для Black Hole и других каналящихся заклинаний - не пытаемся повторно кастовать
            -- пока не закончится первый канал
            if isChannelSpell(stored.primaryName) and NPC.IsChannellingAbility(myHero) then
                -- Герой всё ещё каналирует спелл после Refresher, не прерываем его
                print("[RubickUlt] ОЖИДАНИЕ КАНАЛА: Герой продолжает каналить " .. spell_friendly_names[stored.primaryName] .. " после Refresher")
                return -- Просто выходим без сброса состояния, чтобы продолжить каналирование
            end
            
            if not ordersExecuted then
                ordersExecuted = true
                
                print("[RubickUlt] БЛИНК ПОСЛЕДОВАТЕЛЬНОСТЬ: Шаг 3 - повторный каст заклинаний после Refresher")
                
                -- primary
                if isNoTargetSpell(stored.primaryName) then
                    print("[RubickUlt] КАСТ 1/ПОСЛЕ REFRESHER: " .. spell_friendly_names[stored.primaryName] .. " (NoTarget)")
                    Ability.CastNoTarget(stored.primary, false) -- Первый после рефрешера без очереди
                else
                    print("[RubickUlt] КАСТ 1/ПОСЛЕ REFRESHER: " .. spell_friendly_names[stored.primaryName] .. " (CastPosition)")
                    Ability.CastPosition(stored.primary, stored.castPt, false) -- Первый после рефрешера без очереди
                end
                
                -- Запоминаем время для каста второго спелла с задержкой
                secondaryTimer = os.clock()
                stateTime = os.clock()
                return
            end
            
            -- Проверяем, пора ли кастовать второй спелл
            if stored.secondary and os.clock() - secondaryTimer >= spellDelay and not stored.secondaryCasted then
                local s2, name2 = stored.secondary.ability, stored.secondary.name
                if isNoTargetSpell(name2) then
                    print("[RubickUlt] КАСТ 2/ПОСЛЕ REFRESHER: " .. spell_friendly_names[name2] .. " (NoTarget)")
                    Ability.CastNoTarget(s2, false) -- Второй спелл с задержкой
                else
                    print("[RubickUlt] КАСТ 2/ПОСЛЕ REFRESHER: " .. spell_friendly_names[name2] .. " (CastPosition)")
                    Ability.CastPosition(s2, stored.castPt, false) -- Второй спелл с задержкой
                end
                stored.secondaryCasted = true -- отмечаем, что второй спелл уже кастован
            end
            
            -- Проверяем, пора ли завершать комбо
            if os.clock() - stateTime >= castDelay then
                resetAll()
            end
            
            return
        end
    else
        -- Если еще не начали выполнение, определяем какую логику использовать
        -- Проверяем условия запуска (клавиша или авто режим)
        if ((mode==0 and keyDown) or mode==1) and not ordersExecuted then
            -- ВЫБОР РЕЖИМА ВЫПОЛНЕНИЯ - если castState == 0, выбираем логику:
            
            -- Приоритет 1: Прямое применение заклинания если враги близко
            if dist <= directCastThreshold then
                -- Указываем, что используем режим прямого каста
                executionMode = 1
                ordersExecuted = true
                
                print("[RubickUlt] БЛИЗКАЯ ДИСТАНЦИЯ: Расстояние " .. math.floor(dist) .. " <= " .. math.floor(directCastThreshold) .. " (порог). Прямой каст без блинка.")
                
                -- Сохраняем информацию для второго скилла
                stored.secondary = secondary
                stored.castPt = pt
                secondaryTimer = os.clock()
                
                -- Применяем первый спелл напрямую
                if isNoTargetSpell(spellName) then
                    print("[RubickUlt] КАСТ 1/ПРЯМОЙ: " .. spell_friendly_names[spellName] .. " (NoTarget)")
                    Ability.CastNoTarget(spell, false) -- Первый приказ без очереди
                else
                    print("[RubickUlt] КАСТ 1/ПРЯМОЙ: " .. spell_friendly_names[spellName] .. " (CastPosition)")
                    Ability.CastPosition(spell, pt, false) -- Первый приказ без очереди
                end
                
                -- Второй скилл будет кастоваться в OnUpdate с задержкой
                if not secondary then
                    -- Если второго скилла нет, сразу сбрасываем
                    resetAll()
                end
                
                return
            
            -- Приоритет 2: Используем блинк если доступен и враги в пределах блинк+спелл
            elseif blinkAvailable and inBlink then
                -- Указываем, что используем режим блинка
                executionMode = 2
                
                print("[RubickUlt] БЛИНК ЛОГИКА: Расстояние " .. math.floor(dist) .. " > " .. math.floor(directCastThreshold) .. " (порог). Используем блинк.")
                
                -- Определяем точку блинка
                local blinkTarget = pt
                if not isNoTargetSpell(spellName) and castRange and dist > castRange then
                    local dirX, dirY = dx/dist, dy/dist
                    blinkTarget = Vector(pt.x - dirX * castRange,
                                       pt.y - dirY * castRange,
                                       pt.z)
                end
                -- Для no-target спеллов блинкуем прямо в оптимальную точку
                if isNoTargetSpell(spellName) then
                    blinkTarget = pt
                end
                
                -- Сохраняем данные и начинаем последовательность
                stored.blinkPt   = blinkTarget
                stored.castPt    = pt
                stored.primary     = spell
                stored.primaryName = spellName
                stored.secondary   = secondary
                stored.useRef      = ui.use_refresher:Get()
                castState = 1
                stateTime = os.clock()
                
                print("[RubickUlt] БЛИНК: Прыжок на дистанцию " .. math.floor((blinkTarget - mePos):Length2D()))
                Ability.CastPosition(blink, blinkTarget, false) -- Блинк всегда без очереди
                return
            end
        end
    end
end

-- Отрисовка линий для визуализации
function script.OnDraw()
    if not ui.enable:Get() or not ui.visual_debug:Get() or currentAOE <= 0 then return end
    local _, optimalPos = FindBestAOEPoint(currentAOE, ui.min_targets:Get())
    if not optimalPos then return end
    
    -- Проверяем, находится ли оптимальная позиция в пределах радиуса блинка
    local mePos = Entity.GetAbsOrigin(myHero)
    local dist = (Vector(optimalPos.x, optimalPos.y,0) - Vector(mePos.x, mePos.y,0)):Length2D()
    local blink = NPC.GetItem(myHero, "item_blink", true)
    local blinkRange = blink and (Ability.GetLevelSpecialValueFor(blink, "blink_range") or Ability.GetCastRange(blink)) or 0
    local inRange = dist <= blinkRange
    
    -- Выбираем цвет линий в зависимости от доступности блинка
    local lineColor = inRange and Color(0,255,0) or Color(255,0,0)
    
    for _, h in pairs(Heroes.GetAll()) do
        if h~=myHero and Entity.IsAlive(h) and not NPC.IsIllusion(h) and not Entity.IsSameTeam(h, myHero) then
            local pos = Entity.GetAbsOrigin(h)
            if (Vector(pos.x,pos.y,0) - Vector(optimalPos.x,optimalPos.y,0)):Length2D() <= currentAOE then
                local sp,on = Render.WorldToScreen(pos)
                local cp,con = Render.WorldToScreen(optimalPos)
                if on and con then
                    Render.Line(sp, cp, 2, lineColor)
                end
            end
        end
    end
end

return script