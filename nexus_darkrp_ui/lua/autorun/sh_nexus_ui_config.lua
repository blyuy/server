NEXUS_UI_CONFIG = NEXUS_UI_CONFIG or {}

NEXUS_UI_CONFIG.Lockpick = {
    requiredHits = 6,
    roundTime = 42,
    maxUseDistance = 120,
    inputCooldown = 0.16,
    closeOnMiss = false,
    missPenalty = 1,
    markerSpeed = 0.78,
    zoneSize = 0.2,
    zoneMin = 0.08,
    zoneMax = 0.72,
    panelWidth = 440,
    panelHeight = 220,
    showChatCommands = true
}

NEXUS_UI_CONFIG.Tab = {
    refreshInterval = 0.4,
    openAnimSpeed = 10,
    rowAnimSpeed = 12,
    rowHeight = 46,
    expandedRowHeight = 130,
    contentTop = 104,
    actionInsetX = 12,
    actionGap = 10,
    actionTopOffset = 30,
    actionButtonHeight = 36,
    teleportCooldown = 0.4,
    adminOnlyTeleport = true,
    samCommand = "sam teleport",
    fallbackTeleportIfSamMissing = true,
    actions = {
        {
            id = "copy_steamid",
            label = "Скопировать SteamID",
            icon = "icon16/page_copy.png",
            enabled = true
        },
        {
            id = "open_steam_profile",
            label = "Открыть профиль Steam",
            icon = "icon16/world_link.png",
            enabled = true
        },
        {
            id = "teleport_sam",
            label = "Телепортировать (sam teleport)",
            icon = "icon16/arrow_right.png",
            enabled = true
        }
    }
}