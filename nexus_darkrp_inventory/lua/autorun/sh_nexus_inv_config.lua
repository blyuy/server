NEXUS_INV_CONFIG = NEXUS_INV_CONFIG or {}

NEXUS_INV_CONFIG.Settings = {
    inventoryCommand = "nexus_inv_open",
    pickupDistance = 120,
    saveFolder = "nexus_inv",
    allowDropToWorld = true,
    shiftPickupEnabled = true
}

NEXUS_INV_CONFIG.Items = {
    scrap = {
        name = "Металлолом",
        model = "models/props_junk/MetalBucket01a.mdl",
        description = "Обычный материал. Нужен для крафта и торговли.",
        maxStack = 64,
        canDrop = true,
        canSell = true,
        buyPrice = 45,
        sellPrice = 20
    },
    medkit = {
        name = "Аптечка",
        model = "models/items/healthkit.mdl",
        description = "Восстанавливает 25 здоровья при использовании.",
        maxStack = 8,
        canDrop = true,
        canSell = true,
        buyPrice = 350,
        sellPrice = 180,
        useType = "heal",
        healAmount = 25
    },
    lockpick_kit = {
        name = "Набор отмычек",
        model = "models/props_lab/box01a.mdl",
        description = "Расходник для взлома и контрактов.",
        maxStack = 16,
        canDrop = true,
        canSell = true,
        buyPrice = 600,
        sellPrice = 260
    },
    evidence_bag = {
        name = "Пакет улик",
        model = "models/props_lab/box01a.mdl",
        description = "Добывается с ивентов, можно продать на черном рынке.",
        maxStack = 20,
        canDrop = true,
        canSell = true,
        buyPrice = 0,
        sellPrice = 500
    },
    id_card = {
        name = "ID карта",
        model = "models/props_lab/clipboard.mdl",
        description = "Локальный обязательный предмет. Нельзя выбросить.",
        maxStack = 1,
        canDrop = false,
        canSell = false,
        buyPrice = 0,
        sellPrice = 0
    },
    city_radio = {
        name = "Городская рация",
        model = "models/props_lab/citizenradio.mdl",
        description = "Локальный предмет связи. Нельзя выбросить.",
        maxStack = 1,
        canDrop = false,
        canSell = false,
        buyPrice = 0,
        sellPrice = 0
    }
}

-- Локальные предметы выдаются автоматически и не удаляются из инвентаря.
NEXUS_INV_CONFIG.LocalItems = {
    { id = "id_card", amount = 1 },
    { id = "city_radio", amount = 1 }
}

-- Только эти энтити можно подбирать в инвентарь через Shift+E.
NEXUS_INV_CONFIG.PickupEntities = {
    ["sent_hop_bag"] = { id = "medkit", amount = 1, removeOnPickup = true },
    ["item_battery"] = { id = "scrap", amount = 2, removeOnPickup = true },
    ["nexus_inv_worlditem"] = { worldItem = true }
}

-- Ассортимент NPC-торговцев.
NEXUS_INV_CONFIG.Vendor = {
    model = "models/Humans/Group01/Male_07.mdl",
    useDistance = 140,
    stock = {
        { id = "scrap", buyPrice = 45, sellPrice = 20 },
        { id = "medkit", buyPrice = 350, sellPrice = 180 },
        { id = "lockpick_kit", buyPrice = 600, sellPrice = 260 },
        { id = "evidence_bag", buyPrice = 0, sellPrice = 500 }
    }
}