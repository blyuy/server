XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

XPDRP.Inv.Traders = {
    bunker_master = {
        id = "bunker_master",
        name = "Кладовщик Бункера",
        buys = {
            { id = "metal_scrap", qty = 20, price = 900 },
            { id = "polymer", qty = 10, price = 1600 }
        },
        sells = {
            { id = "armor_plate", qty = 1, price = 2200 },
            { id = "med_stim", qty = 2, price = 1500 }
        }
    },
    gunsmith = {
        id = "gunsmith",
        name = "Оружейник",
        buys = {
            { id = "weapon_kit", qty = 1, price = 2500 }
        },
        sells = {
            { id = "weapon_kit", qty = 1, price = 3200 }
        }
    }
}