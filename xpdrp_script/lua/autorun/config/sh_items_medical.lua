XPDRP = XPDRP or {}

XPDRP.Inventory.RegisterItem("bandage", {
    name = "Бинт",
    description = "Лечит 20 HP.",
    stack = 15,
    use = function(ply)
        if not IsValid(ply) then return false end
        ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + 20))
        return true
    end
})

XPDRP.Inventory.RegisterItem("food_ration", {
    name = "Паек",
    description = "Восстанавливает голод.",
    stack = 20,
    use = function(ply)
        if not IsValid(ply) or not ply.setDarkRPVar then return false end
        local energy = ply:getDarkRPVar("Energy") or 100
        ply:setDarkRPVar("Energy", math.min(100, energy + 25))
        return true
    end
})
