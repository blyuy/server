include("shared.lua")

local TIER_META = {
    [1] = {
        name = "Кустарный принтер",
        accent = Color(240, 140, 85),
        barName = "Температура",
        mode = "heat"
    },
    [2] = {
        name = "Продвинутый принтер",
        accent = Color(95, 170, 255),
        barName = "Чернила",
        mode = "ink"
    },
    [3] = {
        name = "Профессиональный принтер",
        accent = Color(140, 240, 190),
        barName = "Статус",
        mode = "jam"
    }
}

local function moneyText(v)
    return "$" .. tostring(math.floor(v or 0))
end

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if self:GetPos():DistToSqr(lp:GetPos()) > (260 * 260) then return end

    local tier = self:GetTier()
    local meta = TIER_META[tier] or TIER_META[1]
    local stored = self:GetStoredMoney()

    local ang = self:GetAngles()
    local pos = self:GetPos() + self:GetUp() * 6 + self:GetForward() * 8
    ang:RotateAroundAxis(ang:Up(), 90)

    cam.Start3D2D(pos, ang, 0.06)
        draw.RoundedBox(10, -170, -120, 340, 190, Color(8, 14, 28, 240))
        draw.RoundedBox(10, -170, -120, 340, 26, Color(meta.accent.r, meta.accent.g, meta.accent.b, 220))

        draw.SimpleText(meta.name, "DermaDefaultBold", 0, -107, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Баланс: " .. moneyText(stored), "DermaLarge", 0, -70, Color(235, 242, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local barValue = 0
        local barLabel = ""
        local barColor = meta.accent

        if meta.mode == "heat" then
            barValue = math.Clamp(self:GetHeat(), 0, 100)
            barLabel = "Температура: " .. math.floor(barValue) .. "%"
            if barValue > 70 then
                barColor = Color(250, 90, 90)
            end
        elseif meta.mode == "ink" then
            barValue = math.Clamp(self:GetInk(), 0, 100)
            barLabel = "Чернила: " .. math.floor(barValue) .. "%"
            if barValue <= 20 then
                barColor = Color(240, 130, 90)
            end
        else
            if self:GetJammed() then
                barValue = 100
                barLabel = "ОШИБКА: ЗАСТРЯЛА БУМАГА"
                barColor = Color(250, 90, 90)
            else
                barValue = 100
                barLabel = "Статус: Работает"
                barColor = Color(120, 220, 150)
            end
        end

        draw.RoundedBox(6, -140, -35, 280, 18, Color(22, 30, 48, 230))
        draw.RoundedBox(6, -140, -35, 2.8 * barValue, 18, barColor)
        draw.SimpleText(barLabel, "DermaDefaultBold", 0, -44, Color(205, 220, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

        draw.RoundedBox(8, -125, 10, 250, 30, Color(70, 120, 210, 230))
        draw.SimpleText("СНЯТЬ ДЕНЬГИ [E]", "DermaDefaultBold", 0, 25, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if tier == 3 and self:GetJammed() then
            draw.RoundedBox(8, -125, 46, 250, 18, Color(230, 80, 80, 230))
            draw.SimpleText("ПОЧИНИТЬ [E]", "DermaDefaultBold", 0, 55, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end