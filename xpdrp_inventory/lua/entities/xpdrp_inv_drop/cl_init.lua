include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local ang = LocalPlayer():EyeAngles()
    local pos = self:GetPos() + Vector(0, 0, 12)
    local amount = self:GetAmount()

    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    cam.Start3D2D(pos, Angle(0, ang.y, 90), 0.06)
        draw.SimpleText("x" .. tostring(amount), "DermaLarge", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end