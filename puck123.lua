local script = {}
local myHero = nil

--#region UI
local tabMain = Menu.Create("Heroes", "Hero List", "Puck")

-- General Master Switch
local generalGroup = tabMain:Create("Auto Phase Shift"):Create("Global")
local ui = {}
ui.masterEnable = generalGroup:Switch("Enable Script", true, "\u{f058}")

-- Attack Debug UI
local attackGroup = tabMain:Create("Auto Phase Shift"):Create("Main")
ui.debugEnabled = attackGroup:Switch("Enable Logic", true, "\u{f00c}")
ui.projectileCount = attackGroup:Slider("Min Projectiles to Dodge", 1, 5, 1, function(v) return tostring(v) end)
--#endregion

-- persistent storage
db.puckIndicator = db.puckIndicator or {}
local info = db.puckIndicator

-- Fonts
local statusFont = Renderer.LoadFont("Arial", 20, Enum.FontCreate.FONTFLAG_ANTIALIAS)

-- Visual interface variables
local currentYOffset = 0
local targetYOffset = 0
local animationSpeed = 1
local colorAnimSpeed = 5
local colorAnimSpeed1 = 15
local rectCurrColor = Color(255, 0, 0, 0)
local letterCurrColor = Color(175, 175, 175, 0)
local currentRectX = nil
local currentRectW = nil
local interpSpeedX = 0.1
local initialized = false
local centerBg = nil
local abilityBevel = nil
local abilityButton = nil

-- Initialize visual interface
local function Initialize()
    if initialized then
        return
    end
    centerBg = Panorama.GetPanelByName("center_bg")
    if not centerBg then
        return
    end
    local abilityPanel = Panorama.GetPanelByName("Ability2")
    if abilityPanel then
        abilityBevel = abilityPanel:FindChildTraverse("AbilityBevel")
        abilityButton = abilityPanel:FindChildTraverse("AbilityButton")
    end
    initialized = true
end

-- Helper functions
local function Approach(current, target, step)
    if (current < target) then
        return math.min(current + step, target)
    elseif (current > target) then
        return math.max(current - step, target)
    end
    return current
end

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

-- Helpers
local function GetMyHero()
    if not myHero then
        myHero = Heroes.GetLocal()
    end
    return myHero
end

-- Projectile tracking
local activeProjectiles = {}  -- [id] = projectile data
local lastCastTime = 0
local projIdCounter = 0  -- For tracking projectiles without IDs

function script.OnProjectile(proj)
    local hero = GetMyHero()
    
    if not hero then return end
    if NPC.GetUnitName(hero) ~= "npc_dota_hero_puck" then return end
    if not ui.masterEnable:Get() or not ui.debugEnabled:Get() then return end
    if not Entity.IsAlive(hero) then return end

    local src = proj.source
    local tgt = proj.target
    
    if tgt == hero and src and not Entity.IsSameTeam(hero, src) then
        local projId = proj.id
        
        if not projId or projId == 0 then
            projIdCounter = projIdCounter + 1
            projId = "gen" .. projIdCounter
        end
        
        activeProjectiles[projId] = {
            source = src,
            time = GameRules.GetGameTime()
        }
    end
end

function GetActiveCount()
    local count = 0
    local now = GameRules.GetGameTime()
    
    for id, data in pairs(activeProjectiles) do
        -- Считаем снаряд активным, если он был создан менее 0.5 секунды назад
        if now - data.time < 0.5 then
            count = count + 1
        else
            activeProjectiles[id] = nil
        end
    end
    
    return count
end

function script.OnUpdate()
    if not ui.masterEnable:Get() or not ui.debugEnabled:Get() then return end

    local hero = GetMyHero()
    if not hero then return end
    if NPC.GetUnitName(hero) ~= "npc_dota_hero_puck" then return end
    if not Entity.IsAlive(hero) then return end
    
    local now = GameRules.GetGameTime()
    
    -- Очищаем старые снаряды
    for id, data in pairs(activeProjectiles) do
        if now - data.time > 1.0 then
            activeProjectiles[id] = nil
        end
    end
    
    if GetActiveCount() >= ui.projectileCount:Get() then
        if now - lastCastTime > 1.0 then
            local ab = NPC.GetAbility(hero, "puck_phase_shift")
            if ab and Ability.IsReady(ab) then
                Ability.CastNoTarget(ab)
                lastCastTime = now
                activeProjectiles = {}
            end
        end
    end
end

function script.OnDraw()
    local hero = GetMyHero()
    if not hero or NPC.GetUnitName(hero) ~= "npc_dota_hero_puck" then return end
    if not ui.masterEnable:Get() then return end

    local selectedUnits = Player.GetSelectedUnits(Players.GetLocal())
    if not selectedUnits then return end

    local isSelectedMain = false
    for _, u in ipairs(selectedUnits) do
        if u == hero then
            isSelectedMain = true
            break
        end
    end
    if not isSelectedMain then return end

    if not initialized then
        Initialize()
    end
    if not (initialized and centerBg and abilityBevel and abilityButton) then
        return
    end

    local isEnabled = ui.debugEnabled:Get()
    
    local x_cb, y_cb, w_cb, h_cb = GetAbsoluteBounds(centerBg)
    local x_bevel, y_bevel, w_bevel, h_bevel = GetAbsoluteBounds(abilityBevel)
    local x_btn, y_btn, w_btn, h_btn = GetAbsoluteBounds(abilityButton)

    if (currentRectX == nil) then
        currentRectX = x_bevel
    end
    if (currentRectW == nil) then
        currentRectW = w_bevel
    end

    local halfRectH = 5
    local actualYBot = y_cb
    local actualYTop = actualYBot - 3

    local blackRectX = currentRectX
    local blackRectY = actualYTop + currentYOffset
    local blackRectW = currentRectW
    local blackRectH = actualYBot - blackRectY

    local isTextVisible = Input.IsCursorInRect(blackRectX, blackRectY, blackRectW, blackRectH)
    local targetRectAlpha = 135

    -- Проверяем, полностью ли растянута панель
    local eps = 0.1
    local isFullyExpanded = (math.abs(currentRectX - x_btn) < eps) and (math.abs(currentRectW - w_btn) < eps)
    
    -- Текст появляется только если панель полностью растянута
    local targetLetterAlpha = (isTextVisible and isFullyExpanded) and 255 or 0

    rectCurrColor.a = Approach(rectCurrColor.a, targetRectAlpha, colorAnimSpeed)
    letterCurrColor.a = Approach(letterCurrColor.a, targetLetterAlpha, colorAnimSpeed1)

    if rectCurrColor.a == 0 then
        return
    end

    local desiredRectRGB = isEnabled and {r=0,g=255,b=0} or {r=255,g=0,b=0}
    rectCurrColor.r = Approach(rectCurrColor.r, desiredRectRGB.r, colorAnimSpeed)
    rectCurrColor.g = Approach(rectCurrColor.g, desiredRectRGB.g, colorAnimSpeed)
    rectCurrColor.b = Approach(rectCurrColor.b, desiredRectRGB.b, colorAnimSpeed)

    local colorRectX = currentRectX
    local colorRectY = (actualYTop - halfRectH) + currentYOffset
    local colorRectW = currentRectW
    local colorRectH = halfRectH

    -- Логика раскрытия всегда работает при masterEnable
    local isHoverAnyRect = false
    if (Input.IsCursorInRect(blackRectX, blackRectY, blackRectW, blackRectH) or 
        Input.IsCursorInRect(colorRectX, colorRectY, colorRectW, colorRectH)) then
        isHoverAnyRect = true
    end

    local vertDone = math.abs(currentYOffset - 0) < eps

    if (isHoverAnyRect and isFullyExpanded) then
        targetYOffset = -20
    else
        targetYOffset = 0
    end

    local targetRectX, targetRectW
    if isHoverAnyRect then
        targetRectX = x_btn
        targetRectW = w_btn
    elseif (not isHoverAnyRect and not vertDone) then
        targetRectX = x_btn
        targetRectW = w_btn
    else
        targetRectX = x_bevel
        targetRectW = w_bevel
    end

    currentRectX = currentRectX + ((targetRectX - currentRectX) * interpSpeedX)
    currentRectW = currentRectW + ((targetRectW - currentRectW) * interpSpeedX)

    if (currentYOffset > targetYOffset) then
        currentYOffset = math.max(currentYOffset - animationSpeed, targetYOffset)
    elseif (currentYOffset < targetYOffset) then
        currentYOffset = math.min(currentYOffset + animationSpeed, targetYOffset)
    end

    local lineColor = Color(0, 0, 0, math.min(125, math.floor(rectCurrColor.a)))
    local lineStart = Vec2(currentRectX, actualYTop + currentYOffset)
    local lineEnd = Vec2(currentRectX + currentRectW, actualYBot)
    Render.FilledRect(lineStart, lineEnd, lineColor, 0, Enum.DrawFlags.None)

    local fullX = currentRectX
    local fullY = (actualYTop - halfRectH) + currentYOffset
    local fullW = currentRectW
    local fullH = halfRectH

    Render.FilledRect(Vec2(fullX, fullY), Vec2(fullX + fullW, fullY + fullH), rectCurrColor, 3, Enum.DrawFlags.RoundCornersTop)
    Render.Shadow(Vec2(fullX + 1, fullY + 1), Vec2(fullX + fullW - 3, fullY + fullH), rectCurrColor, 20)
    
    -- Показываем текст всегда, но с анимированной альфой
    if letterCurrColor.a > 0 then
        local topY = actualYTop + currentYOffset
        local bottomY = actualYBot
        local midY = (topY + bottomY) * 0.5

        local statusText = isEnabled and "ON" or "OFF"
        local size = Render.TextSize(1, 20, statusText)
        local textX = (currentRectX + (currentRectW * 0.5)) - (size.x * 0.5)
        local textY = midY - (size.y * 0.5)

        Render.Text(1, 20, statusText, Vec2(textX, textY), letterCurrColor)
    end

    -- Handle click on the black rectangle
    if Input.IsCursorInRect(blackRectX, blackRectY, blackRectW, blackRectH) and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then
        ui.debugEnabled:Set(not isEnabled)
    end
end

function script.OnScriptLoad()
    local hero = GetMyHero()
end

return script