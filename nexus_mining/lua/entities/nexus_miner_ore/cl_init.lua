include("shared.lua")

local function formatTimeLeft(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d", m, s)
end

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local distSqr = self:GetPos():DistToSqr(lp:GetPos())
    if distSqr > (220 * 220) then return end

    local ang = EyeAngles()
    local pos = self:GetPos() + Vector(0, 0, 36)
    ang = Angle(0, ang.y - 90, 90)

    local depleted = self:GetDepleted()
    local remain = math.max(0, math.ceil((self:GetRegenAt() or 0) - CurTime()))

    cam.Start3D2D(pos, ang, 0.08)
        draw.RoundedBox(6, -130, -20, 260, 40, Color(16, 18, 26, 230))

        if depleted then
            draw.SimpleText("Жила истощена", "DermaDefaultBold", 0, -2, Color(235, 126, 126), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("До восстановления: " .. formatTimeLeft(remain), "DermaDefault", 0, 13, Color(210, 216, 232), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("Рудная жила", "DermaDefaultBold", 0, -2, Color(160, 232, 172), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Нажмите E для добычи", "DermaDefault", 0, 13, Color(210, 216, 232), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end