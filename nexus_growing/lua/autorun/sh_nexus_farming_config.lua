NEXUS_FARM_CFG = NEXUS_FARM_CFG or {}

NEXUS_FARM_CFG.PotModel = "models/props_junk/terracotta01.mdl"
NEXUS_FARM_CFG.PlantModel = "models/props/cs_shacks/weeds001.mdl"

NEXUS_FARM_CFG.UseDistance = 150
NEXUS_FARM_CFG.StageCooldown = 60

-- Этап 1: облегченный, с гарантированным прохождением по стабильности
NEXUS_FARM_CFG.Stage1 = {
    duration = 6.5,
    speed = 2.5,
    zoneMin = 0.36,
    zoneMax = 0.64,
    stabilityGood = 18,
    stabilityBad = 11,
    needStability = 45,
    needClicks = 0
}

NEXUS_FARM_CFG.Stage2 = {
    timeLimit = 4.5,
    pointsToHit = 4
}

NEXUS_FARM_CFG.Stage3 = {
    timeLimit = 5.5,
    sequenceLen = 3,
    keys = { "W", "A", "S", "D", "SPACE" }
}

NEXUS_FARM_CFG.Items = {
    seed = "parsley_seed",
    soil = "parsley_soil",
    water = "parsley_water",
    reward = "parsley_dried_pack"
}