local script = {}
local myHero = nil


--#region UI
local tabMain = Menu.Create("Heroes", "Hero List", "Kez")

-- General Master Switch
local generalGroup = tabMain:Create("Auto Shado Sai"):Create("Global")
local ui = {}
ui.masterEnable = generalGroup:Switch("Enable Script", true, "\u{f058}")

-- Attack Debug UI
local attackGroup = tabMain:Create("Auto Shado Sai"):Create("Main")
ui.debugEnabled        = attackGroup:Switch("Enable Logic", true,  "\u{f00c}")
ui.attackTickThreshold = attackGroup:Slider("Attack Tick Threshold", 1, 20, 5, function(v) return tostring(v) end)
ui.angleThreshold      = attackGroup:Slider("Angle Threshold (deg)", 0, 180, 20, function(v) return tostring(v) end)
ui.attackRange         = attackGroup:Slider("Attack Range", 300, 1500, 800, function(v) return tostring(v) end)

-- Skill Indicator UI
local indicatorGroup      = tabMain:Create("Auto Shado Sai"):Create("Visual")
ui.size                 = indicatorGroup:Slider("Icon Size",         32,   256, 64,  function(v) return tostring(v) end)
ui.ctrlToDrag           = indicatorGroup:Switch("Ctrl+LMB to Drag",  true,  "\u{f0b2}")
ui.shadowEnable         = indicatorGroup:Switch("Enable Shadow",     true,  "\u{f19c}")
ui.shadowColor          = indicatorGroup:ColorPicker("Shadow Color",    Color(0,128,255), "\u{f0db}")
ui.shadowThickness      = indicatorGroup:Slider("Shadow Thickness",  1,    50,  4,   function(v) return tostring(v) end)
--#endregion

-- persistent storage
db.kezIndicator = db.kezIndicator or {}
local info = db.kezIndicator

-- cache
local iconPath   = "panorama/images/spellicons/kez_shodo_sai_png.vtex_c"
local iconHandle = Render.LoadImage(iconPath)
local iconPos    = Vec2(info.x or 100, info.y or 100)
local dragging   = false
local dragOffset = Vec2(0, 0)

local KEY_CTRL = Enum.ButtonCode.KEY_LCONTROL
local KEY_LMB  = Enum.ButtonCode.KEY_MOUSE1

-- Helpers
local function GetMyHero()
    if not myHero then
        myHero = Heroes.GetLocal()
    end
    return myHero
end

-- Attack data tables
local attackData     = {}  -- melee: [enemy] = { tickCount, hasCasted }
local projectileData = {}  -- ranged: [source] = lastTime

--------------------------------------------------------------------------------
-- OnUpdate: melee attack logic
--------------------------------------------------------------------------------
function script.OnUpdate()
    
    if not ui.masterEnable:Get() or not ui.debugEnabled:Get() then return end

    local hero = GetMyHero()
    if not hero or NPC.GetUnitName(hero) ~= "npc_dota_hero_kez" then return end
    if not hero or not Entity.IsAlive(hero) then return end

    for _, enemy in pairs(Heroes.GetAll()) do
        if not Entity.IsSameTeam(hero, enemy) and Entity.IsAlive(enemy) then
            if not NPC.IsRanged or not NPC.IsRanged(enemy) then
                local act   = NPC.GetActivity(enemy)
                local dist  = (Entity.GetAbsOrigin(enemy) - Entity.GetAbsOrigin(hero)):Length()
                local range = ui.attackRange:Get()

                if (act == Enum.GameActivity.ACT_DOTA_ATTACK or act == Enum.GameActivity.ACT_DOTA_ATTACK2)
                   and dist <= range then

                    local forward   = Entity.GetAbsRotation(enemy):GetForward():Normalized()
                    local direction = (Entity.GetAbsOrigin(hero) - Entity.GetAbsOrigin(enemy)):Normalized()
                    local dot = math.clamp(forward:Dot(direction), -1, 1)
                    local angle = math.deg(math.acos(dot))

                    if angle <= ui.angleThreshold:Get() then
                        local data = attackData[enemy] or { tickCount = 0, hasCasted = false }
                        data.tickCount = data.tickCount + 1
                        attackData[enemy] = data

                        if data.tickCount >= ui.attackTickThreshold:Get() and not data.hasCasted then
                            if NPC.GetUnitName(hero) == "npc_dota_hero_kez" then
                                local ab = NPC.GetAbility(hero, "kez_shodo_sai")
                                if ab and Ability.GetName(ab) == "kez_shodo_sai" then
                                    Ability.CastPosition(ab, Entity.GetAbsOrigin(enemy))
                                    data.hasCasted = true
                                end
                            end
                        end
                    else
                        attackData[enemy] = nil
                    end
                else
                    attackData[enemy] = nil
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- OnProjectile: ranged attack logic
--------------------------------------------------------------------------------
function script.OnProjectile(proj)
    local hero = GetMyHero()
    if not hero or NPC.GetUnitName(hero) ~= "npc_dota_hero_kez" then return end
    if not ui.masterEnable:Get() or not ui.debugEnabled:Get() then return end

    local src  = proj.source
    local tgt  = proj.target
    if not hero or not Entity.IsAlive(hero) then return end
    if tgt ~= hero then return end
    if Entity.IsSameTeam(hero, src) then return end
    if not NPC.IsHero(src) then return end
    if not NPC.IsAttacking(src) then return end

    local now = GameRules.GetGameTime()
    if projectileData[src] and now - projectileData[src] < 1.0 then return end
    projectileData[src] = now

    if NPC.GetUnitName(hero) == "npc_dota_hero_kez" then
        local ab = NPC.GetAbility(hero, "kez_shodo_sai")
        if ab and Ability.GetName(ab) == "kez_shodo_sai" then
            Ability.CastPosition(ab, Entity.GetAbsOrigin(src))
        end
    end
end

--------------------------------------------------------------------------------
-- OnDraw: skill indicator rendering + click & drag
--------------------------------------------------------------------------------
function script.OnDraw()
    local hero = GetMyHero()
    if not hero or NPC.GetUnitName(hero) ~= "npc_dota_hero_kez" then return end
    if not ui.masterEnable:Get() then return end

    local size      = Vec2(ui.size:Get(), ui.size:Get())
    local half      = size * 0.5
    local topLeft   = iconPos - half
    local botRight  = iconPos + half

    local mx,my = Input.GetCursorPos()
    local m     = Vec2(mx, my)

    -- click toggle (no Ctrl)
    if Input.IsKeyDownOnce(KEY_LMB)
      and not (ui.ctrlToDrag:Get() and Input.IsKeyDown(KEY_CTRL))
      and m.x >= topLeft.x and m.x <= botRight.x
      and m.y >= topLeft.y and m.y <= botRight.y then
        ui.debugEnabled:Set(not ui.debugEnabled:Get())
    end

    -- drag (Ctrl+LMB)
    if ui.ctrlToDrag:Get()
      and Input.IsKeyDown(KEY_CTRL)
      and Input.IsKeyDownOnce(KEY_LMB)
      and m.x >= topLeft.x and m.x <= botRight.x
      and m.y >= topLeft.y and m.y <= botRight.y then
        dragging   = true
        dragOffset = iconPos - m
    end
    if dragging and Input.IsKeyDown(KEY_LMB) then
        local cx,cy = Input.GetCursorPos()
        iconPos = Vec2(cx, cy) + dragOffset
    end
    if dragging and not Input.IsKeyDown(KEY_LMB) then
        dragging = false
        -- save position
        info.x = iconPos.x
        info.y = iconPos.y
    end

    -- icon color
    local col = ui.debugEnabled:Get() and Color(255,255,255,255) or Color(128,128,128,255)

    -- shadow
    if ui.shadowEnable:Get() then
        local th       = ui.shadowThickness:Get()
        local rounding = size.x * 0.2
        local shadowTL = topLeft
        local shadowBR = botRight
        Render.Shadow(
            shadowTL, shadowBR,
            ui.shadowColor:Get(), th,
            rounding, Enum.DrawFlags.RoundCornersAll, Vec2(0,0)
        )
    end

    -- icon
    Render.ImageCentered(iconHandle, iconPos, size, col, size.x * 0.2)
end

return script
