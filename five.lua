local example = {}
--#region UI

local tab = Menu.Create("General", "Main", "bodyblock")
tab:Icon("\u{f6b6}")
local group = tab:Create("Main"):Create("Group")

local ui = {}

ui.bodyblock_enabled = group:Switch("Bodyblock Enabled", false, "\u{f047}")
ui.bodyblock_key     = group:Bind("Bodyblock Key", Enum.ButtonCode.KEY_NONE)
-- Add adjustable distance for fine-tuning
ui.min_distance      = group:Slider("Min Block Distance", 90, 150, 108)
ui.max_distance      = group:Slider("Max Block Distance", 110, 170, 130)
ui.speed_threshold   = group:Slider("Speed Threshold", 100, 300, 170)

--#endregion UI

--#region Vars

local my_hero = nil
-- Add hero collision size mapping
local HERO_COLLISION_SIZE = {
    -- Heroes with smaller collision sizes
    npc_dota_hero_puck = 0.8,
    npc_dota_hero_batrider = 0.85,
    npc_dota_hero_weaver = 0.85,
    npc_dota_hero_venomancer = 0.85,
    npc_dota_hero_snapfire = 0.85,
    -- Add more as needed
    
    -- Heroes with larger collision sizes
    npc_dota_hero_spirit_breaker = 1.1,
    npc_dota_hero_pudge = 1.1,
    npc_dota_hero_doom_bringer = 1.1,
    -- Add more as needed
}

--#endregion Vars

local POSITION_HISTORY = {}    -- {pos = Vector, time = number}
local last_order       = Vector()

--#region @Core

-- Movement tracking
local function GetMovementData(target)
    if not POSITION_HISTORY[target] then
        POSITION_HISTORY[target] = {
            pos  = Entity.GetAbsOrigin(target),
            time = GameRules.GetGameTime()
        }
        return Vector(0, 0, 0), 0
    end

    local old_data     = POSITION_HISTORY[target]
    local new_pos      = Entity.GetAbsOrigin(target)
    local current_time = GameRules.GetGameTime()
    local delta_time   = current_time - old_data.time
    local delta_pos    = new_pos - old_data.pos
    POSITION_HISTORY[target] = { pos = new_pos, time = current_time }

    local move_speed = delta_time > 0 and (delta_pos:Length() / delta_time) or 0
    return delta_pos:Normalized(), move_speed
end

-- Get hero collision size multiplier
local function GetHeroSizeMultiplier(hero)
    local name = NPC.GetUnitName(hero)
    return HERO_COLLISION_SIZE[name] or 1.0
end

-- Calculate bodyblock position ahead of target with adjusted distance based on hero size
local function GetSmartBlockPosition(hero, target)
    local target_pos = Entity.GetAbsOrigin(target)
    local move_dir, move_speed = GetMovementData(target)
    
    -- Get size multiplier for target hero
    local size_multiplier = GetHeroSizeMultiplier(target)
    
    -- Calculate dynamic distance based on hero size and movement speed
    local min_distance = ui.min_distance:Get() * size_multiplier
    local max_distance = ui.max_distance:Get() * size_multiplier
    local speed_threshold = ui.speed_threshold:Get()
    
    local dynamic_distance = (move_speed < speed_threshold) and min_distance or max_distance

    if move_dir:Length() < 0.01 then
        move_dir = (Entity.GetAbsOrigin(hero) - target_pos):Normalized()
    end

    return target_pos + move_dir * dynamic_distance
end

-- Issue move or hold orders to selected units with a valid issuer NPC
local function IssueOrder(pos, shouldHold, issuer)
    local player    = Players.GetLocal()
    local orderType = shouldHold
        and Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION
        or Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION

    if ui.bodyblock_enabled:Get() then
        print(string.format(
            "[Bodyblock][LOG] ISSUE ORDER: %s to (%.1f,%.1f,%.1f)",
            shouldHold and "HOLD" or "MOVE",
            pos.x, pos.y, pos.z
        ))
    end

    Player.PrepareUnitOrders(
        player,
        orderType,
        nil,
        shouldHold and nil or pos,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
        issuer,
        false, false, false, true,
        nil,
        true
    )
end

-- Main bodyblock logic using selected units
local timer = 0
local function SmartBodyBlock(hero)
    local enemies = Entity.GetHeroesInRadius(hero, 1200) or {}
    for _, enemy in ipairs(enemies) do
        if Entity.IsAlive(enemy) then
            local block_pos = GetSmartBlockPosition(hero, enemy)
            if timer < GameRules.GetGameTime() and last_order:Distance2D(block_pos) > 20 then
                timer      = GameRules.GetGameTime() + (2/30)
                last_order = block_pos
                -- Move or hold to block with selected units
                IssueOrder(block_pos, false, hero)
            end
            return
        end
    end
end

-- Add a debug option to visualize the blocking position
local function DrawBlockingPosition()
    if not ui.bodyblock_enabled:Get() or not ui.bodyblock_key:IsDown() then
        return
    end
    
    local enemies = Entity.GetHeroesInRadius(my_hero, 1200) or {}
    for _, enemy in ipairs(enemies) do
        if Entity.IsAlive(enemy) then
            local block_pos = GetSmartBlockPosition(my_hero, enemy)
            local screen_x, screen_y = Renderer.WorldToScreen(block_pos)
            if screen_x and screen_y then
                Renderer.SetDrawColor(255, 0, 0, 255)
                Renderer.DrawFilledRect(screen_x - 5, screen_y - 5, 10, 10)
                
                -- Draw info about the hero
                local name = NPC.GetUnitName(enemy)
                local size_multiplier = GetHeroSizeMultiplier(enemy)
                local text = string.format("%s (%.2f)", NPC.GetUnitName(enemy):gsub("npc_dota_hero_", ""), size_multiplier)
                Renderer.SetDrawColor(255, 255, 255, 255)
                Renderer.DrawText(screen_x + 10, screen_y, text)
            end
            break
        end
    end
end

--#endregion @Core

example.OnUpdate = function ()
    if not my_hero then
        my_hero = Heroes.GetLocal()
        return
    end
    
    if ui.bodyblock_enabled:Get() and ui.bodyblock_key:IsDown()
       and not NPC.HasModifier(my_hero, "modifier_phase_shift") then
        SmartBodyBlock(my_hero)
    end
end

example.OnDraw = function()
    DrawBlockingPosition()
end

return example