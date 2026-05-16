include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if self:GetPos():Distance(lp:GetPos()) > 220 then return end

    local ang = EyeAngles()
    local pos = self:GetPos() + Vector(0, 0, 52)
    ang = Angle(0, ang.y - 90, 90)

    cam.Start3D2D(pos, ang, 0.08)
        draw.RoundedBox(6, -150, -20, 300, 40, Color(16, 18, 26, 230))
        draw.SimpleText(self:GetBinName() ~= "" and self:GetBinName() or "Мусорка", "DermaDefaultBold", 0, -2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Нажмите E", "DermaDefault", 0, 12, Color(165, 180, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end