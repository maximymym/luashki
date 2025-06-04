local script = {}

function script.OnUpdate()
    local myHero = Heroes.GetLocal()
    if not myHero then 
        return 
    end

    local index = 0
    while true do
        local item = NPC.GetItemByIndex(myHero, index)
        if item == nil then break end

        local itemName = Ability.GetName(item)
        print("Предмет " .. index .. ": " .. itemName)
        index = index + 1
    end
end

return script
