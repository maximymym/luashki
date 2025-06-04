local debug = {}

local tab = Menu.Create("General", "Debug", "Debug", "Debug")

local inworld_group = tab:Create("In-World")
local callbacks_group = tab:Create("Callbacks")
local inworld_settings_group = tab:Create("In-World Settings", 1)
local callbacks_settings_group = tab:Create("Callbacks Settings", 2)

--#region UI
local ui = {}

ui.inworld = {}
ui.inworld.global_switch = inworld_group:Switch("In-World Enabled", false)
ui.inworld.name = inworld_group:Switch("Unit Name", false)
ui.inworld.position = inworld_group:Switch("Unit Position", false)
ui.inworld.modifier = inworld_group:Switch("Modifiers", false)
ui.inworld.ability = inworld_group:Switch("Abilities", false)
ui.inworld.item = inworld_group:Switch("Items", false)
ui.inworld.modifier_state = inworld_group:Switch("Modifier State", false)
ui.inworld.modifier_state_duration = inworld_group:Switch("Modifier State Duration", false)

ui.inworld_settings = {}
ui.inworld_settings.hero_only = inworld_settings_group:Switch("Only heroes", true)
ui.inworld_settings.on_draw = inworld_settings_group:Switch("Render in OnDraw \a{primary}fps drop", false)

ui.callbacks = {}
ui.callbacks.modifier = callbacks_group:Switch("Modifier", false)
ui.callbacks.animation = callbacks_group:Switch("Animation", false)
ui.callbacks.add_entity = callbacks_group:Switch("Entity Create/Remove", false)
ui.callbacks.projectile = callbacks_group:Switch("Projectile", false)
ui.callbacks.particle = callbacks_group:Switch("Particle", false)
ui.callbacks.gesture = callbacks_group:Switch("Gesture", false)
ui.callbacks.sound = callbacks_group:Switch("Sound", false)
ui.callbacks.order = callbacks_group:Switch("Unit Order", false)

ui.callbacks_settings = {}
ui.callbacks_settings.divider = callbacks_settings_group:Switch("Add 'divider' in the end of the log message", true)
ui.callbacks_settings.add_more_info = callbacks_settings_group:Switch("More info. Starts with [m] prefix", true)
--#endregion

local font = Render.LoadFont("Arial", 0, 500)

local function add_divider()
    if ui.callbacks_settings.divider:Get() then
        print("+---+---+---+---+---+---+---+")
    end
end

-- we can't modify the original table in callbacks, so we need to copy it to add more info
function table.copy(t)
    local u = { }
    for k, v in pairs(t) do u[k] = v end
    return u
end

--#region Callbacks

--#region Modifier
function debug.OnModifierCreate(ent, mod)
    if not ui.callbacks.modifier:Get() then return end
    print("OnModifierCreate")
    local modifier_name = Modifier.GetName(mod)
    local owner = Ability.GetOwner(Modifier.GetAbility(mod))
    local owner_name = NPC.GetUnitName(owner)
    print(("%s | %s -> %s"):format(modifier_name, owner_name, NPC.GetUnitName(ent)))
    add_divider()
end

function debug.OnModifierDestroy(ent, mod)
    if not ui.callbacks.modifier:Get() then return end
    print("OnModifierDestroy")
    local modifier_name = Modifier.GetName(mod)
    local owner = Ability.GetOwner(Modifier.GetAbility(mod))
    local owner_name = NPC.GetUnitName(owner)
    print(("%s | %s -> %s"):format(modifier_name, owner_name, NPC.GetUnitName(ent)))
    add_divider()
end
--#endregion

--#region Animation
function debug.OnUnitAnimation(a)
    if not ui.callbacks.animation:Get() then return end
    print("OnUnitAnimation")
    if (ui.callbacks_settings.add_more_info:Get() and a.unit and Entity.IsNPC(a.unit)) then
        a = table.copy(a)
        local unit_name = NPC.GetUnitName(a.unit)
        a["[m]unit_name"] = unit_name
    end
    print(a)
    add_divider()
end

function debug.OnUnitAnimationEnd(a)
	if not ui.callbacks.animation:Get() then return end
    print("OnUnitAnimationEnd")
    if (ui.callbacks_settings.add_more_info:Get() and a.unit and Entity.IsNPC(a.unit)) then
        a = table.copy(a)
        local unit_name = NPC.GetUnitName(a.unit)
        a["[m]unit_name"] = unit_name
    end
    print(a)
    add_divider()
end
--#endregion

--#region EntityCreate
function debug.OnEntityCreate(entity)
    if not ui.callbacks.add_entity:Get() then return end

    print('OnEntityCreate')
    -- can't use NPC.GetUnitNameor Abilit.GetName because entity is not fully filled in the first tick
    local type = (function ()
        if Entity.IsAbility(entity) then
            return "Ability"
        elseif Entity.IsNPC(entity) then
            return "NPC"
        elseif Entity.IsPlayer(entity) then
            return "Player"
        else
            return "Entity"
        end
    end)()

    print(("%s | %s | %d"):format(type, Entity.GetClassName(entity), Entity.GetIndex(entity)))
    add_divider()
end

function debug.OnEntityDestroy(entity)
    if not ui.callbacks.add_entity:Get() then return end

	print('OnEntityDestroy')
    local type = (function ()
        if Entity.IsAbility(entity) then
            return "Ability"
        elseif Entity.IsNPC(entity) then
            return "NPC"
        elseif Entity.IsPlayer(entity) then
            return "Player"
        else
            return "Entity"
        end
    end)()

    print(("%s | %s | %d"):format(type, Entity.GetClassName(entity), Entity.GetIndex(entity)))
    add_divider()
end
--#endregion

--#region Projectile
function debug.OnProjectile(proj)
    -- range autoatacks, target abilities
	if not ui.callbacks.projectile:Get() then return end
    print("OnProjectile")
    if ui.callbacks_settings.add_more_info:Get() then
        proj = table.copy(proj)
        if (proj.source and Entity.IsNPC(proj.source)) then
            local unit_name = NPC.GetUnitName(proj.source)
            proj["[m]unit_name"] = unit_name
        end
        if (proj.target and Entity.IsNPC(proj.target)) then
            local unit_name = NPC.GetUnitName(proj.target)
            proj["[m]target_name"] = unit_name
        end
    end
    print(proj)
    add_divider()
end

function debug.OnLinearProjectileCreate(proj)
    -- mirana's arrow
    if not ui.callbacks.projectile:Get() then return end
    print("OnLinearProjectileCreate")
    if ui.callbacks_settings.add_more_info:Get() then
        proj = table.copy(proj)
        if (proj.source and Entity.IsNPC(proj.source)) then
            local unit_name = NPC.GetUnitName(proj.source)
            proj["[m]unit_name"] = unit_name
        end
    end
    print(proj)
    add_divider()
end


function debug.OnProjectileLoc(proj)
    if not ui.callbacks.projectile:Get() then return end

    -- tinker's rockets
	print("OnProjectileLoc")
    print(proj)
    add_divider()
end
--#endregion

--#region Particle
local particle_name_map = {}
function debug.OnParticleCreate(prt)
    if not ui.callbacks.particle:Get() then return end
    
    print("OnParticleCreate")
    if ui.callbacks_settings.add_more_info:Get() then
        prt = table.copy(prt)
        if (prt.entity and Entity.IsNPC(prt.entity)) then
            local unit_name = NPC.GetUnitName(prt.entity)
            prt["[m]entity_name"] = unit_name
        end
        if (prt.entityForModifiers and Entity.IsNPC(prt.entityForModifiers)) then
            local unit_name = NPC.GetUnitName(prt.entityForModifiers)
            prt["[m]entityForModifiers_name"] = unit_name
        end

        particle_name_map[prt.index] = prt.name
    end
    print(prt)
    add_divider()
end

function debug.OnParticleUpdate(prt)
    if not ui.callbacks.particle:Get() then return end

    -- wisp's tentacles spam
    if (prt.controlPoint == 2 and prt.position == Vector(1.0, 1.0, 1.0)) then
		return
	end

    print("OnParticleUpdate")
    if ui.callbacks_settings.add_more_info:Get() then
        prt = table.copy(prt)
        if particle_name_map[prt.index] then
            prt["[m]name"] = particle_name_map[prt.index]
        end
    end
    print(prt)
    add_divider()
end

function debug.OnParticleUpdateEntity(prt)
    if not ui.callbacks.particle:Get() then return end

    print("OnParticleUpdateEntity")
    if ui.callbacks_settings.add_more_info:Get() then
        prt = table.copy(prt)
        if (prt.entity and Entity.IsNPC(prt.entity)) then
            local unit_name = NPC.GetUnitName(prt.entity)
            prt["[m]entity_name"] = unit_name
        end

        if particle_name_map[prt.index] then
            prt["[m]name"] = particle_name_map[prt.index]
        end
    end
    print(prt)
    add_divider()
end

function debug.OnParticleUpdateFallback(prt)
    if not ui.callbacks.particle:Get() then return end

    print("OnParticleUpdateFallback")
    if ui.callbacks_settings.add_more_info:Get() then
        prt = table.copy(prt)
        if particle_name_map[prt.index] then
            prt["[m]name"] = particle_name_map[prt.index]
        end
    end
    print(prt)
    add_divider()
end

function debug.OnParticleDestroy(prt)
    if not ui.callbacks.particle:Get() then return end

    print("OnParticleDestroy")
    if ui.callbacks_settings.add_more_info:Get() then
        prt = table.copy(prt)
        if particle_name_map[prt.index] then
            prt["[m]name"] = particle_name_map[prt.index]
        end
    end
    print(prt)
    add_divider()

    particle_name_map[prt.index] = nil
end
--#endregion

--#region Gesture
function debug.OnUnitAddGesture(a)
    if not ui.callbacks.gesture:Get() then return end

    print("OnUnitAddGesture")
	print(a)
    add_divider()
end
--#endregion

--#region Sound
function debug.OnStartSound(obj)
    if not ui.callbacks.sound:Get() then return end

    
    print("OnStartSound")
    if ui.callbacks_settings.add_more_info:Get() then
        obj = table.copy(obj)
        if (obj.source and Entity.IsNPC(obj.source)) then
            local unit_name = NPC.GetUnitName(obj.source)
            obj["[m]source_name"] = unit_name
        end
    end
    print(obj)
    add_divider()
end
--#endregion

--#region Order
local flipped_order_enum = {}
for i, v in pairs(Enum.UnitOrder) do
    flipped_order_enum[v] = i
end

local flipped_issuer_enum = {}
for i, v in pairs(Enum.PlayerOrderIssuer) do
    flipped_issuer_enum[v] = i
end

function debug.OnPrepareUnitOrders(order)
    if not ui.callbacks.order:Get() then return end

    print("OnPrepareUnitOrders")
    if ui.callbacks_settings.add_more_info:Get() then
        order = table.copy(order)
        if (order.npc and Entity.IsNPC(order.npc)) then
            local unit_name = NPC.GetUnitName(order.npc)
            order["[m]npc_name"] = unit_name
        end
        if (order.target and Entity.IsNPC(order.target)) then
            local unit_name = NPC.GetUnitName(order.target)
            order["[m]target_name"] = unit_name
        end
        if (order.ability and Entity.IsAbility(order.ability)) then
            local ability_name = Ability.GetName(order.ability)
            order["[m]ability_name"] = ability_name
        end

        if (order.order) then
            local order_name = flipped_order_enum[order.order]
            if order_name then
                order["[m]order_name"] = order_name
            end
        end
    end

	print(order)
    add_divider()
end
--#endregion

--#endregion

local text_color <const> = Color(255, 255, 255, 255)
local font_size <const> = 14
local line_height <const> = 18

local floor = math.floor

local flipped_modstate_enum = {}
for i, v in pairs(Enum.ModifierState) do
    flipped_modstate_enum[v] = i
end

local function inworld_processing()
    if not ui.inworld.global_switch:Get() then return end

    local render_names = ui.inworld.name:Get()
    local render_position = ui.inworld.position:Get()
    local render_modifiers = ui.inworld.modifier:Get()
    local render_abilities = ui.inworld.ability:Get()
    local render_items = ui.inworld.item:Get()
    local render_modifier_state = ui.inworld.modifier_state:Get()
    local render_modifier_state_duration = ui.inworld.modifier_state_duration:Get()

    local list = ui.inworld_settings.hero_only:Get() and Heroes.GetAll() or NPCs.GetAll()
    for i, unit in pairs(list) do
        if unit then
            local pos = Entity.GetAbsOrigin(unit)
            local screen_pos, is_visible = pos:ToScreen()
            if not is_visible then
                goto continue
            end
            if render_names then
                local text = ("%s | %s | %d"):format(
                    Entity.GetClassName(unit),
                    Entity.GetClassName(unit),
                    Entity.GetIndex(unit)
                )
                Render.Text(font, font_size, text, screen_pos, text_color)
                screen_pos = screen_pos + Vec2(0, line_height)
            end
            if render_position then
                local text = ("%d, %d, %d"):format(
                    floor(pos.x),
                    floor(pos.y),
                    floor(pos.z)
                )
                Render.Text(font, font_size, text, screen_pos, text_color)
                screen_pos = screen_pos + Vec2(0, line_height)
            end
            if render_modifiers then
                local modifiers = NPC.GetModifiers(unit)
                if modifiers then
                    for _, mod in pairs(modifiers) do
                        local text = Modifier.GetName(mod)
                        Render.Text(font, font_size, text, screen_pos, text_color)
                        screen_pos = screen_pos + Vec2(0, line_height)
                    end
                end
            end
            if render_abilities then
                for i = 0, 25 do
                    local ab = NPC.GetAbilityByIndex(unit, i)
                    if ab then
                        local text = ("%d: %s"):format(i, Ability.GetName(ab))
                        Render.Text(font, font_size, text, screen_pos, text_color)
                        screen_pos = screen_pos + Vec2(0, line_height)
                    end
                end
            end
            if render_items then
                for i = 0, 20 do
                    local item = NPC.GetItemByIndex(unit, i)
                    if item then
                        local text = ("%d: %s"):format(i, Ability.GetName(item))
                        Render.Text(font, font_size, text, screen_pos, text_color)
                        screen_pos = screen_pos + Vec2(0, line_height)
                    end
                end
            end
            if render_modifier_state then
                for state_name, state_value in pairs(Enum.ModifierState) do
                    local has_state = NPC.HasState(unit, state_value)
                    if (has_state) then
                        local text = state_name
                        Render.Text(font, font_size, text, screen_pos, text_color)
                        screen_pos = screen_pos + Vec2(0, line_height)
                    end
                end
            end
            if render_modifier_state_duration then
                local payload = {}
                for i = 0, Enum.ModifierState.MODIFIER_STATE_LAST, 1 do
                    payload[i] = true
                end

                local states = NPC.GetStatesDuration(unit, payload, false)
                for mod_state, duration in pairs(states) do
                    if (duration > 0.0) then
                        local name = flipped_modstate_enum[mod_state]
                        if (name) then
                            local text = ("%s: %.2f"):format(name, duration)
                            Render.Text(font, font_size, text, screen_pos, text_color)
                            screen_pos = screen_pos + Vec2(0, line_height)
                        end
                    end
                end
            end
        end
        ::continue::
    end
end

function debug.OnDraw()
    if not ui.inworld_settings.on_draw:Get() then
        return
    end

    inworld_processing()
end

function debug.OnUpdate()
    if ui.inworld_settings.on_draw:Get() then
        return
    end

    inworld_processing()
end

return debug