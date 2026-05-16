if SERVER then return end

local function cfgValue(key, fallback)
    local cfg = NEXUS_PLUS_CONFIG and NEXUS_PLUS_CONFIG.HUD
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

local function generalValue(key, fallback)
    local cfg = NEXUS_PLUS_CONFIG and NEXUS_PLUS_CONFIG.General
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

local function themeValue(key, fallback)
    local cfg = NEXUS_PLUS_CONFIG and NEXUS_PLUS_CONFIG.Theme
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

surface.CreateFont("NexusHudBrand", {
    font = "Roboto",
    size = 26,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusHudText", {
    font = "Roboto",
    size = 18,
    weight = 600,
    antialias = true
})

surface.CreateFont("NexusHudSmall", {
    font = "Roboto",
    size = 15,
    weight = 500,
    antialias = true
})

surface.CreateFont("NexusHudChip", {
    font = "Roboto",
    size = 14,
    weight = 700,
    antialias = true
})

local smooth = {
    hp = 0,
    armor = 0,
    hunger = 0
}

local function formatMoney(value)
    local number = tonumber(value) or 0
    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(number)
    end

    return tostring(number)
end

local function formatSeconds(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    local m = math.floor(total / 60)
    local s = total % 60
    return string.format("%02d:%02d", m, s)
end

local function getArrestTimeLeft(ply)
    if not ply.getDarkRPVar then return nil end

    local arrested = ply:getDarkRPVar("Arrested")
    if not arrested then return nil end

    local value = ply:getDarkRPVar("ArrestedTime")
    if not isnumber(value) then
        return 0
    end

    if value > CurTime() then
        return math.max(0, value - CurTime())
    end

    return math.max(0, value)
end

local function isLockdownActive()
    return GetGlobalBool("DarkRP_LockDown", false)
        or GetGlobalBool("DarkRP_Lockdown", false)
        or GetGlobalBool("DarkRP_LockDownStarted", false)
end

local function getAgendaText(ply)
    if not cfgValue("showAgenda", true) then return nil end

    if ply.getAgendaTable then
        local agenda = ply:getAgendaTable()
        if istable(agenda) and agenda.Text and agenda.Text ~= "" then
            return agenda.Title or "Повестка", agenda.Text
        end
    end

    if ply.getDarkRPVar then
        local text = ply:getDarkRPVar("agenda")
        if isstring(text) and text ~= "" then
            return "Повестка", text
        end
    end

    return nil
end

local function drawBar(x, y, w, h, value, maxValue, fillColor, label)
    local ratio = 0
    if maxValue > 0 then
        ratio = math.Clamp(value / maxValue, 0, 1)
    end

    draw.RoundedBox(8, x, y, w, h, Color(22, 25, 37, 225))
    draw.RoundedBox(8, x, y, math.max(8, w * ratio), h, fillColor)
    draw.SimpleText(label, "NexusHudSmall", x + 8, y + h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(math.floor(value) .. "%", "NexusHudSmall", x + w - 8, y + h * 0.5, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

local function drawTopStatuses(ply)
    if not cfgValue("showTopStatus", true) then return end

    local statuses = {}

    if isLockdownActive() then
        statuses[#statuses + 1] = { text = "КОМЕНДАНТСКИЙ ЧАС", color = Color(191, 74, 74, 240) }
    end

    if GetGlobalBool("DarkRP_LotteryActive", false) then
        statuses[#statuses + 1] = { text = "ЛОТЕРЕЯ АКТИВНА", color = Color(119, 92, 196, 240) }
    end

    local arrestedLeft = getArrestTimeLeft(ply)
    if arrestedLeft ~= nil then
        statuses[#statuses + 1] = { text = "АРЕСТ: " .. formatSeconds(arrestedLeft), color = Color(221, 126, 60, 240) }
    end

    local wanted = ply.getDarkRPVar and ply:getDarkRPVar("wanted")
    if wanted then
        local wantedText = "РОЗЫСК"
        local wantedTime = ply:getDarkRPVar("wantedTime")
        if isnumber(wantedTime) then
            local left = wantedTime > CurTime() and math.max(0, math.ceil(wantedTime - CurTime())) or math.max(0, math.ceil(wantedTime))
            wantedText = "РОЗЫСК: " .. tostring(left)
        else
            local reason = tostring(ply:getDarkRPVar("wantedReason") or "")
            if reason ~= "" then
                if #reason > 26 then
                    reason = string.sub(reason, 1, 26) .. "..."
                end
                wantedText = "РОЗЫСК: " .. reason
            end
        end
        statuses[#statuses + 1] = { text = wantedText, color = Color(192, 65, 65, 240) }
    end

    local hasLicense = ply.getDarkRPVar and ply:getDarkRPVar("HasGunlicense")
    if hasLicense then
        statuses[#statuses + 1] = { text = "ЛИЦЕНЗИЯ НА ОРУЖИЕ", color = Color(66, 152, 97, 240) }
    end

    if #statuses == 0 then return end

    local centerX = ScrW() * 0.5
    local y = 12
    local panelW = cfgValue("topPanelWidth", 700)
    local panelH = cfgValue("topPanelHeight", 34)
    local x = centerX - panelW * 0.5

    draw.RoundedBox(10, x, y, panelW, panelH, Color(16, 18, 26, 222))

    local chipX = x + 10
    for _, status in ipairs(statuses) do
        surface.SetFont("NexusHudChip")
        local tw = surface.GetTextSize(status.text)
        local chipW = tw + 22
        if chipX + chipW > x + panelW - 10 then
            break
        end

        draw.RoundedBox(7, chipX, y + 6, chipW, panelH - 12, status.color)
        draw.SimpleText(status.text, "NexusHudChip", chipX + chipW * 0.5, y + panelH * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        chipX = chipX + chipW + 8
    end
end

local function drawAmmoPanel(ply)
    if not cfgValue("showAmmo", true) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return end

    local clip1 = wep:Clip1()
    local ammoType = wep:GetPrimaryAmmoType()
    local reserve = ammoType >= 0 and ply:GetAmmoCount(ammoType) or 0

    if clip1 < 0 and reserve <= 0 then return end

    local w, h = 240, 72
    local x = ScrW() - w - 16
    local y = ScrH() - h - cfgValue("bottomMargin", 14)

    draw.RoundedBox(10, x, y, w, h, Color(16, 18, 26, 226))

    local name = wep:GetPrintName()
    if not isstring(name) or name == "" or name == "#HL2_Weapon_Unknown" then
        name = wep:GetClass()
    end

    draw.SimpleText(name, "NexusHudSmall", x + 12, y + 18, themeValue("mutedText", Color(165, 172, 196)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText((clip1 >= 0 and clip1 or 0) .. " / " .. reserve, "NexusHudBrand", x + w - 12, y + 42, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

local function draw3D2DInfo(pos, ang, title, sub)
    local scale = cfgValue("info3D2DScale", 0.14)

    cam.Start3D2D(pos, ang, scale)
        surface.SetFont("NexusHudText")
        local titleW = surface.GetTextSize(title)
        surface.SetFont("NexusHudSmall")
        local subW = surface.GetTextSize(sub)
        local boxW = math.max(180, titleW + 28, subW + 28)
        local boxH = 56
        local x = -boxW * 0.5

        draw.RoundedBox(8, x, 0, boxW, boxH, Color(16, 18, 26, 220))
        draw.SimpleText(title, "NexusHudText", 0, 18, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(sub, "NexusHudSmall", 0, 40, themeValue("mutedText", Color(165, 172, 196)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

local function drawWorldTargetInfo3D2D()
    if not cfgValue("show3D2DTargetInfo", true) then return end

    local ply = LocalPlayer()
    local tr = ply:GetEyeTrace()
    if not tr or not IsValid(tr.Entity) then return end

    local maxDist = cfgValue("targetInfoDistance", 260)
    if tr.HitPos:Distance(ply:EyePos()) > maxDist then return end

    local ent = tr.Entity

    if ent:IsPlayer() and cfgValue("show3D2DPlayerInfo", true) then
        local pos = ent:EyePos() + Vector(0, 0, 14)
        local eyeAng = EyeAngles()
        local faceAng = Angle(0, eyeAng.y - 90, 90)
        draw3D2DInfo(pos, faceAng, ent:Nick(), team.GetName(ent:Team()))
        return
    end

    if not cfgValue("show3D2DDoorInfo", true) then return end

    local class = ent:GetClass()
    if class ~= "prop_door_rotating" and class ~= "func_door" and class ~= "func_door_rotating" then return end

    local title = "Дверь"
    local doorData = ent.getDoorData and ent:getDoorData() or nil
    if istable(doorData) and doorData.title and doorData.title ~= "" then
        title = doorData.title
    end

    local owners = {}
    if ent.isKeysOwnedBy then
        for _, p in ipairs(player.GetAll()) do
            if ent:isKeysOwnedBy(p) then
                owners[#owners + 1] = p:Nick()
            end
        end
    end

    local sub = #owners > 0 and table.concat(owners, ", ") or "Без владельца"
    if #sub > 30 then
        sub = string.sub(sub, 1, 30) .. "..."
    end

    -- Static double-sided door labels: one panel on each side of the door.
    local center = ent:LocalToWorld(ent:OBBCenter() + Vector(0, 0, 22))
    local forward = ent:GetForward()
    local offset = cfgValue("doorInfoOffset", 2)

    local posFront = center + (forward * offset)
    local posBack = center - (forward * offset)

    local baseY = ent:GetAngles().y
    local angFront = Angle(0, baseY + 90, 90)
    local angBack = Angle(0, baseY - 90, 90)

    draw3D2DInfo(posFront, angFront, title, sub)
    draw3D2DInfo(posBack, angBack, title, sub)
end

local function drawAgenda(ply)
    local title, text = getAgendaText(ply)
    if not title or not text then return end

    local w, h = 430, 88
    local x = ScrW() - w - 16
    local y = 56

    draw.RoundedBox(10, x, y, w, h, Color(16, 18, 26, 222))
    draw.SimpleText(title, "NexusHudText", x + 12, y + 18, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local short = tostring(text)
    short = string.gsub(short, "\n", " ")
    if #short > 90 then
        short = string.sub(short, 1, 90) .. "..."
    end
    draw.SimpleText(short, "NexusHudSmall", x + 12, y + 48, themeValue("mutedText", Color(165, 172, 196)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function drawMainHud()
    if not cfgValue("enabled", true) then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not ply:Alive() then return end

    local speed = cfgValue("animationSpeed", 8)
    smooth.hp = Lerp(FrameTime() * speed, smooth.hp, math.Clamp(ply:Health(), 0, 100))
    smooth.armor = Lerp(FrameTime() * speed, smooth.armor, math.Clamp(ply:Armor(), 0, 100))

    local hunger = 100
    if ply.getDarkRPVar then
        hunger = tonumber(ply:getDarkRPVar("Energy") or 100) or 100
    end
    smooth.hunger = Lerp(FrameTime() * speed, smooth.hunger, math.Clamp(hunger, 0, 100))

    local x = cfgValue("leftMargin", 16)
    local y = ScrH() - cfgValue("panelHeight", 118) - cfgValue("bottomMargin", 14)
    local w = cfgValue("panelWidth", 420)
    local h = cfgValue("panelHeight", 118)

    draw.RoundedBox(12, x, y, w, h, Color(16, 18, 26, 228))
    draw.SimpleText(cfgValue("infoTitle", "ИНФО ПЕРСОНАЖА"), "NexusHudBrand", x + 12, y + 20, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    local rpname = ply.getDarkRPVar and ply:getDarkRPVar("rpname") or ply:Nick()
    local job = team.GetName(ply:Team())
    local salary = ply.getDarkRPVar and (ply:getDarkRPVar("salary") or 0) or 0
    local money = ply.getDarkRPVar and (ply:getDarkRPVar("money") or 0) or 0

    draw.SimpleText(rpname .. " | " .. job, "NexusHudSmall", x + 12, y + 42, themeValue("mutedText", Color(165, 172, 196)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(formatMoney(money), "NexusHudText", x + w - 12, y + 20, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    draw.SimpleText("Зарплата: " .. formatMoney(salary), "NexusHudSmall", x + w - 12, y + 42, themeValue("mutedText", Color(165, 172, 196)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    local barY = y + 56
    local barW = w - 24
    local barH = cfgValue("barHeight", 16)
    drawBar(x + 12, barY, barW, barH, smooth.hp, 100, Color(189, 76, 76, 240), "Здоровье")
    drawBar(x + 12, barY + 20, barW, barH, smooth.armor, 100, Color(79, 127, 214, 240), "Броня")
    drawBar(x + 12, barY + 40, barW, barH, smooth.hunger, 100, Color(97, 172, 98, 240), "Сытость")

    drawTopStatuses(ply)
    drawAmmoPanel(ply)
    drawAgenda(ply)
end

hook.Add("HUDPaint", "NexusPlusHUDPaint", function()
    drawMainHud()
end)

hook.Add("PostDrawTranslucentRenderables", "NexusPlusHUDWorldTargetInfo", function(depth, skybox)
    if skybox then return end
    if not cfgValue("enabled", true) then return end
    drawWorldTargetInfo3D2D()
end)

hook.Add("HUDShouldDraw", "NexusPlusHideDefaultHUD", function(name)
    if not cfgValue("hideDefaultHud", true) then return end

    local blacklist = {
        CHudHealth = true,
        CHudBattery = true,
        CHudAmmo = true,
        CHudSecondaryAmmo = true,
        CHudCrosshair = false
    }

    if blacklist[name] ~= nil then
        return not blacklist[name]
    end
end)

hook.Add("HUDDrawTargetID", "NexusPlusHideTargetID", function()
    if cfgValue("hideDefaultHud", true) then
        return false
    end
end)

hook.Add("HUDDrawDoorData", "NexusPlusHideDoorData", function()
    if cfgValue("hideDefaultHud", true) then
        return false
    end
end)