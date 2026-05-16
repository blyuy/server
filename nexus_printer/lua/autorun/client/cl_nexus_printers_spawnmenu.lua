if SERVER then return end

-- Явно добавляем энтити в вкладку Q-menu -> Entities
list.Set("SpawnableEntities", "sent_printer_tier1", {
    PrintName = "Кустарный принтер",
    ClassName = "sent_printer_tier1",
    Category = "Nexus Printers",
    AdminOnly = false
})

list.Set("SpawnableEntities", "sent_printer_tier2", {
    PrintName = "Продвинутый принтер",
    ClassName = "sent_printer_tier2",
    Category = "Nexus Printers",
    AdminOnly = false
})

list.Set("SpawnableEntities", "sent_printer_tier3", {
    PrintName = "Профессиональный принтер",
    ClassName = "sent_printer_tier3",
    Category = "Nexus Printers",
    AdminOnly = false
})

list.Set("SpawnableEntities", "sent_cooler", {
    PrintName = "Охлаждающий спрей",
    ClassName = "sent_cooler",
    Category = "Nexus Printers",
    AdminOnly = false
})

list.Set("SpawnableEntities", "sent_ink", {
    PrintName = "Картридж с чернилами",
    ClassName = "sent_ink",
    Category = "Nexus Printers",
    AdminOnly = false
})