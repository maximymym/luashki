-- AutoStacker for Meepo: dynamic hit-triggered pull + Poof + skill display + UI outlines with fade animation

local tab   = Menu.Create("Scripts", "User Scripts", "Meepo")
local group = tab:Create("AutoStacker"):Create("Main")

-- Binds and settings
local enableSwitch      = group:Switch("Enable Script", false, "\u{f0e7}")
local botBind          = group:Bind("Toggle Meepo Auto Stacker", Enum.ButtonCode.KEY_0, "\u{f021}")
local shadowColorPicker = group:ColorPicker("Shadow Color", Color(255, 0, 0, 255), "\u{f3a8}")
local poofTargetCombo   = group:Combo("Poof Target", { "Cursor", "Main Meepo" }, 0, "\u{f0e7}")

-- Fade animation state
local shadowFadeSpeed = 25      -- alpha change per update

-- Camp manual coordinates
local campStackData = {
    [1]  = { wait = Vector(-750,  4493, 136), pull = Vector(-682, 3881, 236) },
    [2]  = { wait = Vector(3050,  -853, 256), pull = Vector(2795, -177, 256) },
    [3]  = { wait = Vector(3949, -4921, 128), pull = Vector(4200, -4323, 128) },
    [4]  = { wait = Vector(8183,  -666, 256), pull = Vector(8204, -1369, 256) },
    [5]  = { wait = Vector(-4756, 4353, 128), pull = Vector(-4713, 4958, 128) },
    [6]  = { wait = Vector(4318, -4110, 128), pull = Vector(3640, -4309, 128) },
    [7]  = { wait = Vector(-1147,-3948, 144), pull = Vector(-625, -4432, 136) },
    [8]  = { wait = Vector(257,  -4751, 136), pull = Vector(333,  -4101, 254) },
    [9]  = { wait = Vector(-4452,  292, 256), pull = Vector(-4891, 1201, 128) },
    [10] = { wait = Vector(4077,  -301, 256), pull = Vector(4154,-1364, 128) },
    [11] = { wait = Vector(-1588,-4850, 128), pull = Vector(-528,-4853, 130) },
    [12] = { wait = Vector(1742, 8205, 128), pull = Vector(792,  8152, 128) },
    [13] = { wait = Vector(738,  3996, 133), pull = Vector(-78,  3932, 136) },
    [14] = { wait = Vector(-4213, 821, 256), pull = Vector(-5012,1234, 128) },
    [15] = { wait = Vector(220, -7914, 136), pull = Vector(954, -8538, 136) },
    [16] = { wait = Vector(-2517,-8010, 136), pull = Vector(-2690,-7154, 128) },
    [17] = { wait = Vector(-463, 7879, 136), pull = Vector(-551, 6961, 128) },
    [18] = { wait = Vector(-4744,7736,   8), pull = Vector(-4820,7121,   0) },
    [19] = { wait = Vector(1294, 2985, 128), pull = Vector(1683, 3710, 128) },
    [20] = { wait = Vector(8148, 1209, 256), pull = Vector(7681,  695, 256) },
    [21] = { wait = Vector(-7835,-183, 256), pull = Vector(-7436, 685, 256) },
    [22] = { wait = Vector(-3544,7570,   0), pull = Vector(-4521,7474,   8) },
    [23] = { wait = Vector(-2599,4254, 256), pull = Vector(-2651,5138, 256) },
    [24] = { wait = Vector(3522,-8186,   8), pull = Vector(4028,-7376,   0) },
    [25] = { wait = Vector(1501,-4208, 256), pull = Vector( 657,-3909, 256) },
    [26] = { wait = Vector(-4338,4903, 128), pull = Vector(-5198,4877, 128) },
    [27] = { wait = Vector(-7781,-1344,256), pull = Vector(-7538,-550, 256) },
    [28] = { wait = Vector(4781,-7812,   8), pull = Vector(4464,-7166, 128) },
}

-- State
local botActive        = false
local wasBotBindPressed = false
local AssignedUnits    = {}
local UnitAssignments  = {}
local UnitStates       = {}      -- 0=init,1=wait_sent,2=attack_sent,3=hit_detected,4=done
local CampStrikeCenters= {}
local MeepoIndices     = {}      -- store index from Divided We Stand (0 for main Meepo)
local UnitDisabled     = {}      -- true if external order arrived for Meepo
local UnitShadowAlpha  = {}      -- current shadow alpha for each Meepo

-- Cached UI bounds (computed once per toggle)
local PanelBounds = {}

-- ////////////////////////////////////////////////////////////////////////////
-- Utility helpers
-- ////////////////////////////////////////////////////////////////////////////

-- In‑game time
local function getIngameTime()
    local t = GameRules.GetGameTime() - GameRules.GetGameStartTime()
    return math.max(t, 0)
end

-- Camp utilities
local function getBoxCenter(camp)
    local box = Camp.GetCampBox(camp)
    if not box or not box.min or not box.max then return nil end
    return Vector((box.min:GetX()+box.max:GetX())/2,
                  (box.min:GetY()+box.max:GetY())/2,
                  (box.min:GetZ()+box.max:GetZ())/2)
end

local function findRealCampByWait(waitPos)
    local camps = Camps.GetAll() or {}
    local best, dist = nil, math.huge
    for _, c in ipairs(camps) do
        local center = getBoxCenter(c)
        if center then
            local d = (center - waitPos):Length2D()
            if d < dist then dist, best = d, c end
        end
    end
    return best
end

-- Assign Meepos to camps evenly / greedily
local function assignUnitsToCamps(units)
    local assignments = {}
    local available   = {}
    for idx in pairs(campStackData) do
        table.insert(available, idx)
    end

    if #units <= #available then
        for _, unit in ipairs(units) do
            local bestIdx, bestD = nil, math.huge
            local pos = Entity.GetAbsOrigin(unit)
            if pos then
                for i, campIdx in ipairs(available) do
                    local d = (campStackData[campIdx].wait - pos):Length2D()
                    if d < bestD then bestD, bestIdx = d, campIdx end
                end
            end
            assignments[unit] = bestIdx
            -- remove chosen camp
            for i, v in ipairs(available) do
                if v == bestIdx then table.remove(available, i); break end
            end
        end
    else
        -- more Meepos than camps – greedily assign to nearest camp (duplicates possible)
        for _, unit in ipairs(units) do
            local bestIdx, bestD = nil, math.huge
            local pos = Entity.GetAbsOrigin(unit)
            if pos then
                for idx, data in pairs(campStackData) do
                    local d = (data.wait - pos):Length2D()
                    if d < bestD then bestD, bestIdx = d, idx end
                end
            end
            assignments[unit] = bestIdx
        end
    end
    return assignments
end

-- ////////////////////////////////////////////////////////////////////////////
-- Meepo hit detection (for pull timing)
-- ////////////////////////////////////////////////////////////////////////////
function OnEntityHurt(data)
    if not enableSwitch:Get() then return end
    if not botActive then return end

    local src = data.source
    if not src or not Entity.IsNPC(src) then return end
    if NPC.GetUnitName(src) ~= "npc_dota_hero_meepo" then return end

    if UnitStates[src] == 2 then -- attack‑move sent, waiting for 1st hit
        local tgt = data.target
        if tgt and Entity.IsNPC(tgt) then
            if (Entity.GetAbsOrigin(src) - Entity.GetAbsOrigin(tgt)):Length2D() <= 300 then
                UnitStates[src] = 3 -- hit detected → pull phase
            end
        end
    end
end

-- ////////////////////////////////////////////////////////////////////////////
-- Initialize / reset on toggle
-- ////////////////////////////////////////////////////////////////////////////

-- возвращает handle главного Meepo (index 0) или nil, если его нет в живых
local function getMainMeepo()
    local player = Players.GetLocal()
    if not player then return nil end
    local unit
    player = unit
    return unit

end


local function initializeAssignments()
    local p = Players.GetLocal()
    AssignedUnits = {}

    for _, u in ipairs(Player.GetSelectedUnits(p) or {}) do
        if Entity.IsNPC(u) and NPC.GetUnitName(u) == "npc_dota_hero_meepo" then
            table.insert(AssignedUnits, u)
        end
    end

    if #AssignedUnits == 0 then
        print("[MeepoAutoStacker] No Meepos selected.")
        return false
    end

    UnitAssignments = assignUnitsToCamps(AssignedUnits)
    UnitStates      = {}
    MeepoIndices    = {}
    UnitDisabled    = {}
    UnitShadowAlpha = {}

    for _, u in ipairs(AssignedUnits) do
        UnitStates[u]  = 0
        UnitShadowAlpha[u] = 0
        local ab = NPC.GetAbility(u, "meepo_divided_we_stand")
        MeepoIndices[u] = ab and CustomEntities.GetMeepoIndex(ab) or 0
    end

    CampStrikeCenters = {}
    for idx, data in pairs(campStackData) do
        local real = findRealCampByWait(data.wait)
        CampStrikeCenters[idx] = real and getBoxCenter(real)
    end

    return true
end

-- ////////////////////////////////////////////////////////////////////////////
-- UI bounds caching (executed once per toggle)
-- ////////////////////////////////////////////////////////////////////////////
local function GetAbsolutePosition(panel)
    local x, y = 0, 0
    local cur = panel
    while cur do
        x = x + cur:GetXOffset()
        y = y + cur:GetYOffset()
        cur = cur:GetParent()
    end
    return x, y
end

local function GetAbsoluteBounds(panel)
    local x, y = GetAbsolutePosition(panel)
    local b = panel:GetBounds()
    local w = tonumber(b.w) or 0
    local h = tonumber(b.h) or 0
    return x, y, w, h
end

local function CachePanelBounds()
    PanelBounds = {}

    local heroDisplay = Panorama.GetPanelByName("HeroDisplay")
    if not heroDisplay then return end

    for idx = 0, 10 do -- enough for main + 10 clones
        local row = heroDisplay:FindChildTraverse("HeroDisplayRow" .. idx)
        if row then
            local c1 = row:FindChildTraverse("HeroDisplayContainer")
            local c2 = row:FindChildTraverse("ProgressContainer")
            if c1 and c2 then
                local x1, y1, w1, h1 = GetAbsoluteBounds(c1)
                local x2, y2, w2, h2 = GetAbsoluteBounds(c2)
                local x0 = math.min(x1, x2)
                local y0 = math.min(y1, y2)
                local x3 = math.max(x1 + w1, x2 + w2)
                local y3 = math.max(y1 + h1, y2 + h2)

                PanelBounds[idx] = { x0 = x0, y0 = y0, x1 = x3, y1 = y3 }
            end
        end
    end
end

-- ////////////////////////////////////////////////////////////////////////////
-- Prevent bot logic on units receiving external orders
-- ////////////////////////////////////////////////////////////////////////////
function OnPrepareUnitOrders(data)
    if not enableSwitch:Get() then return end
    if not botActive then return true end

    local targets = {}
    if data.npc and Entity.IsNPC(data.npc) then
        table.insert(targets, data.npc)
    elseif data.units and #data.units > 0 then
        for _, idx in ipairs(data.units) do
            table.insert(targets, idx)
        end
    else
        for _, unit in ipairs(Player.GetSelectedUnits(Players.GetLocal()) or {}) do
            if Entity.IsNPC(unit) then
                table.insert(targets, Entity.GetIndex(unit))
            end
        end
    end

    for _, t in ipairs(targets) do
        for _, u in ipairs(AssignedUnits) do
            if (type(t) == "userdata" and t == u) or (type(t) == "number" and t == Entity.GetIndex(u)) then
                UnitDisabled[u] = true
                print("[MeepoAutoStacker] External order on Meepo – combo disabled for", u)
            end
        end
    end

    return true
end

-- ////////////////////////////////////////////////////////////////////////////
-- Main update (logic + fade)
-- ////////////////////////////////////////////////////////////////////////////
function OnUpdate()
    if not enableSwitch:Get() then return end
    local p       = Players.GetLocal()
    local pressed = botBind:IsPressed()

    -- Toggle bot
    if pressed and not wasBotBindPressed then
        botActive = not botActive
        print("[MeepoAutoStacker] Toggled:", botActive)
        if botActive then
            if initializeAssignments() then
                CachePanelBounds()          -- ← compute UI bounds once per toggle
            else
                botActive = false
            end
        end
    end
    wasBotBindPressed = pressed

    -- Early exit if bot inactive and all alphas faded
    local anyVisible = false
    for _, u in ipairs(AssignedUnits) do
        if UnitShadowAlpha[u] and UnitShadowAlpha[u] > 0 then anyVisible = true; break end
    end
    if not botActive and not anyVisible then return end

    local sec = math.floor(getIngameTime() % 60)

    -- Core stacking logic
    for _, u in ipairs(AssignedUnits) do
        if not UnitDisabled[u] then
            local state = UnitStates[u]
            local idx   = UnitAssignments[u]
            local data  = campStackData[idx]
            local center= CampStrikeCenters[idx]

            if data then
                if sec < 53 and state == 0 then
                    Player.PrepareUnitOrders(p, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, data.wait, nil,
                                             Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS, {u}, false)
                    UnitStates[u] = 1

                elseif sec >= 53 and sec < 54 and state == 1 and center then
                    Player.PrepareUnitOrders(p, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE, nil, center, nil,
                                             Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS, {u}, false)
                    UnitStates[u] = 2

                elseif state == 3 then
                    Player.PrepareUnitOrders(p, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, data.pull, nil,
                                             Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS, {u}, false)
                                             local poof = NPC.GetAbility(u, "meepo_poof")
                                             if poof and Ability.IsReady(poof) then
                                                 if poofTargetCombo:Get() == 1 then                   -- «Main Meepo»
                                                     local main = getMainMeepo()
                                                     if main then
                                                         Player.PrepareUnitOrders(
                                                             p,
                                                             Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET,
                                                             main,                                    -- таргет-юнит
                                                             Vector(),
                                                             poof,
                                                             Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                                                             { u },
                                                             true
                                                         )
                                                     else                                             -- клона 0 нет → fallback
                                                         Player.PrepareUnitOrders(
                                                             p,
                                                             Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
                                                             nil,
                                                             Input.GetWorldCursorPos(),
                                                             poof,
                                                             Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                                                             { u },
                                                             true
                                                         )
                                                     end
                                                 else                                                 -- «Cursor»
                                                     Player.PrepareUnitOrders(
                                                         p,
                                                         Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
                                                         nil,
                                                         Input.GetWorldCursorPos(),
                                                         poof,
                                                         Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
                                                         { u },
                                                         true
                                                     )
                                                 end
                                             end
                                             
                    UnitStates[u] = 4
                end
            end
        end
    end

    -- Disable bot once all Meepos finished or disabled
    local done = true
    for _, u in ipairs(AssignedUnits) do
        if not UnitDisabled[u] and UnitStates[u] ~= 4 then
            done = false; break
        end
    end
    if done then botActive = false end

    -- Shadow alpha fade per Meepo
    for _, u in ipairs(AssignedUnits) do
        local target = (botActive and not UnitDisabled[u]) and 255 or 0
        local cur    = UnitShadowAlpha[u] or 0
        if cur < target then
            cur = math.min(cur + shadowFadeSpeed, 255)
        else
            cur = math.max(cur - shadowFadeSpeed, 0)
        end
        UnitShadowAlpha[u] = cur
    end
end

-- ////////////////////////////////////////////////////////////////////////////
-- OnDraw – uses *cached* panel bounds, no Panorama work every frame
-- ////////////////////////////////////////////////////////////////////////////
function OnDraw()
    if not enableSwitch:Get() then return end
    -- Draw shadow only if we have cached bounds
    if not PanelBounds or next(PanelBounds) == nil then return end

    for _, u in ipairs(AssignedUnits) do
        local alpha = UnitShadowAlpha[u] or 0
        if alpha > 0 then
            local idx = MeepoIndices[u] or 0
            if idx == -1 then idx = 0 end
            local b = PanelBounds[idx]
            if b then
                local baseColor = shadowColorPicker:Get() or Color(255, 0, 0, 255)
                local color = Color(baseColor.r, baseColor.g, baseColor.b, alpha)
                local thickness = 26
                local rounding  = 8
                local flags     = Enum.DrawFlags.ShadowCutOutShapeBackground
                Render.Shadow(Vec2(b.x0, b.y0), Vec2(b.x1, b.y1), color, thickness, rounding, flags)
            end
        end
    end
end

return {
    OnUpdate            = OnUpdate,
    OnDraw              = OnDraw,
    OnEntityHurt        = OnEntityHurt,
    OnPrepareUnitOrders = OnPrepareUnitOrders,
}
