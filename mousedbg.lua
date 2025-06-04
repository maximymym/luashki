-- debug_mouse_pos_by_bind_integer.lua

-----------------------------------------------
-- UI: создаём вкладку, группу и биндинг для отладки позиции мыши
-----------------------------------------------
local tab = Menu.Create("Scripts", "User Scripts", "MousePosDebug")
local group = tab:Create("Options"):Create("Main")
local debugBind = group:Bind("Show Mouse Position", Enum.ButtonCode.KEY_0, "panorama/images/spellicons/default_icon.vtex_c")

-- Глобальная переменная для хранения полученных координат мыши
local debugMousePos = nil

-- Функция для округления до целого (стандартное округление)
local function round(num)
    return math.floor(num + 0.5)
end

-----------------------------------------------
-- Функция OnUpdate: получает мировую позицию курсора, если биндинг нажат
-----------------------------------------------
function OnUpdate()
    if debugBind:IsPressed() then
        -- Получаем мировую позицию курсора (на миникарте/в мире)
        debugMousePos = MiniMap.GetMousePosInWorld()
        if debugMousePos.x ~= 0 or debugMousePos.y ~= 0 or debugMousePos.z ~= 0 then
            print(string.format("Vector(%d, %d, %d),", 
                round(debugMousePos.x), round(debugMousePos.y), round(debugMousePos.z)))
        else
            print("[DEBUG] Mouse not on minimap (returned (0,0,0))")
        end
    else
        debugMousePos = nil
    end
end

-----------------------------------------------
-- Функция OnDraw: отрисовка позиции мыши для отладки
-----------------------------------------------
function OnDraw()
    if debugMousePos then
        local x, y, visible = Renderer.WorldToScreen(debugMousePos)
        if visible then
            Renderer.SetDrawColor(255, 0, 0, 255)
            Renderer.DrawText(1, x, y, 
                string.format("(%d, %d, %d)", 
                    round(debugMousePos.x), round(debugMousePos.y), round(debugMousePos.z)))
        end
    end
end

return {
    OnUpdate = OnUpdate,
    OnDraw = OnDraw
}
