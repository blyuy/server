NEXUS_MINER_CONFIG = NEXUS_MINER_CONFIG or {}

NEXUS_MINER_CONFIG.OreModel = "models/props_junk/rock001a.mdl"

NEXUS_MINER_CONFIG.Mining = {
    useDistance = 140,
    stepsToWin = 3,
    stepDelay = 1.0,
    firstRoundTime = 1.15,
    roundTimeDecrease = 0.14,
    minRoundTime = 0.65,
    failCooldown = 2.0,
    successCooldown = 8.0
}

NEXUS_MINER_CONFIG.Rewards = {
    -- Требуемые шансы: уголь 60, железо 20, серебро 10, золото 8, алмаз 2
    { id = "coal", chance = 60 },
    { id = "iron", chance = 20 },
    { id = "silver", chance = 10 },
    { id = "gold", chance = 8 },
    { id = "diamond", chance = 2 }
}

-- Если предметы еще не заведены, добавляем базовые дефолты в конфиг инвентаря.
if NEXUS_INV_CONFIG then
    NEXUS_INV_CONFIG.Items = NEXUS_INV_CONFIG.Items or {}

    if not NEXUS_INV_CONFIG.Items.coal then
        NEXUS_INV_CONFIG.Items.coal = {
            name = "Уголь",
            model = "models/props_junk/rock001a.mdl",
            description = "Базовый ресурс шахтера.",
            maxStack = 128,
            canDrop = true,
            canSell = true,
            buyPrice = 0,
            sellPrice = 35
        }
    end

    if not NEXUS_INV_CONFIG.Items.iron then
        NEXUS_INV_CONFIG.Items.iron = {
            name = "Железо",
            model = "models/props_debris/concrete_chunk04a.mdl",
            description = "Металл средней редкости.",
            maxStack = 96,
            canDrop = true,
            canSell = true,
            buyPrice = 0,
            sellPrice = 80
        }
    end

    if not NEXUS_INV_CONFIG.Items.silver then
        NEXUS_INV_CONFIG.Items.silver = {
            name = "Серебро",
            model = "models/props_debris/concrete_chunk05g.mdl",
            description = "Ценный металл.",
            maxStack = 64,
            canDrop = true,
            canSell = true,
            buyPrice = 0,
            sellPrice = 150
        }
    end

    if not NEXUS_INV_CONFIG.Items.gold then
        NEXUS_INV_CONFIG.Items.gold = {
            name = "Золото",
            model = "models/props_debris/concrete_chunk06g.mdl",
            description = "Редкий драгоценный металл.",
            maxStack = 48,
            canDrop = true,
            canSell = true,
            buyPrice = 0,
            sellPrice = 260
        }
    end

    if not NEXUS_INV_CONFIG.Items.diamond then
        NEXUS_INV_CONFIG.Items.diamond = {
            name = "Алмаз",
            model = "models/props_junk/garbage_glassbottle003a.mdl",
            description = "Очень редкий ресурс.",
            maxStack = 24,
            canDrop = true,
            canSell = true,
            buyPrice = 0,
            sellPrice = 500
        }
    end
end