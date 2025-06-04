-- Puff.lua: Dual Poof Combos with Single Bind and Hover-Cancel (with Main Enable Switch)

local script = {}

-- Local hero retrieval
local myHero = nil
local function GetMyHero()
    if not myHero then myHero = Heroes.GetLocal() end
    return myHero
end

-- UI Setup
local tab      = Menu.Create("Scripts", "User Scripts", "Meepo")
local common   = tab:Create("Puff Farm"):Create("Main")
local ui = {}
-- Main script on/off switch
ui.mainEnabled   = common:Switch("Enable Script", true, "\u{f0e7}")
-- Single bind for both combos
ui.comboKey      = common:Bind("Start/Cancel Combo Key", Enum.ButtonCode.KEY_P)
ui.arrivalThresh = common:Slider("Arrival Threshold",       50, 200, 50, function(v) return tostring(v) end)
ui.drawRadius    = common:Slider("Midpoint Circle Radius",  10, 200, 50, function(v) return tostring(v) end)

-- Per-combo color and enable toggles
for i = 1, 2 do
    local group = tab:Create("Puff Farm"):Create("Combo Slot " .. i)
    ui[i] = {
        enabled     = group:Switch("Enable Slot " .. i, true),
        circleColor = group:ColorPicker("Circle Color " .. i, Color(i == 1 and 255 or 0, i == 1 and 0 or 255, 128)),
    }
end

-- State per combo slot
local combos = {}
for i = 1, 2 do
    combos[i] = {
        midpointData    = nil,
        comboActive     = false,
        selectedUnits   = {},
        splitDest       = {},
        stage           = 0,    -- 0=idle,0.5=search,1=move,2=split,3=wait,4=return,5=poof
        hurtHit         = {},
        searchStartTime = nil,
        searchTimeout   = 0.5,
    }
end

-- Reset a specific slot
local function ResetCombo(idx)
    local state = combos[idx]
    state.midpointData    = nil
    state.comboActive     = false
    state.selectedUnits   = {}
    state.splitDest       = {}
    state.stage           = 0
    state.hurtHit         = {}
    state.searchStartTime = nil
end

-- Helper to get spot position
local function spotPos(spot)
    if spot.pos then return spot.pos end
    local c = (spot.box.min + spot.box.max) * 0.5
    return Vector(c.x, c.y, c.z)
end

-- Compute midpoint for a slot
local function ComputeMidpoint(idx)
    local state = combos[idx]
    local cursorPos = Input.GetWorldCursorPos()
    if not cursorPos or not (LIB_HEROES_DATA and LIB_HEROES_DATA.jungle_spots) then return end
    local spots = LIB_HEROES_DATA.jungle_spots
    table.sort(spots, function(a, b)
        return (spotPos(a) - cursorPos):Length2D() < (spotPos(b) - cursorPos):Length2D()
    end)
    if #spots < 2 then return end
    local a, b = spotPos(spots[1]), spotPos(spots[2])
    local map = GridNav.CreateNpcMap({ GetMyHero() }, true)
    local path = GridNav.BuildPath(a, b, false, map)
    GridNav.ReleaseNpcMap(map)
    if not path or #path < 2 then
        state.midpointData = { mid = (a + b) * 0.5, campA = a, campB = b }
        return
    end
    local total = 0 for i = 2, #path do total = total + (path[i] - path[i-1]):Length2D() end
    local half = total * 0.5
    local acc = 0
    for i = 2, #path do
        local seg = (path[i] - path[i-1]):Length2D()
        if acc + seg >= half then
            local t = (half - acc) / seg
            local p1, p2 = path[i-1], path[i]
            state.midpointData = {
                mid   = Vector(p1.x + (p2.x - p1.x) * t,
                               p1.y + (p2.y - p1.y) * t,
                               p1.z + (p2.z - p1.z) * t),
                campA = a,
                campB = b,
            }
            return
        end
        acc = acc + seg
    end
end

-- Issue orders for a slot
local function IssueOrders(idx)
    local state, cfg = combos[idx], ui[idx]
    local player = Players.GetLocal()
    if state.stage == 1 then
        state.selectedUnits = Player.GetSelectedUnits(player) or {}
        if #state.selectedUnits < 2 then ResetCombo(idx); return end
        state.hurtHit, state.splitDest = {}, {}
        for _, u in ipairs(state.selectedUnits) do
            Player.PrepareUnitOrders(player,
                Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil, state.midpointData.mid, nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                { u }, false, false, false, false, "", true)
        end
    elseif state.stage == 2 then
        state.hurtHit, state.splitDest = {}, {}
        local half = math.ceil(#state.selectedUnits / 2)
        for i, u in ipairs(state.selectedUnits) do
            local dest = (i <= half) and state.midpointData.campA or state.midpointData.campB
            state.splitDest[u] = dest
            Player.PrepareUnitOrders(player,
                Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                nil, dest, nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                { u }, false, false, false, false, "", true)
        end
    elseif state.stage == 4 then
        for _, u in ipairs(state.selectedUnits) do
            Player.PrepareUnitOrders(player,
                Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil, state.midpointData.mid, nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                { u }, false, false, false, false, "", true)
        end
    elseif state.stage == 5 then
        for _, u in ipairs(state.selectedUnits) do
            if Entity.IsNPC(u) and NPC.GetUnitName(u) == "npc_dota_hero_meepo" then
                local ab = NPC.GetAbility(u, "meepo_poof")
                if ab and Ability.IsReady(ab) then
                    Player.PrepareUnitOrders(player,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
                        nil, state.midpointData.mid, ab,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                        { u }, false, true, false, false, "poof_cast", true)
                end
            end
        end
        ResetCombo(idx)
    end
end

-- Main update
function script.OnUpdate()
    -- skip all logic if script disabled
    if not ui.mainEnabled:Get() then return end

    -- handle bind press for start or cancel
    if ui.comboKey:IsPressed() then
        local cursor = Input.GetWorldCursorPos()
        -- first try canceling any slot under cursor
        for i = 1, 2 do
            local s = combos[i]
            if s.comboActive and s.midpointData and cursor and (cursor - s.midpointData.mid):Length2D() <= ui.drawRadius:Get() then
                ResetCombo(i)
                return
            end
        end
        -- if no cancel, start first free slot
        for i = 1, 2 do
            local s, c = combos[i], ui[i]
            if c.enabled:Get() and not s.comboActive then
                s.comboActive = true
                s.stage = 0.5
                s.searchStartTime = os.clock()
                break
            end
        end
    end
    -- process each slot
    for i = 1, 2 do
        local s, c = combos[i], ui[i]
        if not s.comboActive or not c.enabled:Get() then goto cont end
        if s.stage == 0.5 then
            if os.clock() - s.searchStartTime >= s.searchTimeout then
                ComputeMidpoint(i)
                if s.midpointData then
                    s.stage = 1; IssueOrders(i)
                else ResetCombo(i) end
            end; goto cont
        end
        if s.stage == 1 then
            local allArr = true
            for _, u in ipairs(s.selectedUnits) do
                if (Entity.GetAbsOrigin(u) - s.midpointData.mid):Length2D() > ui.arrivalThresh:Get() then allArr = false; break end
            end
            if allArr then s.stage = 2; IssueOrders(i) end
        elseif s.stage == 2 then
            local allHit = true
            for _, u in ipairs(s.selectedUnits) do if not s.hurtHit[u] then allHit = false; break end end
            if allHit then s.stage = 3 end
        elseif s.stage == 3 then s.stage = 4; IssueOrders(i)
        elseif s.stage == 4 then
            local allArr = true
            for _, u in ipairs(s.selectedUnits) do
                if (Entity.GetAbsOrigin(u) - s.midpointData.mid):Length2D() > ui.arrivalThresh:Get() then allArr = false; break end
            end
            if allArr then s.stage = 5; IssueOrders(i) end
        end
        ::cont::
    end
end

-- Draw circles
function script.OnDraw()
    if not ui.mainEnabled:Get() then return end
    for i = 1, 2 do
        local s, c = combos[i], ui[i]
        if not s.comboActive or not c.enabled:Get() or not s.midpointData then goto cont end
        local pos, on = Render.WorldToScreen(s.midpointData.mid)
        if on then
            local col = c.circleColor:Get()
            Renderer.SetDrawColor(math.floor(col.r), math.floor(col.g), math.floor(col.b), 255)
            Renderer.DrawFilledCircle(pos.x, pos.y, ui.drawRadius:Get())
        end
        ::cont::
    end
end

-- Damage callback
function script.OnEntityHurt(data)
    if not ui.mainEnabled:Get() then return end
    local src = data.source
    if not src or not Entity.IsNPC(src) or NPC.GetUnitName(src) ~= "npc_dota_hero_meepo" then return end
    for i = 1, 2 do
        local s = combos[i]
        for _, u in ipairs(s.selectedUnits) do
            if u == src then s.hurtHit[src] = true end
        end
    end
end

return {
    OnUpdate     = script.OnUpdate,
    OnDraw       = script.OnDraw,
    OnEntityHurt = script.OnEntityHurt,
}