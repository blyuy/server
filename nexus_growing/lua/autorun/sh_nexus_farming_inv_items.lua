local function ensureItems()
    if not NEXUS_INV_CONFIG then return false end
    NEXUS_INV_CONFIG.Items = NEXUS_INV_CONFIG.Items or {}

    local items = NEXUS_INV_CONFIG.Items

    if not items.parsley_seed then
        items.parsley_seed = {
            name = "Семя особой кудрявой петрушки",
            model = "models/props_lab/box01a.mdl",
            description = "Семена для посадки в горшок.",
            maxStack = 64,
            canDrop = true,
            canSell = false,
            buyPrice = 250,
            sellPrice = 0
        }
    end

    if not items.parsley_soil then
        items.parsley_soil = {
            name = "Пакет земли",
            model = "models/props_junk/garbage_bag001a.mdl",
            description = "Питательный грунт.",
            maxStack = 64,
            canDrop = true,
            canSell = false,
            buyPrice = 180,
            sellPrice = 0
        }
    end

    if not items.parsley_water then
        items.parsley_water = {
            name = "Бутыль воды",
            model = "models/props_junk/garbage_plasticbottle003a.mdl",
            description = "Для полива.",
            maxStack = 64,
            canDrop = true,
            canSell = false,
            buyPrice = 120,
            sellPrice = 0
        }
    end

    if not items.parsley_dried_pack then
        items.parsley_dried_pack = {
            name = "Пакет сушеной травы",
            model = "models/props_lab/box01a.mdl",
            description = "Финальный продукт фермерства.",
            maxStack = 32,
            canDrop = true,
            canSell = true,
            buyPrice = 0,
            sellPrice = 1400
        }
    end

    return true
end

local tries = 0
timer.Create("NexusFarmEnsureInvItems", 1, 20, function()
    tries = tries + 1
    if ensureItems() then
        timer.Remove("NexusFarmEnsureInvItems")
    elseif tries >= 20 then
        timer.Remove("NexusFarmEnsureInvItems")
    end
end)