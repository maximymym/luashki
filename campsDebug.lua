-- DebugJungleSpots.lua

local script = {}

local function spotPos(spot)
    if spot.pos then return spot.pos end
    local c = (spot.box.min + spot.box.max) * 0.5
    return Vector(c.x, c.y, c.z)
end


function script.OnDraw()
    if not (LIB_HEROES_DATA and LIB_HEROES_DATA.jungle_spots) then return end

    for idx, spot in ipairs(LIB_HEROES_DATA.jungle_spots) do
        local wp = spotPos(spot)
        wp.z = wp.z + 150
        local pos, on = Render.WorldToScreen(wp)
        print(string.format("Camp %d: X=%.0f Y=%.0f", idx, wp.x, wp.y))
        if on then
            local txt = string.format("Camp %d: X=%.0f Y=%.0f", idx, wp.x, wp.y)
            Renderer.SetDrawColor(255, 255, 255, 255)
            Renderer.DrawText(1, pos.x, pos.y, txt)
        end
    end
end

return script
