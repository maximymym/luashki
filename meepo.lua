local script = {};
local tab = Menu.Create("Scripts", "User Scripts", "Meepo", "Fail Switch");
tab:Image("panorama/images/spellicons/kev_meepo_png.vtex_c");
local group = tab:Create("Main");
local ui = {};
ui.enable = group:Switch("Enable Script", false, "\u{f0e7}");
ui.min_meepos = group:Slider("Min Meepos in 600", 1, 5, 2, function(v)
	return tostring(v);
end);
local RADIUS = 600;
local function CountMyMeeposInRange(center, radius)
	local cnt = 0;
	for _, h in pairs(Heroes.GetAll()) do
		if (Entity.IsAlive(h) and (NPC.GetUnitName(h) == "npc_dota_hero_meepo")) then
			if ((Entity.GetAbsOrigin(h) - center):Length2D() <= radius) then
				cnt = cnt + 1;
			end
		end
	end
	return cnt;
end
script.OnPrepareUnitOrders = function(data)
	if not ui.enable:Get() then
		return true;
	end
	if (not data.ability or (Ability.GetName(data.ability) ~= "meepo_megameepo")) then
		return true;
	end
	local isCast = (data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET) or (data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION) or (data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TOGGLE) or (data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TOGGLE_AUTO);
	if not isCast then
		return true;
	end
	local caster = Ability.GetOwner(data.ability);
	if not caster then
		return true;
	end
	local center = Entity.GetAbsOrigin(caster);
	local need = ui.min_meepos:Get();
	local have = CountMyMeeposInRange(center, RADIUS);
	if (have < need) then
		print(string.format("[MegaMeepoGuard] Cast blocked: %d/%d Meepos within %d", have, need, RADIUS));
		return false;
	end
	return true;
end;
return script;