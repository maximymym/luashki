local powerCogsActivator = {}

--#region UI

local tab = Menu.Create("Scripts", "User Scripts", "Auto Cogs")
local group = tab:Create("Options"):Create("Main")
-- Создаём привязку клавиши для активации автокаста Power Cogs.
local powerCogsBind = group:Bind("Activate Power Cogs", Enum.ButtonCode.KEY_0, "panorama/images/spellicons/rattletrap_power_cogs_png.vtex_c")
-- Добавляем слайдер для дистанции активации от 250 до 350, начальное значение 325
local activationDistanceSlider = group:Slider("Activation Distance", 250, 350, 325, function(value)
    return tostring(value)
end)

--#endregion UI

-- Функция для вычисления расстояния между двумя позициями (векторами)
local function GetDistance(pos1, pos2)
  local dx = pos1.x - pos2.x
  local dy = pos1.y - pos2.y
  local dz = pos1.z - pos2.z
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Основной коллбэк OnUpdate, вызываемый каждый игровой кадр
function powerCogsActivator.OnUpdate()
  -- Если привязка не активна (клавиша не нажата), выходим
  if not powerCogsBind:IsDown() then 
    return 
  end

  local myHero = Heroes.GetLocal()
  if not myHero then 
    return 
  end
  
  -- Проверяем, что локальный герой – Rattletrap
  if NPC.GetUnitName(myHero) ~= "npc_dota_hero_rattletrap" then
    return
  end

  -- Получаем способность "rattletrap_power_cogs"
  local powerCogs = NPC.GetAbility(myHero, "rattletrap_power_cogs")
  local powerCogs1 = NPC.GetAbility(myHero, "rattletrap_battery_assault")
  if not powerCogs then 
    return 
  end

  -- Проверяем, что способность доступна для каста (не в кулдауне и хватает маны)
  if not Ability.IsCastable(powerCogs, NPC.GetMana(myHero)) then
    return
  end

  if not powerCogs1 then 
    return 
  end

  -- Получаем позицию локального героя и значение дистанции из слайдера
  local myPos = Entity.GetAbsOrigin(myHero)
  local activationDistance = activationDistanceSlider:Get()
  
  local enemies = Heroes.GetAll()
  -- Проходим по всем вражеским героям
  for _, enemy in ipairs(enemies) do
    if enemy and not Entity.IsSameTeam(enemy, myHero) and Entity.IsAlive(enemy) and not NPC.IsIllusion(enemy) then
      local enemyPos = Entity.GetAbsOrigin(enemy)
      -- Если противник находится ближе, чем значение слайдера, кастуем способность без цели
      if GetDistance(myPos, enemyPos) < activationDistance then
        Ability.CastNoTarget(powerCogs)
        Ability.CastNoTarget(powerCogs1)
        print("Power Cogs activated!")
        return  -- После успешного каста прекращаем проверку
      end
    end
  end
end

return powerCogsActivator
