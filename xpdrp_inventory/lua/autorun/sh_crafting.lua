XPDRP = XPDRP or {}
XPDRP.Inventory = XPDRP.Inventory or {}

XPDRP.Inventory.Recipes = XPDRP.Inventory.Recipes or {}

function XPDRP.Inventory.RegisterRecipe(id, data)
    if not isstring(id) or id == "" then return end
    if not istable(data) then return end
    if not isstring(data.result) then return end

    data.id = id
    data.name = data.name or id
    data.amount = math.max(1, math.floor(data.amount or 1))
    data.require = data.require or {}

    XPDRP.Inventory.Recipes[id] = data
end

function XPDRP.Inventory.GetRecipe(id)
    return XPDRP.Inventory.Recipes[id]
end

XPDRP.Inventory.RegisterRecipe("craft_lockpick", {
    name = "Собрать набор отмычек",
    result = "lockpick_kit",
    amount = 1,
    require = {
        metal_scrap = 4,
        wood_plank = 2
    }
})

XPDRP.Inventory.RegisterRecipe("craft_ration", {
    name = "Сделать паек",
    result = "food_ration",
    amount = 1,
    require = {
        wood_plank = 1,
        metal_scrap = 1
    }
})
