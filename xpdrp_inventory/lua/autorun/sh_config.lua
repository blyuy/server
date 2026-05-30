XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

XPDRP.Inv.Config = XPDRP.Inv.Config or {
    DataDir = "xpdrp",
    DataFile = "xpdrp/inventory_data.json",
    TraderSpawnsFile = "xpdrp/trader_spawns.json",
    MaxSlots = 48,
    TxCacheSize = 512,
    PickupDistance = 140,
    AdminGroups = {
        superadmin = true,
        admin = true
    },
    PickupWhitelist = {
        -- Example: class = { itemId = "metal_scrap", qty = 2 }
        -- ["spawned_food"] = { itemId = "med_stim", qty = 1 }
    }
}