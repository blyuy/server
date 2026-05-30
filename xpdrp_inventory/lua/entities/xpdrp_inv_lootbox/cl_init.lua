include("shared.lua")

surface.CreateFont("XPDRP_Loot_Title", {
    font = "Trebuchet MS",
    size = 30,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("XPDRP_Loot_Sub", {
    font = "Trebuchet MS",
    size = 20,
    weight = 700,
    antialias = true,
    extended = true
})

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:GetPos():DistToSqr(self:GetPos()) > (300 * 300) then return end

    local pos = self:GetPos() + Vector(0, 0, 24)
    local ang = (lp:EyePos() - pos):Angle()
    ang = Angle(0, ang.y - 90, 90)

    local w, h = 360, 92
    local ready = self:GetLootReady()
    local status = ready and "Готов к открытию" or ("Обновление через " .. tostring(math.max(0, math.ceil(self:GetNextRefreshAt() - CurTime()))) .. "с")
    local accent = ready and Color(112, 214, 136, 180) or Color(82, 162, 255, 160)

    cam.Start3D2D(pos, ang, 0.045)
        draw.RoundedBox(0, -w * 0.5, -h * 0.5, w, h, Color(10, 14, 22, 230))
        draw.RoundedBox(0, -w * 0.5, -h * 0.5, w, 4, accent)
        surface.SetDrawColor(255, 255, 255, 22)
        surface.DrawOutlinedRect(-w * 0.5, -h * 0.5, w, h, 1)

        draw.SimpleTextOutlined(self:GetBoxName() ~= "" and self:GetBoxName() or "Лутбокс", "XPDRP_Loot_Title", 0, -13, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
        draw.SimpleTextOutlined(status, "XPDRP_Loot_Sub", 0, 18, Color(174, 191, 214), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 220))
    cam.End3D2D()
end