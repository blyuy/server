XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

XPDRP.Inv.LootBoxes = {
    basic_crate = {
        id = "basic_crate",
        name = "Базовый лутбокс",
        model = "models/Items/item_item_crate.mdl",
        refresh = 600,
        loot = {
            { itemId = "metal_scrap", chance = 0.85, min = 8, max = 20 },
            { itemId = "polymer", chance = 0.55, min = 3, max = 8 },
            { itemId = "med_stim", chance = 0.20, min = 1, max = 2 }
        }
    },
    military_crate = {
        id = "military_crate",
        name = "Военный лутбокс",
        model = "models/Items/ammocrate_ar2.mdl",
        refresh = 600,
        loot = {
            { itemId = "metal_scrap", chance = 0.65, min = 10, max = 24 },
            { itemId = "polymer", chance = 0.70, min = 6, max = 14 },
            { itemId = "armor_plate", chance = 0.30, min = 1, max = 2 },
            { itemId = "weapon_kit", chance = 0.15, min = 1, max = 1 }
        }
    }
}