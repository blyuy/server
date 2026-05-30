include("shared.lua")

XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

local worldCfg = (XPDRP.Config and XPDRP.Config.World3D2D) or {}

local cfg = {
    Distance = worldCfg.PlayerDistance or 520,
    Scale = worldCfg.PlayerScale or worldCfg.Scale or 0.045
}

surface.CreateFont("XPDRP_TRADER_3D2D_Title", {
    font = "Trebuchet MS",
    size = 32,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("XPDRP_TRADER_3D2D_Sub", {
    font = "Trebuchet MS",
    size = 22,
    weight = 700,
    antialias = true,
    extended = true
})

local cBg = Color(10, 14, 22, 236)
local cBorder = Color(255, 255, 255, 28)
local cAccent = Color(82, 162, 255, 160)
local cText = Color(238, 244, 255)
local cDim = Color(174, 191, 214)

local function isLookedAt(eyePos, eyeForward, targetPos, maxDist, dotLimit)
    local to = targetPos - eyePos
    if to:LengthSqr() > (maxDist * maxDist) then return false end
    to:Normalize()
    return eyeForward:Dot(to) >= dotLimit
end

local function hasLineOfSight(viewer, targetEnt, startPos, endPos)
    local tr = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = { viewer, targetEnt },
        mask = MASK_VISIBLE_AND_NPCS
    })
    return not tr.Hit
end

local function getTraderTitle(ent)
    local netName = ent:GetTraderName()
    if isstring(netName) and netName ~= "" then
        return netName
    end

    local id = ent:GetTraderId()
    local trader = XPDRP.Inv and XPDRP.Inv.Traders and XPDRP.Inv.Traders[id]
    if trader and trader.name and trader.name ~= "" then
        return trader.name
    end
    if id ~= "" then
        return "Торговец: " .. tostring(id)
    end
    return "Торговец"
end

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local eyePos = lp:EyePos()
    local headPos = self:GetPos() + Vector(0, 0, 74)
    local eyeForward = EyeAngles():Forward()

    if not isLookedAt(eyePos, eyeForward, headPos, cfg.Distance, 0.4) then return end
    if not hasLineOfSight(lp, self, eyePos, headPos) then return end

    local pos = self:GetPos() + Vector(0, 0, 86)
    local ang = (eyePos - pos):Angle()
    ang = Angle(0, ang.y - 90, 90)

    local w, h = 520, 114
    local title = getTraderTitle(self)
    local subtitle = "Нажми E для торговли"

    cam.Start3D2D(pos, ang, cfg.Scale)
        surface.SetAlphaMultiplier(1)
        draw.RoundedBox(0, -w * 0.5, -h * 0.5, w, h, cBg)
        draw.RoundedBox(0, -w * 0.5, -h * 0.5, w, 4, cAccent)
        surface.SetDrawColor(cBorder)
        surface.DrawOutlinedRect(-w * 0.5, -h * 0.5, w, h, 1)

        draw.SimpleTextOutlined(tostring(title), "XPDRP_TRADER_3D2D_Title", 0, -16, cText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 235))
        draw.SimpleTextOutlined(tostring(subtitle), "XPDRP_TRADER_3D2D_Sub", 0, 18, cDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 235))
    cam.End3D2D()
end