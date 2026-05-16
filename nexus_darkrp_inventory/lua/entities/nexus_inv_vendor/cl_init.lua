include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if self:GetPos():Distance(lp:GetPos()) > 200 then return end

    local ang = EyeAngles()
    local pos = self:GetPos() + Vector(0, 0, 86)

    ang = Angle(0, ang.y - 90, 90)
    cam.Start3D2D(pos, ang, 0.08)
        draw.RoundedBox(6, -120, -22, 240, 44, Color(16, 18, 26, 230))
        draw.SimpleText(self:GetVendorName(), "DermaLarge", 0, -4, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Нажмите E для торговли", "DermaDefaultBold", 0, 13, Color(165, 180, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end