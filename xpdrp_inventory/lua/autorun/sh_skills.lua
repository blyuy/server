XPDRP = XPDRP or {}
XPDRP.Skills = XPDRP.Skills or {}

XPDRP.Skills.Config = {
    SecondsPerPoint = 36000,
    MaxLevel = 5,
    Definitions = {
        marathoner = {
            id = "marathoner",
            name = "Марафонец",
            maxLevel = 5,
            unlockTeam = "TEAM_FLASH",
            levels = {
                "+15% к скорости бега",
                "+15% к скорости бега",
                "+20% к скорости бега",
                "+40% к скорости бега",
                "Открывает профессию Флэш"
            }
        },
        sadist = {
            id = "sadist",
            name = "Садист",
            maxLevel = 5,
            unlockTeam = "TEAM_AGENT",
            levels = {
                "+5% к урону от оружия",
                "+5% к урону от оружия",
                "+5% к урону от оружия",
                "За убийство +20 к HP до смерти",
                "Открывает профессию Агент 47"
            }
        },
        parkourist = {
            id = "parkourist",
            name = "Паркурист",
            maxLevel = 5,
            levels = {
                "+10% к высоте прыжка",
                "+10% к высоте прыжка",
                "Открывает двойной прыжок",
                "+10% к высоте прыжка",
                "Открывает тройной прыжок"
            }
        }
    }
}