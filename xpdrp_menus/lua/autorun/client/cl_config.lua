if not CLIENT then return end

XPDRP = XPDRP or {}
XPDRP.Config = XPDRP.Config or {}

XPDRP.Config.F4BindHint = "F4"
XPDRP.Config.TabRefreshInterval = 1
XPDRP.Config.DefaultFrameW = 0.72
XPDRP.Config.DefaultFrameH = 0.8

XPDRP.Config.World3D2D = {
    Enabled = true,
    DoorDistance = 650,
    PlayerDistance = 520,
    RefreshRate = 0.35,
    Scale = 0.05,
    DoorScale = 0.05,
    PlayerScale = 0.045
}

XPDRP.Config.Colors = {
    Accent = Color(109, 191, 255),
    AccentSoft = Color(109, 191, 255, 45),
    BgA = Color(11, 14, 24, 238),
    BgB = Color(21, 28, 44, 235),
    Line = Color(255, 255, 255, 24),
    Good = Color(106, 228, 152),
    Warn = Color(255, 189, 96)
}
