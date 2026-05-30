XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

XPDRP.Inv.Items = {
    metal_scrap = {
        id = "metal_scrap",
        name = "Металлолом",
        category = "Ресурсы",
        model = "models/props_debris/metal_panel02a.mdl",
        value = 60,
        maxStack = 100,
        rarity = "common",
        description = "Базовый материал для крафта и ремонта."
    },
    polymer = {
        id = "polymer",
        name = "Полимер",
        category = "Ресурсы",
        model = "models/props_lab/jar01b.mdl",
        value = 120,
        maxStack = 80,
        rarity = "uncommon",
        description = "Компонент для усиленных деталей."
    },
    weapon_kit = {
        id = "weapon_kit",
        name = "Оружейный набор",
        category = "Компоненты",
        model = "models/weapons/w_suitcase_passenger.mdl",
        value = 2000,
        maxStack = 5,
        rarity = "rare",
        description = "База для сборки огнестрельного вооружения."
    },
    armor_plate = {
        id = "armor_plate",
        name = "Бронепластина",
        category = "Компоненты",
        model = "models/items/battery.mdl",
        value = 1450,
        maxStack = 6,
        rarity = "rare",
        description = "Усиленная пластина для брони."
    },
    med_stim = {
        id = "med_stim",
        name = "Мед-стим",
        category = "Расходники",
        model = "models/healthvial.mdl",
        value = 700,
        maxStack = 10,
        rarity = "uncommon",
        description = "Восстанавливает здоровье при использовании."
    }
}