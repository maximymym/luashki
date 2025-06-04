local abusik = {}
abusik.LastUpdateTime = 0

function abusik.OnUpdate()
    if ((os.clock() - abusik.LastUpdateTime) < 0.1) then return end
    abusik.LastUpdateTime = os.clock()

    for i = 0, 5 do
        local item = Panorama.GetPanelByName("inventory_slot_" .. i, false)
        if item == nil then goto continue end

        local item_button = item:GetChild(0)
        if item_button == nil then goto continue end

        local hot = item_button:FindChildTraverse("HotkeyContainer")
        if hot == nil then goto continue end

        local hotkey = hot:GetChild(0)
        if hotkey == nil then goto continue end

        local text = hotkey:GetChild(0)
        if text == nil then goto continue end

        local content = text:GetText()
        if content ~= nil and string.sub(content, 1, 5):lower() == "abuse" then
            if string.find(content:lower(), "on") then
                text:SetTextType(3)
                text:SetText("<font color='green'>" .. content .. "</font>")
            elseif string.find(content:lower(), "off") then
                text:SetTextType(3)
                text:SetText("<font color='red'>" .. content .. "</font>")
            end
        end

        ::continue::
    end
end

return abusik
