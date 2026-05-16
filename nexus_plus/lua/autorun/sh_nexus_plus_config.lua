NEXUS_PLUS_CONFIG = NEXUS_PLUS_CONFIG or {}

NEXUS_PLUS_CONFIG.General = {
    brand = "NEXUS DARKRP",
    maxUseDistance = 140
}

NEXUS_PLUS_CONFIG.Theme = {
    background = Color(16, 18, 26, 238),
    panel = Color(28, 31, 44, 245),
    panelHover = Color(39, 50, 68, 245),
    panelSoft = Color(23, 26, 38, 220),
    mutedText = Color(165, 172, 196, 230),
    text = Color(240, 244, 252, 255),
    accent = Color(74, 123, 214, 255),
    accentSoft = Color(53, 86, 154, 240)
}

NEXUS_PLUS_CONFIG.F4 = {
    openAnimSpeed = 10,
    toggleCooldown = 0.2,
    widthFactor = 0.8,
    heightFactor = 0.82,
    cardHeight = 78,
    modelPanelWidth = 84,
    modelFOV = 34,
    defaultModel = "models/props_c17/oildrum001.mdl",
    defaultAmmoModel = "models/items/boxsrounds.mdl",
    showCommandsCategory = true,
    categories = {
        { id = "inventory", label = "Инвентарь" },
        { id = "jobs", label = "Работы" },
        { id = "entities", label = "Энтити" },
        { id = "shipments", label = "Поставки" },
        { id = "ammo", label = "Патроны" },
        { id = "commands", label = "Команды" }
    },
    quickCommands = {
        { label = "Дроп денег 1000", cmd = "say /dropmoney 1000" },
        { label = "Продать все двери", cmd = "darkrp sellalldoors" },
        { label = "Сброс розыска", cmd = "say /warrant" }
    }
}

NEXUS_PLUS_CONFIG.CMenu = {
    openAnimSpeed = 12,
    width = 390,
    anchorRight = true,
    rightOffset = 24,
    leftOffset = 24,
    topOffset = 210,
    itemHeight = 42,
    commands = {
        { label = "F4 Меню", cmd = "nexus_plus_f4" },
        { label = "Меню двери", cmd = "nexus_plus_door_menu" },
        { label = "Выбросить деньги 1000", cmd = "say /dropmoney 1000" },
        { label = "Демка", cmd = "record nexus_demo" },
        { label = "Остановить демку", cmd = "stop" }
    }
}

NEXUS_PLUS_CONFIG.Door = {
    maxTitleLength = 48,
    openAnimSpeed = 12,
    width = 460,
    height = 430,
    buyDoorCommand = "/buydoor",
    sellDoorCommand = "/selldoor",
    titleCommand = "/title",
    doorGroupChatCommand = "/setdoorgroup",
    superadminActions = {
        { id = "unlock", label = "Разблокировать дверь" },
        { id = "lock", label = "Заблокировать дверь" },
        { id = "open", label = "Открыть дверь" },
        { id = "close", label = "Закрыть дверь" },
        { id = "set_ownable", label = "Сделать продаваемой" },
        { id = "set_unownable", label = "Сделать непродаваемой" },
        { id = "set_group", label = "Применить группу двери" }
    }
}

NEXUS_PLUS_CONFIG.HUD = {
    enabled = true,
    hideDefaultHud = true,
    showAgenda = true,
    showAmmo = true,
    showPlayerInfo = true,
    showTopStatus = true,
    show3D2DTargetInfo = true,
    show3D2DPlayerInfo = true,
    show3D2DDoorInfo = true,
    info3D2DScale = 0.14,
    doorInfoOffset = 2,
    targetInfoDistance = 260,
    infoTitle = "ИНФО ПЕРСОНАЖА",
    leftMargin = 16,
    bottomMargin = 14,
    panelWidth = 420,
    panelHeight = 118,
    barHeight = 16,
    topPanelWidth = 700,
    topPanelHeight = 34,
    animationSpeed = 8
}

NEXUS_PLUS_CONFIG.EscMenu = {
    enabled = true,
    width = 560,
    headerHeight = 78,
    itemHeight = 46,
    openAnimSpeed = 12,
    buttons = {
        { label = "Продолжить", action = "resume" },
        { label = "F4 Меню", action = "f4" },
        { label = "Меню двери", action = "door" },
        { label = "Настройки", action = "open_options" },
        { label = "Отключиться", action = "disconnect" }
    }
}

NEXUS_PLUS_CONFIG.ChatBox = {
    enabled = false,
    width = 640,
    height = 300,
    x = 22,
    yFromBottom = 170,
    inputHeight = 34,
    openAnimSpeed = 14,
    maxMessages = 140,
    fadeDelay = 300,
    fadeDuration = 4,
    showTimestamps = true,
    rounded = 10,
    channels = {
        { id = "all", label = "Все" },
        { id = "ic", label = "IC" },
        { id = "ooc", label = "OOC" },
        { id = "team", label = "TEAM" },
        { id = "system", label = "SYSTEM" }
    },
    commandSuggestions = {
        "/ooc",
        "//",
        "/ad",
        "/w",
        "/pm",
        "/dropmoney",
        "/radio",
        "/me",
        "/roll",
        "/lock",
        "/unlock"
    }
}