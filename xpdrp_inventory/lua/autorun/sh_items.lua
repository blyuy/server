XPDRP = XPDRP or {}
XPDRP.Inventory = XPDRP.Inventory or {}

XPDRP.Inventory.Items = XPDRP.Inventory.Items or {}

function XPDRP.Inventory.RegisterItem(id, data)
    if not isstring(id) or id == "" then return end
    if not istable(data) then return end

    data.id = id
    data.name = data.name or id
    data.stack = math.max(1, math.floor(data.stack or XPDRP.Inventory.Config.MaxStack or 1))
    data.icon = data.icon or "icon16/box.png"
    data.description = data.description or ""

    XPDRP.Inventory.Items[id] = data
end

function XPDRP.Inventory.GetItem(id)
    return XPDRP.Inventory.Items[id]
end

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

XPDRP.Inventory.RegisterItem("metal_scrap", {
    name = "Металлолом",
    description = "Базовый материал для крафта.",
    stack = 80
})

XPDRP.Inventory.RegisterItem("wood_plank", {
    name = "Доски",
    description = "Базовый строительный материал.",
    stack = 80
})

XPDRP.Inventory.RegisterItem("lockpick_kit", {
    name = "Набор отмычек",
    description = "Расходник для взлома.",
    stack = 10
})

XPDRP.Inventory.RegisterItem("food_ration", {
    name = "Паек",
    description = "Восстанавливает голод.",
    stack = 20,
    use = function(ply)
        if not IsValid(ply) then return false end
        if not ply.setDarkRPVar then return false end

        local energy = ply:getDarkRPVar("Energy") or 100
        local newEnergy = math.min(100, energy + 25)
        ply:setDarkRPVar("Energy", newEnergy)
        return true
    end
})
