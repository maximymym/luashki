local creep_aggro = {}

-- Создаем UI
local tab = Menu.Create("Scripts", "Creep Aggro", "Creep Aggro", "Lane Control")
tab:Icon("\u{f0e7}")
local settings_group = tab:Create("Settings")
local damage_settings_group = tab:Create("Damage Settings")
local debug_group = tab:Create("Debug")

-- Настройки UI
local ui = {}
ui.enabled = settings_group:Switch("Enabled", true)
ui.hp_percent_buffer = damage_settings_group:Slider("HP Percent Buffer (%)", 1, 10, 4)
ui.use_max_damage = damage_settings_group:Switch("Use Max Potential Damage", true)
ui.enemy_hero_search_radius = settings_group:Slider("Enemy Hero Search Radius", 300, 1000, 600)
ui.aggro_cooldown = settings_group:Slider("Aggro Cooldown (ms)", 1000, 5000, 2500)
ui.melee_angle_threshold = settings_group:Slider("Melee Targeting Angle", 10, 60, 30)
-- Новые настройки для упрощенного режима
ui.simplified_mode = debug_group:Switch("Simplified Mode (HP-only trigger)", false)
ui.debug_mode = debug_group:Switch("Debug Mode", false)

-- Локальные переменные
local last_aggro_time = 0
local font = Render.LoadFont("Arial", 0, 500)

-- Хранение активных снарядов
local active_projectiles = {}

-- Хранение данных атак ближних героев
local melee_attack_data = {}

-- Система отложенных действий
local delayed_actions = {}

-- Добавление отложенного действия
local function add_delayed_action(delay_ms, callback)
    table.insert(delayed_actions, {
        execute_time = os.clock() * 1000 + delay_ms,
        callback = callback
    })
end

-- Обработка отложенных действий
local function process_delayed_actions()
    local current_time = os.clock() * 1000
    local i = 1
    
    while i <= #delayed_actions do
        if current_time >= delayed_actions[i].execute_time then
            -- Выполняем действие
            delayed_actions[i].callback()
            -- Удаляем из списка
            table.remove(delayed_actions, i)
        else
            i = i + 1
        end
    end
end

-- Проверка, что сущность действительна
local function is_entity_valid(entity)
    return entity ~= nil and Entity.IsAlive(entity) and not Entity.IsDormant(entity)
end

-- Очистка старых снарядов
local function clean_old_projectiles()
    if ui.simplified_mode:Get() then return end
    
    local current_time = os.clock()
    for handle, info in pairs(active_projectiles) do
        -- Удаляем снаряды старше 2 секунд или с неактуальными сущностями
        if current_time - info.time > 2.0 or
           not is_entity_valid(info.source) or 
           not is_entity_valid(info.target) then
            active_projectiles[handle] = nil
        end
    end
end

-- Проверяем, может ли наш герой выполнить переагривание
local function can_perform_aggro()
    local my_hero = Heroes.GetLocal()
    if not my_hero or not Entity.IsAlive(my_hero) then
        return false
    end
    
    -- Проверяем, не истёк ли кулдаун
    local current_time = os.clock() * 1000
    if current_time - last_aggro_time < ui.aggro_cooldown:Get() then
        return false
    end
    
    -- Проверяем, не обездвижен ли герой
    if NPC.HasState(my_hero, Enum.ModifierState.MODIFIER_STATE_STUNNED) or
       NPC.HasState(my_hero, Enum.ModifierState.MODIFIER_STATE_SILENCED) or
       NPC.HasState(my_hero, Enum.ModifierState.MODIFIER_STATE_HEXED) or
       NPC.HasState(my_hero, Enum.ModifierState.MODIFIER_STATE_ROOTED) then
        return false
    end
    
    return true
end

-- Получаем реальный урон героя (с учетом бонусов)
local function get_hero_true_damage(hero)
    if ui.use_max_damage:Get() then
        -- Используем максимальный возможный урон для "наихудшего сценария"
        return NPC.GetTrueMaximumDamage(hero)
    else
        -- Используем средний урон (минимальный + бонусы)
        return NPC.GetTrueDamage(hero)
    end
end

-- Проверяем, находится ли крип в зоне риска добивания
local function is_creep_in_last_hit_range(creep, enemy_hero)
    local current_hp = Entity.GetHealth(creep)
    local max_hp = Entity.GetMaxHealth(creep)
    local true_damage = get_hero_true_damage(enemy_hero)
    
    -- Вычисляем порог: реальный урон героя + X% от макс здоровья крипа
    local hp_buffer = max_hp * (ui.hp_percent_buffer:Get() / 100)
    local threshold = true_damage + hp_buffer
    
    -- Если текущее здоровье меньше или равно порогу, крип в опасности
    return current_hp <= threshold
end

-- Получаем союзных рэнж крипов
local function get_allied_ranged_creeps()
    local my_hero = Heroes.GetLocal()
    if not my_hero then return {} end
    
    local creeps = NPCs.GetAll()
    local result = {}
    
    for _, creep in pairs(creeps) do
        if creep and Entity.IsAlive(creep) and Entity.IsSameTeam(my_hero, creep) and 
           NPC.IsCreep(creep) and NPC.IsLaneCreep(creep) and 
           NPC.IsRanged(creep) then
            table.insert(result, creep)
        end
    end
    
    return result
end

-- Находим вражеских героев рядом с крипом
local function get_nearby_enemy_heroes(creep)
    local my_hero = Heroes.GetLocal()
    if not my_hero then return {} end
    
    local heroes = Heroes.GetAll()
    local result = {}
    local creep_pos = Entity.GetAbsOrigin(creep)
    local search_radius = ui.enemy_hero_search_radius:Get()
    
    for _, hero in pairs(heroes) do
        if hero and Entity.IsAlive(hero) and not Entity.IsSameTeam(my_hero, hero) then
            local hero_pos = Entity.GetAbsOrigin(hero)
            local distance = (creep_pos - hero_pos):Length()
            
            if distance <= search_radius then
                table.insert(result, hero)
            end
        end
    end
    
    return result
end

-- Проверяем, целится ли дальний герой в крипа (по снарядам)
local function is_ranged_hero_targeting_creep(hero, creep)
    -- В упрощенном режиме считаем, что герой всегда целится в крипа
    if ui.simplified_mode:Get() then
        return true
    end
    
    for _, info in pairs(active_projectiles) do
        if info.source == hero and info.target == creep then
            return true
        end
    end
    
    return false
end

-- Проверяем, целится ли ближний герой в крипа (по углу поворота)
local function is_melee_hero_targeting_creep(hero, creep)
    -- В упрощенном режиме считаем, что герой всегда целится в крипа
    if ui.simplified_mode:Get() then
        return true
    end
    
    if not melee_attack_data[hero] then
        return false
    end
    
    -- Проверяем, достаточно ли долго герой нацелен на крипа
    local current_activity = NPC.GetActivity(hero)
    if current_activity == Enum.GameActivity.ACT_DOTA_ATTACK or 
       current_activity == Enum.GameActivity.ACT_DOTA_ATTACK2 then
        
        -- Проверяем направление героя на крипа
        local hero_pos = Entity.GetAbsOrigin(hero)
        local creep_pos = Entity.GetAbsOrigin(creep)
        local forward = Entity.GetRotation(hero):GetForward():Normalized()
        local direction = (creep_pos - hero_pos):Normalized()
        
        -- Вычисляем угол
        local dot = forward:Dot(direction)
        if dot > 1 then dot = 1 end
        if dot < -1 then dot = -1 end
        local angle = math.deg(math.acos(dot))
        
        -- Если угол достаточно мал, считаем, что герой нацелен на крипа
        if angle <= ui.melee_angle_threshold:Get() then
            return true
        end
    end
    
    return false
end

-- Проверяем, целится ли герой в крипа (универсальная функция)
local function is_hero_targeting_creep(hero, creep)
    -- В упрощенном режиме считаем, что герой всегда целится в крипа, если крип в опасности
    if ui.simplified_mode:Get() then
        return true
    end
    
    if NPC.IsRanged(hero) then
        return is_ranged_hero_targeting_creep(hero, creep)
    else
        return is_melee_hero_targeting_creep(hero, creep)
    end
end

-- Выполняем A-клик на вражеского героя
local function perform_aggro(enemy_hero)
    local my_hero = Heroes.GetLocal()
    if not my_hero or not can_perform_aggro() then return end
    
    -- Выполняем А-клик на врага
    Player.PrepareUnitOrders(
        Players.GetLocal(),
        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
        enemy_hero,
        Vector(),
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        my_hero
    )
    
    -- Обновляем время последнего переагривания
    last_aggro_time = os.clock() * 1000
    
    -- Отладочный вывод
    if ui.debug_mode:Get() then
        local mode = ui.simplified_mode:Get() and "SIMPLIFIED MODE" or "NORMAL MODE"
        print("Creep Aggro (" .. mode .. "): Executed aggro on " .. NPC.GetUnitName(enemy_hero))
    end
    
    -- Опционально: сразу отменяем команду, если не хотим реально атаковать
    -- Используем нашу систему отложенных действий
    add_delayed_action(50, function()
        local my_hero_copy = Heroes.GetLocal() -- Получаем героя снова, т.к. это отложенное действие
        if my_hero_copy then
            Player.PrepareUnitOrders(
                Players.GetLocal(),
                Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
                nil,
                Vector(),
                nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                my_hero_copy
            )
        end
    end)
end

-- Отслеживание снарядов
function creep_aggro.OnProjectile(proj)
    if not ui.enabled:Get() or ui.simplified_mode:Get() then return end
    
    local my_hero = Heroes.GetLocal()
    if not my_hero then return end
    
    if proj.source and Entity.IsNPC(proj.source) and not Entity.IsSameTeam(my_hero, proj.source) and
       NPC.IsHero(proj.source) and proj.target and Entity.IsNPC(proj.target) then
        -- Сохраняем информацию о снаряде
        active_projectiles[proj.handle] = {
            source = proj.source,
            target = proj.target,
            time = os.clock()
        }
        
        if ui.debug_mode:Get() then
            print(string.format("Projectile: %s -> %s", NPC.GetUnitName(proj.source), NPC.GetUnitName(proj.target)))
        end
    end
end

-- Отслеживание атак ближних героев в OnUpdate
function creep_aggro.OnUpdate()
    if not ui.enabled:Get() then return end
    
    local my_hero = Heroes.GetLocal()
    if not my_hero or not Entity.IsAlive(my_hero) then return end
    
    -- Обрабатываем отложенные действия
    process_delayed_actions()
    
    -- Если не в упрощенном режиме, обновляем данные о снарядах и анимациях
    if not ui.simplified_mode:Get() then
        -- Очищаем старые снаряды
        clean_old_projectiles()
        
        -- Обновляем информацию об атаках ближних героев
        for _, enemy in pairs(Heroes.GetAll()) do
            if not Entity.IsSameTeam(my_hero, enemy) and Entity.IsAlive(enemy) and not NPC.IsRanged(enemy) then
                local current_activity = NPC.GetActivity(enemy)
                if current_activity == Enum.GameActivity.ACT_DOTA_ATTACK or 
                   current_activity == Enum.GameActivity.ACT_DOTA_ATTACK2 then
                    
                    -- Добавляем данные об атаке
                    if not melee_attack_data[enemy] then
                        melee_attack_data[enemy] = {
                            time = os.clock(),
                            animation_started = true
                        }
                    end
                else
                    -- Сбрасываем данные, если герой не атакует
                    melee_attack_data[enemy] = nil
                end
            end
        end
    end
    
    -- Получаем союзных рэнж крипов
    local allied_ranged_creeps = get_allied_ranged_creeps()
    
    for _, creep in pairs(allied_ranged_creeps) do
        -- Находим вражеских героев рядом с крипом
        local enemy_heroes = get_nearby_enemy_heroes(creep)
        
        for _, enemy_hero in pairs(enemy_heroes) do
            -- Проверяем, находится ли крип в зоне риска добивания
            if is_creep_in_last_hit_range(creep, enemy_hero) then
                -- В упрощенном режиме сразу выполняем переагривание
                if ui.simplified_mode:Get() then
                    perform_aggro(enemy_hero)
                    return
                -- В обычном режиме проверяем, целится ли враг на крипа
                else if is_hero_targeting_creep(enemy_hero, creep) then
                        perform_aggro(enemy_hero)
                        return -- Выполняем только одно переагривание за кадр
                    end
                end
            end
        end
    end
end

-- Отладочная информация
function creep_aggro.OnDraw()
    if not ui.enabled:Get() or not ui.debug_mode:Get() then return end
    
    local my_hero = Heroes.GetLocal()
    if not my_hero then return end
    
    -- Показываем режим работы
    local mode_text = ui.simplified_mode:Get() and "SIMPLIFIED MODE (HP-only trigger)" or "NORMAL MODE (Full targeting detection)"
    Render.Text(font, 14, mode_text, Vec2(10, 90), Color(0, 255, 0, 255))
    
    local allied_ranged_creeps = get_allied_ranged_creeps()
    
    for _, creep in pairs(allied_ranged_creeps) do
        local pos = Entity.GetAbsOrigin(creep)
        local screen_pos, is_visible = pos:ToScreen()
        
        if is_visible then
            local enemy_heroes = get_nearby_enemy_heroes(creep)
            
            for _, enemy_hero in pairs(enemy_heroes) do
                -- Получаем урон героя
                local true_damage = get_hero_true_damage(enemy_hero)
                local hp_threshold = true_damage + Entity.GetMaxHealth(creep) * (ui.hp_percent_buffer:Get() / 100)
                local current_hp = Entity.GetHealth(creep)
                
                -- Проверяем, находится ли крип в зоне риска
                local in_danger = current_hp <= hp_threshold
                
                if in_danger then
                    local text = "HP: " .. current_hp .. " / Thresh: " .. math.floor(hp_threshold)
                    Render.Text(font, 14, text, screen_pos, Color(255, 0, 0, 255))
                    
                    local hero_pos = Entity.GetAbsOrigin(enemy_hero)
                    local hero_screen_pos, hero_is_visible = hero_pos:ToScreen()
                    
                    if hero_is_visible then
                        -- Рисуем линию от крипа к герою
                        Render.Line(screen_pos, hero_screen_pos, Color(255, 165, 0, 255))
                        
                        -- Отображаем информацию о реальном уроне героя
                        local hero_type = NPC.IsRanged(enemy_hero) and "Ranged" or "Melee"
                        local dmg_text = hero_type .. " DMG: " .. math.floor(true_damage)
                        Render.Text(font, 14, dmg_text, hero_screen_pos, Color(255, 255, 255, 255))
                        
                        if not ui.simplified_mode:Get() then
                            -- Проверяем нацеливание
                            local targeting = is_hero_targeting_creep(enemy_hero, creep)
                            if targeting then
                                local target_text = "Targeting!"
                                Render.Text(font, 14, target_text, hero_screen_pos + Vec2(0, 20), Color(255, 0, 0, 255))
                            end
                        else
                            -- В упрощенном режиме всегда показываем, что герой нацелен
                            local target_text = "Auto-targeting (simplified mode)"
                            Render.Text(font, 14, target_text, hero_screen_pos + Vec2(0, 20), Color(255, 128, 0, 255))
                        end
                    end
                end
            end
        end
    end
    
    -- Отображаем состояние кулдауна
    local current_time = os.clock() * 1000
    local cooldown_remaining = ui.aggro_cooldown:Get() - (current_time - last_aggro_time)
    
    if cooldown_remaining > 0 then
        local text = "Aggro CD: " .. string.format("%.1f", cooldown_remaining / 1000) .. "s"
        Render.Text(font, 14, text, Vec2(10, 110), Color(255, 255, 255, 255))
    end
    
    -- Отображаем информацию о активных снарядах только в обычном режиме
    if not ui.simplified_mode:Get() then
        local y_offset = 130
        for handle, info in pairs(active_projectiles) do
            -- Проверяем, что и источник, и цель все еще существуют и действительны
            if info.source and info.target and 
               Entity.IsAlive(info.source) and Entity.IsAlive(info.target) and 
               not Entity.IsDormant(info.source) and not Entity.IsDormant(info.target) then
                
                local source_name = NPC.GetUnitName(info.source)
                local target_name = NPC.GetUnitName(info.target)
                local text = "Projectile: " .. source_name .. " -> " .. target_name
                Render.Text(font, 14, text, Vec2(10, y_offset), Color(0, 255, 255, 255))
                y_offset = y_offset + 20
            end
        end
    end
    
    -- Отображаем информацию о запланированных действиях
    local action_count = #delayed_actions
    if action_count > 0 then
        local text = "Pending actions: " .. action_count
        Render.Text(font, 14, text, Vec2(10, 150), Color(255, 255, 0, 255))
    end
end

-- Обработка начала игры
function creep_aggro.OnGameStart()
    last_aggro_time = 0
    active_projectiles = {}
    melee_attack_data = {}
    delayed_actions = {}
end

return creep_aggro