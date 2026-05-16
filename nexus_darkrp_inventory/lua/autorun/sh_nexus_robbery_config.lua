NEXUS_ROBBERY_CONFIG = NEXUS_ROBBERY_CONFIG or {}

NEXUS_ROBBERY_CONFIG.Settings = {
    dataFile = "nexus_inv/robbery_runtime.json",
    policeNotifySound = "buttons/blip1.wav",
    leaveZoneGrace = 5,
    chatCooldown = 1
}

NEXUS_ROBBERY_CONFIG.Targets = {
    default_store = {
        name = "Ограбление магазина",
        displayName = "МАГАЗИН",
        enabled = true,

        -- Можно принудительно поставить модель всем спавнам этого target
        modelOverride = "",

        startDistance = 120,
        duration = 45,
        cooldown = 300,

        useAbsoluteCenter = false,
        zoneCenter = Vector(0, 0, 0),
        zoneOffset = Vector(0, 0, 0),
        zoneMins = Vector(-140, -140, -10),
        zoneMaxs = Vector(140, 140, 150),

        policeTeams = { 2, 3, 4 },

        loot = {
            { id = "scrap", min = 5, max = 12, chance = 100 },
            { id = "evidence_bag", min = 1, max = 2, chance = 55 },
            { id = "lockpick_kit", min = 1, max = 2, chance = 40 }
        }
    }
}

NEXUS_ROBBERY_CONFIG.Spawns = NEXUS_ROBBERY_CONFIG.Spawns or {}