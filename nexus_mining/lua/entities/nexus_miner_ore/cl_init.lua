include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local dist = self:GetPos():DistToSqr(lp:GetPos())
    if dist > (220 * 220) then return end

    local ang = EyeAngles()
    local pos = self:GetPos() + Vector(0, 0, 36)
    ang = Angle(0, ang.y - 90, 90)

    local depleted = self:GetDepleted()
    local remain = math.max(0, math.ceil(self:GetRegenAt() - CurTime()))

    cam.Start3D2D(pos, ang, 0.08)
        draw.RoundedBox(6, -130, -20, 260, 40, Color(16, 18, 26, 230))
        if depleted then
            draw.SimpleText("Жила истощена", "DermaDefaultBold", 0, -2, Color(235