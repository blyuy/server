XPDRP = XPDRP or {}
XPDRP.Inventory = XPDRP.Inventory or {}

XPDRP.Inventory.Merchants = XPDRP.Inventory.Merchants or {}

function XPDRP.Inventory.RegisterMerchant(id, data)
    if not isstring(id) or id == "" then return end
    if not istable(data) then return end

    data.id = id
    data.name = data.name or id
    data.model = data.model or "models/Humans/Group01/male_07.mdl"
    data.buy = data.buy or {}
    data.sell = data.sell or {}
    data.spawns = data.spawns or {}

    XPDRP.Inventory.Merchants[id] = data
end

function XPDRP.Inventory.GetMerchant(id)
    return XPDRP.Inventory.Merchants[id]
end

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
