if SERVER then return end

local minerState = {
    active = false,
    expected = "",
    duration = 1.0,
    roundStart = 0,
    step = 1,
    total = 3,
    canSend = false
}

local keyToChar = {
    [KEY_W] = "W",
    [KEY_A] = "A",
    [KEY_S] = "S",
    [KEY_D] = "D"
}

surface.CreateFont("NexusMinerTitle", {
    font = "Roboto",
    size = 36,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusMinerKey", {
    font = "Roboto",
    size = 64,
    weight = 900,
    antialias = true
})

surface.CreateFont("NexusMinerText", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true
})

local function sendInput(char)
    if not minerState.active then return end
    if not minerState.canSend then return end

    minerState.canSend = false

    net.Start("nexus_miner_input")
    net.WriteString(char or "")
    net.SendToServer()
end

net.Receive("nexus_miner_round", function()
    minerState.active = true
    minerState.expected = tostring(net.ReadString() or "")
    minerState.duration = math.max(0.1, tonumber(net.ReadFloat()) or 1.0)
    minerState.roundStart = CurTime()
    minerState.step = net.ReadUInt(8)
    minerState.total = net.ReadUInt(8)
    minerState.canSend = true
end)

net.Receive("nexus_miner_finish", function()
    local success = net.ReadBool()
    local msg = tostring(net.ReadString() or "")

    minerState.active = false
    minerState.canSend = false

    chat.AddText(
        success and Color(120, 230, 150) or Color(230, 120, 120),
        "[MINER] ",
        color_white,
        msg
    )
end)

hook.Add("PlayerButtonDown", "NexusMinerButtonCapture", function(_, button)
    if not minerState.active then return end

    local char = keyToChar[button]
    if not char then return end

    sendInput(char)
end)

hook.Add("HUDPaint", "NexusMinerHUD", function()
    if not minerState.active then return end

    local sw, sh = ScrW(), ScrH()
    local cx, cy = sw * 0.5, sh * 0.5

    local baseRadius = 90
    local ringWidth = 14

    local elapsed = CurTime() - minerState.roundStart
    local t = math.Clamp(elapsed / math.max(0.01, minerState.duration), 0, 1)
    local remain = 1 - t
    local dynamicRadius = baseRadius * remain

    -- Background vignette
    draw.RoundedBox(0, 0, 0, sw, sh, Color(8, 10, 16, 120))

    -- Header
    draw.SimpleText("ДОБЫЧА РУДЫ", "NexusMinerTitle", cx, cy - 180, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(
        "Шаг " .. tostring(minerState.step) .. " / " .. tostring(minerState.total),
        "NexusMinerText",
        cx,
        cy - 146,
        Color(170, 184, 214),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )

    -- Main dark circle
    draw.NoTexture()
    surface.SetDrawColor(20, 24, 36, 245)
    surface.DrawPoly((function()
        local poly = {}
        for i = 0, 64 do
            local a = math.rad((i / 64) * -360)
            poly[#poly + 1] = { x = cx + math.sin(a) * baseRadius, y = cy + math.cos(a) * baseRadius }
        end
        return poly
    end)())

    -- Target key
    draw.SimpleText(minerState.expected, "NexusMinerKey", cx, cy - 4, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Ring progress (shrinks to center)
    local ringColor = Color(88, 156, 255, 235)
    if remain < 0.35 then
        ringColor = Color(236, 128, 128, 235)
    elseif remain < 0.65 then
        ringColor = Color(240, 196, 114, 235)
    end

    surface.SetDrawColor(ringColor)
    for i = 0, ringWidth - 1 do
        surface.DrawCircle(cx, cy, math.max(0, dynamicRadius + i), ringColor.r, ringColor.g, ringColor.b, ringColor.a)
    end

    -- Instruction
    draw.SimpleText("Нажмите " .. minerState.expected, "NexusMinerText", cx, cy + 120, Color(190, 202, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- Hide context hints while minigame is active
hook.Add("HUDShouldDraw", "NexusMinerHideHints", function(name)
    if not minerState.active then return end
    if name == "CHudHintDisplay" then return false end
end)