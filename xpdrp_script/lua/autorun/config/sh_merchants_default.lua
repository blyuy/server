XPDRP = XPDRP or {}

XPDRP.Inventory.RegisterMerchant("junkdealer", {
    name = "Скупщик",
    model = "models/Humans/Group01/male_08.mdl",
    buy = {
        bandage = 120,
        food_ration = 85,
        lockpick_kit = 300
    },
    sell = {
        metal_scrap = 18,
        wood_plank = 12
    },
    spawns = {
        rp_downtown_v4c_v2 = {
            { pos = Vector(-544, -648, -192), ang = Angle(0, 45, 0) }
        }
    }
})
