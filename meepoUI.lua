local function getMainMeepo()
	for _, u in ipairs(NPCs.GetAll()) do
		if (NPC.GetUnitName(u) == "npc_dota_hero_meepo") then
			local ab = NPC.GetAbility(u, "meepo_divided_we_stand");
			local idx = (ab and CustomEntities.GetMeepoIndex(ab)) or 0;
			if (idx <= 0) then
				return u;
			end
		end
	end
end
local function TableContains(t, item)
	if not t then
		return false;
	end
	for _, v in ipairs(t) do
		if (v == item) then
			return true;
		end
	end
	return false;
end
local function TableInsertIfMissing(t, item)
	if not t then
		return;
	end
	if not TableContains(t, item) then
		table.insert(t, item);
	end
end
local comboKeyBind = Menu.Find("Heroes", "Hero List", "Meepo", "Main Settings", "Jungle Settings", "Poof Usage");
local Farmenable = Menu.Find("Heroes", "Hero List", "Meepo", "Main Settings", "Jungle Settings", "Farm Key");
local function Approach(current, target, step)
	if (current < target) then
		return math.min(current + step, target);
	elseif (current > target) then
		return math.max(current - step, target);
	end
	return current;
end
local myFont = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS);
local myFontSize = 20;
local currentYOffset = 0;
local targetYOffset = 0;
local animationSpeed = 1;
local colorAnimSpeed = 5;
local rectCurrColor = Color(255, 0, 0, 0);
local letterCurrColorM = Color(255, 0, 0, 0);
local letterCurrColorD = Color(255, 0, 0, 0);
local currentRectX = nil;
local currentRectW = nil;
local interpSpeedX = 0.1;
local initialized = false;
local centerBg = nil;
local abilityBevel = nil;
local abilityButton = nil;
local function Initialize()
	if initialized then
		return;
	end
	centerBg = Panorama.GetPanelByName("center_bg");
	if not centerBg then
		return;
	end
	local abilityPanel = Panorama.GetPanelByName("Ability1");
	if abilityPanel then
		abilityBevel = abilityPanel:FindChildTraverse("AbilityBevel");
		abilityButton = abilityPanel:FindChildTraverse("AbilityButton");
	end
	initialized = true;
end
function OnDraw()
	if not initialized then
		Initialize();
	end
	if not (initialized and centerBg and abilityBevel and abilityButton and comboKeyBind) then
		return;
	end
	local mainMeepo = getMainMeepo();
	if not mainMeepo then
		return;
	end
	local selectedUnits = Player.GetSelectedUnits(Players.GetLocal());
	if not selectedUnits then
		return;
	end
	local isSelectedMain = false;
	for _, u in ipairs(selectedUnits) do
		if (u == mainMeepo) then
			isSelectedMain = true;
			break;
		end
	end
	if not isSelectedMain then
		return;
	end
	local isEnabled = false;
	if Farmenable then
		isEnabled = Farmenable:IsToggled();
	end
	local targetRectAlpha = (isEnabled and 155) or 0;
	local targetLetterAlpha = (isEnabled and 255) or 0;
	rectCurrColor.a = Approach(rectCurrColor.a, targetRectAlpha, colorAnimSpeed);
	letterCurrColorM.a = Approach(letterCurrColorM.a, targetLetterAlpha, colorAnimSpeed);
	letterCurrColorD.a = Approach(letterCurrColorD.a, targetLetterAlpha, colorAnimSpeed);
	if ((rectCurrColor.a == 0) and (letterCurrColorM.a == 0) and (letterCurrColorD.a == 0)) then
		return;
	end
	local isMEnabled, isDEnabled = false, false;
	if isEnabled then
		local okM, valM = pcall(function()
			return comboKeyBind:Get("To Movement");
		end);
		if (okM and (type(valM) == "boolean")) then
			isMEnabled = valM;
		end
		local okD, valD = pcall(function()
			return comboKeyBind:Get("To Damage");
		end);
		if (okD and (type(valD) == "boolean")) then
			isDEnabled = valD;
		end
		local desiredRectRGB = ((isMEnabled or isDEnabled) and {r=0,g=255,b=0}) or {r=255,g=0,b=0};
		rectCurrColor.r = Approach(rectCurrColor.r, desiredRectRGB.r, colorAnimSpeed);
		rectCurrColor.g = Approach(rectCurrColor.g, desiredRectRGB.g, colorAnimSpeed);
		rectCurrColor.b = Approach(rectCurrColor.b, desiredRectRGB.b, colorAnimSpeed);
		local desiredLetterRGBM = (isMEnabled and {r=0,g=255,b=0}) or {r=255,g=0,b=0};
		letterCurrColorM.r = Approach(letterCurrColorM.r, desiredLetterRGBM.r, colorAnimSpeed);
		letterCurrColorM.g = Approach(letterCurrColorM.g, desiredLetterRGBM.g, colorAnimSpeed);
		letterCurrColorM.b = Approach(letterCurrColorM.b, desiredLetterRGBM.b, colorAnimSpeed);
		local desiredLetterRGBD = (isDEnabled and {r=0,g=255,b=0}) or {r=255,g=0,b=0};
		letterCurrColorD.r = Approach(letterCurrColorD.r, desiredLetterRGBD.r, colorAnimSpeed);
		letterCurrColorD.g = Approach(letterCurrColorD.g, desiredLetterRGBD.g, colorAnimSpeed);
		letterCurrColorD.b = Approach(letterCurrColorD.b, desiredLetterRGBD.b, colorAnimSpeed);
	end
	local function GetAbsolutePosition(panel)
		local x, y = 0, 0;
		local cur = panel;
		while cur do
			x = x + cur:GetXOffset();
			y = y + cur:GetYOffset();
			cur = cur:GetParent();
		end
		return x, y;
	end
	local function GetAbsoluteBounds(panel)
		local x, y = GetAbsolutePosition(panel);
		local b = panel:GetBounds();
		local w = tonumber(b.w) or 0;
		local h = tonumber(b.h) or 0;
		return x, y, w, h;
	end
	local x_cb, y_cb, w_cb, h_cb = GetAbsoluteBounds(centerBg);
	local x_bevel, y_bevel, w_bevel, h_bevel = GetAbsoluteBounds(abilityBevel);
	local x_btn, y_btn, w_btn, h_btn = GetAbsoluteBounds(abilityButton);
	if (currentRectX == nil) then
		currentRectX = x_bevel;
	end
	if (currentRectW == nil) then
		currentRectW = w_bevel;
	end
	local halfRectH = 5;
	local actualYBot = y_cb;
	local actualYTop = actualYBot - 3;
	local blackRectX = currentRectX;
	local blackRectY = actualYTop + currentYOffset;
	local blackRectW = currentRectW;
	local blackRectH = actualYBot - blackRectY;
	local colorRectX = currentRectX;
	local colorRectY = (actualYTop - halfRectH) + currentYOffset;
	local colorRectW = currentRectW;
	local colorRectH = halfRectH;
	local isHoverAnyRect = false;
	if isEnabled then
		if (Input.IsCursorInRect(blackRectX, blackRectY, blackRectW, blackRectH) or Input.IsCursorInRect(colorRectX, colorRectY, colorRectW, colorRectH)) then
			isHoverAnyRect = true;
		end
	end
	local eps = 0.1;
	local horizDone = (math.abs(currentRectX - x_btn) < eps) and (math.abs(currentRectW - w_btn) < eps);
	local vertDone = math.abs(currentYOffset - 0) < eps;
	if (isHoverAnyRect and horizDone) then
		targetYOffset = -20;
	else
		targetYOffset = 0;
	end
	local targetRectX, targetRectW;
	if isHoverAnyRect then
		targetRectX = x_btn;
		targetRectW = w_btn;
	elseif (not isHoverAnyRect and not vertDone) then
		targetRectX = x_btn;
		targetRectW = w_btn;
	else
		targetRectX = x_bevel;
		targetRectW = w_bevel;
	end
	currentRectX = currentRectX + ((targetRectX - currentRectX) * interpSpeedX);
	currentRectW = currentRectW + ((targetRectW - currentRectW) * interpSpeedX);
	if (currentYOffset > targetYOffset) then
		currentYOffset = math.max(currentYOffset - animationSpeed, targetYOffset);
	elseif (currentYOffset < targetYOffset) then
		currentYOffset = math.min(currentYOffset + animationSpeed, targetYOffset);
	end
	local lineColor = Color(0, 0, 0, math.min(125, math.floor(rectCurrColor.a)));
	local lineStart = Vec2(currentRectX, actualYTop + currentYOffset);
	local lineEnd = Vec2(currentRectX + currentRectW, actualYBot);
	Render.FilledRect(lineStart, lineEnd, lineColor, 0, Enum.DrawFlags.None);
	local fullX = currentRectX;
	local fullY_top = (actualYTop - halfRectH) + currentYOffset;
	local fullY_bot = actualYTop + currentYOffset;
	local fullW = currentRectW;
	local halfW = fullW * 0.5;
	local leftX = fullX;
	local leftY = fullY_top;
	local leftW = halfW;
	local leftH = halfRectH;
	Render.FilledRect(Vec2(leftX, leftY), Vec2(leftX + leftW, leftY + leftH), letterCurrColorM, 3, Enum.DrawFlags.RoundCornersTopLeft);
	Render.Shadow(Vec2(leftX + 1, leftY + 1), Vec2((leftX + leftW) - 3, leftY + leftH), letterCurrColorM, 20);
	local rightX = fullX + halfW;
	local rightY = fullY_top;
	local rightW = halfW;
	local rightH = halfRectH;
	Render.FilledRect(Vec2(rightX, rightY), Vec2(rightX + rightW, rightY + rightH), letterCurrColorD, 3, Enum.DrawFlags.RoundCornersTopRight);
	Render.Shadow(Vec2((rightX - 1) + 3, rightY + 1), Vec2(rightX + rightW, rightY + rightH), letterCurrColorD, 20);
	local midX = fullX + halfW;
	local lineTopY = fullY_top;
	local lineBotY = fullY_bot;
	if (currentYOffset < -15) then
		local topY = actualYTop + currentYOffset;
		local bottomY = actualYBot;
		local midY = (topY + bottomY) * 0.5;
		local font = myFont;
		local fontSize = myFontSize;
		local sizeM = Render.TextSize(font, fontSize, "M");
		local sizeD = Render.TextSize(font, fontSize, "D");
		local leftX_text = (currentRectX + (currentRectW * 0.25)) - (sizeM.x * 0.5);
		local rightX_text = (currentRectX + (currentRectW * 0.75)) - (sizeD.x * 0.5);
		local textY = midY - (sizeM.y * 0.5);
		Render.Text(font, fontSize, "M", Vec2(leftX_text, textY), letterCurrColorM);
		Render.Text(font, fontSize, "D", Vec2(rightX_text, textY), letterCurrColorD);
		local lineX = currentRectX + (currentRectW * 0.5);
		local lineTopY2 = midY - (sizeM.y * 0.5);
		local lineBotY2 = midY + (sizeM.y * 0.5);
		Render.FilledRect(Vec2(lineX, lineTopY2), Vec2(lineX + 1, lineBotY2), Color(255, 0, 0, math.floor(letterCurrColorM.a)), 0, Enum.DrawFlags.None);
		local rectM_x = leftX_text;
		local rectM_y = textY;
		local rectM_w = sizeM.x;
		local rectM_h = sizeM.y;
		if (Input.IsCursorInRect(rectM_x, rectM_y, rectM_w, rectM_h) and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1)) then
			local newEnabled = {};
			if isDEnabled then
				TableInsertIfMissing(newEnabled, "To Damage");
			end
			if not isMEnabled then
				TableInsertIfMissing(newEnabled, "To Movement");
			end
			pcall(function()
				comboKeyBind:Set(newEnabled);
			end);
		end
		local rectD_x = rightX_text;
		local rectD_y = textY;
		local rectD_w = sizeD.x;
		local rectD_h = sizeD.y;
		if (Input.IsCursorInRect(rectD_x, rectD_y, rectD_w, rectD_h) and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1)) then
			local newEnabled = {};
			if isMEnabled then
				TableInsertIfMissing(newEnabled, "To Movement");
			end
			if not isDEnabled then
				TableInsertIfMissing(newEnabled, "To Damage");
			end
			pcall(function()
				comboKeyBind:Set(newEnabled);
			end);
		end
	end
end
return {OnDraw=OnDraw};