if not CLIENT then return end

XPDRP = XPDRP or {}

local col = {
    bg = Color(8, 12, 20, 210),
    panel = Color(12, 17, 27, 235),
    border = Color(255, 255, 255, 14),
    accent = Color(82, 162, 255, 170),
    good = Color(112, 214, 136, 180),
    warn = Color(255, 186, 98, 180),
    bad = Color(235, 120, 120, 180),
    text = Color(236, 242, 252),
    dim = Color(168, 184, 206)
}

surface.CreateFont("XPDRP_HUD_Title", {
    font = "Tahoma",
    size = 24,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("XPDRP_HUD_Main", {
    font = "Tahoma",
    size = 19,
    weight = 800,
    antialias = true,
    extended = true
})

surface.CreateFont("XPDRP_HUD_Sub", {
    font = "Tahoma",
    size = 16,
    weight = 600,
    antialias = true,
    extended = true
})

local hidden = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    DarkRP_HUD = true,
    DarkRP_EntityDisplay = true,
    DarkRP_LocalPlayerHUD = true,
    DarkRP_ArrestedHUD = true,
    DarkRP_Agenda = true,
    DarkRP_LockdownHUD = true,
    DarkRP_EntityDisplay = true,
    DarkRP_Hungermod = true
}

local smooth = {
    hp = 100,
    ar = 0,
    hunger = 100,
    voice = 0
}

local cache = {
    money = "$0",
    salary = "$0",
    job = "Гражданин",
    name = "",
    wanted = false,
    arrested = false,
    lockdown = false,
    agenda = "",
    players = 0,
    maxPlayers = game.MaxPlayers()
}

local nextDataUpdate = 0

local function roundedRect(x, y, w, h, c)
    draw.RoundedBox(0, x, y, w, h, c)
end

local function drawBar(x, y, w, h, label, value, max, barColor)
    local frac = 0
    if max > 0 then
        frac = math.Clamp(value / max, 0, 1)
    end

    roundedRect(x, y, w, h, Color(255, 255, 255, 6))
    roundedRect(x, y, math.max(2, w * frac), h, barColor)
    surface.SetDrawColor(col.border)
    surface.DrawOutlinedRect(x, y, w, h, 1)

    draw.SimpleText(label, "XPDRP_HUD_Sub", x + 8, y + h * 0.5, col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(math.floor(value) .. "%", "XPDRP_HUD_Sub", x + w - 8, y + h * 0.5, col.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

local function drawPanel(x, y, w, h)
    roundedRect(x, y, w, h, col.panel)
    roundedRect(x, y, w, 3, col.accent)
    surface.SetDrawColor(col.border)
    surface.DrawOutlinedRect(x, y, w, h, 1)
end

local function updateCache(ply)
    if CurTime() < nextDataUpdate then return end
    nextDataUpdate = CurTime() + 0.2

    cache.players = #player.GetAll()
    cache.name = ply:Nick()

    if ply.getDarkRPVar then
        cache.money = XPDRP.FormatMoney(ply:getDarkRPVar("money") or 0)
        cache.salary = XPDRP.FormatMoney(ply:getDarkRPVar("salary") or 0)
        cache.job = ply:getDarkRPVar("job") or team.GetName(ply:Team()) or "Неизвестно"
        cache.wanted = ply:getDarkRPVar("wanted") and true or false
        cache.arrested = ply:getDarkRPVar("Arrested") and true or false
        cache.agenda = ply:getDarkRPVar("agenda") or ""
    else
        cache.job = team.GetName(ply:Team()) or "Неизвестно"
    end

    cache.lockdown = GetGlobalBool("DarkRP_LockDown", false)
end

local function drawAlerts(sw)
    local lines = {}
    if cache.wanted then lines[#lines + 1] = { "Вы в розыске", col.bad } end
    if cache.arrested then lines[#lines + 1] = { "Вы арестованы", col.warn } end
    if cache.lockdown then lines[#lines + 1] = { "В городе локдаун", col.accent } end

    if #lines == 0 then return end

    local boxW = 360
    local boxH = 32 + (#lines * 24)
    local x = sw * 0.5 - boxW * 0.5
    local y = 22

    drawPanel(x, y, boxW, boxH)
    draw.SimpleText("СИСТЕМНЫЕ СТАТУСЫ", "XPDRP_HUD_Sub", x + 10, y + 8, col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    for i = 1, #lines do
        local line = lines[i]
        draw.SimpleText(line[1], "XPDRP_HUD_Main", x + 10, y + 10 + i * 22, line[2], TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

local function drawWeaponPanel(ply, sw, sh)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end

    local clip = wep:Clip1()
    local reserve = ply:GetAmmoCount(wep:GetPrimaryAmmoType())
    if clip < 0 and reserve <= 0 then return end

    local w, h = 290, 88
    local x, y = sw - w - 26, sh - h - 22
    drawPanel(x, y, w, h)

    local wepName = wep:GetPrintName() ~= "" and wep:GetPrintName() or wep:GetClass()
    draw.SimpleText(wepName, "XPDRP_HUD_Main", x + 12, y + 12, col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    draw.SimpleText("Патроны", "XPDRP_HUD_Sub", x + 12, y + 42, col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText((clip < 0 and "-" or tostring(clip)) .. " / " .. tostring(reserve), "XPDRP_HUD_Title", x + w - 12, y + 40, col.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

hook.Add("HUDShouldDraw", "XPDRP.CustomHUD.HideDefault", function(name)
    if hidden[name] then return false end
end)

hook.Add("HUDPaint", "XPDRP.CustomHUD.Paint", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local sw, sh = ScrW(), ScrH()
    updateCache(ply)

    smooth.hp = Lerp(FrameTime() * 8, smooth.hp, math.max(0, ply:Health()))
    smooth.ar = Lerp(FrameTime() * 8, smooth.ar, math.max(0, ply:Armor()))

    local hungerValue = 100
    if ply.getDarkRPVar then
        hungerValue = ply:getDarkRPVar("Energy") or ply:getDarkRPVar("energy") or 100
    end
    smooth.hunger = Lerp(FrameTime() * 8, smooth.hunger, math.max(0, hungerValue))
    smooth.voice = Lerp(FrameTime() * 10, smooth.voice, ply:IsSpeaking() and 1 or 0)

    local x, y = 24, sh - 192
    local w, h = 430, 168
    drawPanel(x, y, w, h)

    draw.SimpleText(cache.name, "XPDRP_HUD_Title", x + 12, y + 10, col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(cache.job, "XPDRP_HUD_Sub", x + 14, y + 38, col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    draw.SimpleText(cache.money, "XPDRP_HUD_Title", x + w - 12, y + 12, col.good, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    draw.SimpleText("Зарплата: " .. cache.salary, "XPDRP_HUD_Sub", x + w - 12, y + 40, col.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    drawBar(x + 12, y + 72, w - 24, 24, "Здоровье", smooth.hp, 100, col.bad)
    drawBar(x + 12, y + 100, w - 24, 24, "Броня", smooth.ar, 100, col.accent)
    drawBar(x + 12, y + 128, w - 24, 24, "Голод", smooth.hunger, 100, col.warn)

    if smooth.voice > 0.03 then
        local vx, vy, vw, vh = x + w + 14, y + h - 46, 120, 30
        roundedRect(vx, vy, vw, vh, Color(col.accent.r, col.accent.g, col.accent.b, 70 + 90 * smooth.voice))
        surface.SetDrawColor(col.border)
        surface.DrawOutlinedRect(vx, vy, vw, vh, 1)
        draw.SimpleText("Голос", "XPDRP_HUD_Sub", vx + vw * 0.5, vy + vh * 0.5, col.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local topW, topH = 300, 60
    local tx, ty = sw - topW - 24, 24
    drawPanel(tx, ty, topW, topH)
    draw.SimpleText("Онлайн: " .. cache.players .. "/" .. cache.maxPlayers, "XPDRP_HUD_Main", tx + 12, ty + 11, col.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(os.date("%d.%m.%Y  %H:%M:%S"), "XPDRP_HUD_Sub", tx + 12, ty + 35, col.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    drawWeaponPanel(ply, sw, sh)
    drawAlerts(sw)
end)
