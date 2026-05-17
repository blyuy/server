XPDRP = XPDRP or {}

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
