XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

XPDRP.Inv.Recipes = {
    armor_plate = {
        id = "armor_plate",
        name = "Усиленная бронепластина",
        category = "Броня",
        station = "Верстак инженера",
        ingredients = {
            { id = "metal_scrap", qty = 25 },
            { id = "polymer", qty = 8 }
        },
        result = { id = "armor_plate", qty = 1 }
    },
    weapon_kit = {
        id = "weapon_kit",
        name = "Оружейный набор",
        category = "Оружие",
        station = "Оружейный стол",
        ingredients = {
            { id = "metal_scrap", qty = 40 },
            { id = "polymer", qty = 12 }
        },
        result = { id = "weapon_kit", qty = 1 }
    },
    med_stim = {
        id = "med_stim",
        name = "Мед-стим",
        category = "Медицина",
        station = "Мед-станция",
        ingredients = {
            { id = "polymer", qty = 3 }
        },
        result = { id = "med_stim", qty = 1 }
    }
}