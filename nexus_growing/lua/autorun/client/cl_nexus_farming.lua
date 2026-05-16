if SERVER then return end

local function sendRequest(action, ent)
    net.Start("nexus_farm_request")
    net.WriteString(action)
    net.WriteEntity(ent)
    net.SendToServer()
end

local function sendInput(ent, inputType, extra)
    net.Start("nexus_farm_game_input")
    net.WriteEntity(ent)
    net.WriteUInt(inputType, 3)
    if inputType == 2 then
        net.WriteUInt(extra or 0, 8)
    elseif inputType == 3 then
        net.WriteString(extra or "")
    end
    net.SendToServer()
end

local ui = {
    pot = nil,
    game = nil,
    currentPot = NULL,
    stage1Stability = 50,
    stage2Hit = 0,
    stage3Progress = 0
}

local stage3Hud = {
    active = false,
    ent = NULL,
    seq = {},
    progress = 0,
    startedAt = 0,
    endAt = 0,
    stepStart = 0,
    stepDuration = 0.8
}

surface.CreateFont("FarmHero", { font = "Roboto", size = 36, weight = 900, antialias = true })
surface.CreateFont("FarmTitle", { font = "Roboto", size = 24, weight = 800, antialias = true })
surface.CreateFont("FarmText", { font = "Roboto", size = 18, weight = 500, antialias = true })
surface.CreateFont("FarmSmall", { font = "Roboto", size = 14, weight = 500, antialias = true })

surface.CreateFont("NexusFarmQteTitle", {
    font = "Roboto",
    size = 36,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusFarmQteKey", {
    font = "Roboto",
    size = 64,
    weight = 900,
    antialias = true
})

surface.CreateFont("NexusFarmQteText", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true
})

local function stageName(st)
    if st == 0 then return "Пустой горшок" end
    if st == 1 then return "Семя" end
    if st == 2 then return "Росток" end
    if st == 3 then return "Зрелый куст" end
    return "Неизвестно"
end

local function drawPanel(w, h, c1, c2)
    draw.RoundedBox(12, 0, 0, w, h, c1)
    draw.RoundedBox(12, 0, 0, w, 1, c2)
end

local function createBtn(parent, text, x, y, w, h, cb)
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y)
    b:SetSize(w, h)
    b:SetText("")
    b.Paint = function(self, bw, bh)
        local hovered = self:IsHovered()
        local bg = hovered and Color(92, 141, 235, 255) or Color(72, 118, 205, 235)
        draw.RoundedBox(8, 0, 0, bw, bh, bg)
        draw.SimpleText(text, "FarmText", bw * 0.5, bh * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = cb
    return b
end

local function stopStage3Hud()
    stage3Hud.active = false
    stage3Hud.ent = NULL
    stage3Hud.seq = {}
    stage3Hud.progress = 0
    stage3Hud.startedAt = 0
    stage3Hud.endAt = 0
    stage3Hud.stepStart = 0
    stage3Hud.stepDuration = 0.8
end

local function startStage3Hud(ent, seq, totalTime)
    stage3Hud.active = true
    stage3Hud.ent = ent
    stage3Hud.seq = seq or {}
    stage3Hud.progress = 0
    stage3Hud.startedAt = CurTime()
    stage3Hud.endAt = CurTime() + math.max(0.1, tonumber(totalTime) or 5)
    stage3Hud.stepDuration = math.max(0.45, (tonumber(totalTime) or 5) / math.max(1, #stage3Hud.seq))
    stage3Hud.stepStart = CurTime()
end

hook.Remove("PlayerButtonDown", "NexusFarmStage3KeyCapture")
hook.Add("PlayerButtonDown", "NexusFarmStage3KeyCapture", function(_, button)
    if not stage3Hud.active then return end

    local keyMap = {
        [KEY_W] = "W",
        [KEY_A] = "A",
        [KEY_S] = "S",
        [KEY_D] = "D",
        [KEY_SPACE] = "SPACE"
    }

    local key = keyMap[button]
    if not key then return end
    if not IsValid(stage3Hud.ent) then return end

    sendInput(stage3Hud.ent, 3, key)
end)

hook.Remove("HUDShouldDraw", "NexusFarmStage3HideHints")
hook.Add("HUDShouldDraw", "NexusFarmStage3HideHints", function(name)
    if not stage3Hud.active then return end
    if name == "CHudHintDisplay" then return false end
end)

hook.Remove("HUDPaint", "NexusFarmStage3HudPaint")
hook.Add("HUDPaint", "NexusFarmStage3HudPaint", function()
    if not stage3Hud.active then return end
    if CurTime() > stage3Hud.endAt then return end

    local seq = stage3Hud.seq
    local progress = stage3Hud.progress
    local expected = seq[math.Clamp(progress + 1, 1, #seq)] or "-"

    local sw, sh = ScrW(), ScrH()
    local cx, cy = sw * 0.5, sh * 0.5
    local baseRadius = 90
    local ringWidth = 14

    local elapsed = CurTime() - stage3Hud.stepStart
    local t = math.Clamp(elapsed / math.max(0.01, stage3Hud.stepDuration), 0, 1)
    local remain = 1 - t
    local dynamicRadius = baseRadius * remain

    draw.RoundedBox(0, 0, 0, sw, sh, Color(8, 10, 16, 120))

    draw.SimpleText("СБОР И СУШКА", "NexusFarmQteTitle", cx, cy - 180, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(
        "Шаг " .. tostring(math.min(progress + 1, #seq)) .. " / " .. tostring(#seq),
        "NexusFarmQteText",
        cx,
        cy - 146,
        Color(170, 184, 214),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER
    )

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

    draw.SimpleText(expected, "NexusFarmQteKey", cx, cy - 4, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

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

    draw.SimpleText("Нажмите " .. expected, "NexusFarmQteText", cx, cy + 120, Color(190, 202, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

net.Receive("nexus_farm_open", function()
    local ent = net.ReadEntity()
    local st = net.ReadUInt(3)
    local nextAt = net.ReadFloat()
    if not IsValid(ent) then return end
    ui.currentPot = ent

    if IsValid(ui.pot) then ui.pot:Remove() end

    ui.pot = vgui.Create("DFrame")
    ui.pot:SetSize(1120, 640)
    ui.pot:Center()
    ui.pot:SetTitle("")
    ui.pot:SetDraggable(false)
    ui.pot:ShowCloseButton(false)
    ui.pot:MakePopup()
    ui.pot.Paint = function(self, w, h)
        drawPanel(w, h, Color(8, 12, 24, 246), Color(255, 255, 255, 14))
        draw.RoundedBox(0, 0, 102, w, 1, Color(255, 255, 255, 12))

        draw.SimpleText("NEXUS DARKRP", "FarmHero", 24, 40, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Продвинутое фермерство", "FarmText", 24, 74, Color(166, 182, 214), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local cd = math.max(0, math.ceil(nextAt - CurTime()))
        draw.SimpleText("Стадия: " .. stageName(st), "FarmText", w - 140, 40, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cd > 0 and ("Откат: " .. cd .. "с") or "Откат: нет", "FarmText", w - 140, 74, Color(166, 182, 214), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    createBtn(ui.pot, "Закрыть", ui.pot:GetWide() - 112, 20, 88, 34, function()
        ui.pot:Remove()
    end)

    local left = vgui.Create("DPanel", ui.pot)
    left:SetPos(20, 118)
    left:SetSize(330, 502)
    left.Paint = function(_, w, h)
        drawPanel(w, h, Color(13, 20, 38, 236), Color(255, 255, 255, 10))
    end

    createBtn(left, "Посадить (семя + земля + вода)", 12, 14, 306, 46, function() sendRequest("plant", ent) end)
    createBtn(left, "Начать текущий этап", 12, 68, 306, 46, function() sendRequest("start_game", ent) end)
    createBtn(left, "Обновить статус", 12, 122, 306, 46, function() sendRequest("open", ent) end)

    local right = vgui.Create("DPanel", ui.pot)
    right:SetPos(360, 118)
    right:SetSize(740, 502)
    right.Paint = function(_, w, h)
        drawPanel(w, h, Color(10, 16, 34, 236), Color(255, 255, 255, 10))
        draw.SimpleText("Особая кудрявая петрушка", "FarmTitle", 20, 30, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Этапы выращивания", "FarmText", 20, 62, Color(176, 194, 228), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.SimpleText("1) Рыхление и полив: удерживай баланс в зеленой зоне.", "FarmText", 20, 122, Color(206, 216, 238), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("2) Подрезка: нажми все красные точки до таймера.", "FarmText", 20, 156, Color(206, 216, 238), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("3) Сбор и сушка: QTE из 3 клавиш (W/A/S/D/SPACE).", "FarmText", 20, 190, Color(206, 216, 238), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.SimpleText("Провал мини-игры сбрасывает куст в пустой горшок.", "FarmSmall", 20, h - 20, Color(150, 166, 198), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end)

net.Receive("nexus_farm_game_begin", function()
    if IsValid(ui.game) then ui.game:Remove() end
    stopStage3Hud()

    local gameType = net.ReadUInt(3)
    local timeLimit = net.ReadFloat()
    local ent = ui.currentPot
    if not IsValid(ent) then return end

    ui.stage1Stability = 50
    ui.stage2Hit = 0
    ui.stage3Progress = 0

    if gameType == 3 then
        local seqLen = net.ReadUInt(8)
        local seq = {}
        for i = 1, seqLen do
            seq[i] = net.ReadString()
        end

        -- Закрываем основное меню горшка во время 3-й мини-игры
        if IsValid(ui.pot) then
            ui.pot:Remove()
        end

        startStage3Hud(ent, seq, timeLimit)
        chat.AddText(Color(130, 200, 255), "[FARM] ", color_white, "QTE начат. Следуйте подсказкам по центру экрана.")
        return
    end

    ui.game = vgui.Create("DFrame")
    ui.game:SetSize(900, 540)
    ui.game:Center()
    ui.game:SetTitle("")
    ui.game:SetDraggable(false)
    ui.game:ShowCloseButton(false)
    ui.game:MakePopup()
    ui.game.endAt = CurTime() + timeLimit
    ui.game.Paint = function(self, w, h)
        drawPanel(w, h, Color(8, 12, 24, 248), Color(255, 255, 255, 14))
        draw.RoundedBox(0, 0, 82, w, 1, Color(255, 255, 255, 12))
        draw.SimpleText("NEXUS FARMING", "FarmHero", 18, 38, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Осталось: " .. math.max(0, math.ceil(self.endAt - CurTime())) .. "с", "FarmText", w - 18, 38, Color(188, 202, 230), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    createBtn(ui.game, "Свернуть", ui.game:GetWide() - 106, 20, 86, 32, function()
        ui.game:SetVisible(false)
    end)

    if gameType == 1 then
        local phase = net.ReadFloat()
        local speed = net.ReadFloat()
        local zoneMin = net.ReadFloat()
        local zoneMax = net.ReadFloat()
        local started = CurTime()

        local panel = vgui.Create("DPanel", ui.game)
        panel:SetPos(22, 100)
        panel:SetSize(856, 418)
        panel:SetMouseInputEnabled(true)
        panel.Paint = function(_, w, h)
            drawPanel(w, h, Color(14, 20, 38, 235), Color(255, 255, 255, 10))
            draw.SimpleText("Этап 1: Рыхление и полив", "FarmTitle", 22, 26, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("ЛКМ по панели. Порог снижен, попасть легче.", "FarmText", 22, 56, Color(176, 194, 228), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            local x, y, bw, bh = 60, 165, 736, 30
            draw.RoundedBox(8, x, y, bw, bh, Color(32, 40, 66))
            draw.RoundedBox(8, x + bw * zoneMin, y, bw * (zoneMax - zoneMin), bh, Color(72, 160, 92, 230))

            local elapsed = CurTime() - started
            local p = 0.5 + 0.45 * math.sin((elapsed * speed) + phase)
            local nx = x + bw * math.Clamp(p, 0, 1)
            draw.RoundedBox(5, nx - 2, y - 12, 4, bh + 24, Color(242, 222, 138))

            draw.SimpleText("Стабильность: " .. math.floor(ui.stage1Stability) .. "%", "FarmText", 22, 252, Color(210, 224, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        panel.OnMousePressed = function(_, code)
            if code == MOUSE_LEFT then sendInput(ent, 1) end
        end
    elseif gameType == 2 then
        local count = net.ReadUInt(8)
        local points = {}
        for i = 1, count do
            points[i] = { net.ReadFloat(), net.ReadFloat() }
        end

        local board = vgui.Create("DPanel", ui.game)
        board:SetPos(22, 100)
        board:SetSize(856, 418)
        board.hitFx = 0
        board.Paint = function(_, w, h)
            drawPanel(w, h, Color(14, 20, 38, 235), Color(255, 255, 255, 10))
            draw.SimpleText("Этап 2: Подрезка сухих листьев", "FarmTitle", 22, 26, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Попаданий: " .. ui.stage2Hit .. "/" .. count, "FarmText", w - 22, 26, Color(210, 224, 250), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

            local cx, cy = w * 0.5, h * 0.56
            for i = 1, 9 do
                local r = 70 + i * 8
                surface.SetDrawColor(42, 90 + i * 4, 58 + i * 3, 18)
                surface.DrawCircle(cx + math.sin(i) * 22, cy + math.cos(i) * 14, r, 42, 110, 72, 28)
            end

            local frac = math.Clamp((ui.game.endAt - CurTime()) / math.max(0.01, timeLimit), 0, 1)
            draw.RoundedBox(6, 22, h - 28, w - 44, 10, Color(24, 32, 52, 220))
            draw.RoundedBox(6, 22, h - 28, (w - 44) * frac, 10, Color(92, 141, 235, 240))
        end

        for i = 1, #points do
            local b = vgui.Create("DButton", board)
            local px = 70 + math.floor(points[i][1] * 700)
            local py = 90 + math.floor(points[i][2] * 260)
            b:SetPos(px, py)
            b:SetSize(28, 28)
            b:SetText("")
            b.seed = math.Rand(0, 6.28)

            b.Paint = function(self, w, h)
                local pulse = (math.sin(CurTime() * 6 + self.seed) + 1) * 0.5
                local a = 180 + pulse * 70
                draw.RoundedBox(14, 0, 0, w, h, Color(220, 76, 76, a))
                draw.RoundedBox(14, 6, 6, w - 12, h - 12, Color(255, 210, 210, a))
            end

            b.DoClick = function(self)
                self:SetVisible(false)
                self:SetMouseInputEnabled(false)
                sendInput(ent, 2, i)
            end
        end
    end
end)

net.Receive("nexus_farm_game_update", function()
    local t = net.ReadUInt(3)
    if t == 1 then
        ui.stage1Stability = net.ReadUInt(8)
    elseif t == 2 then
        ui.stage2Hit = net.ReadUInt(8)
    elseif t == 3 then
        ui.stage3Progress = net.ReadUInt(8)
        stage3Hud.progress = ui.stage3Progress
        stage3Hud.stepStart = CurTime()
    end
end)

net.Receive("nexus_farm_game_finish", function()
    local ok = net.ReadBool()
    local msg = net.ReadString()

    if IsValid(ui.game) then ui.game:Remove() end
    stopStage3Hud()

    chat.AddText(ok and Color(120, 230, 150) or Color(230, 120, 120), "[FARM] ", color_white, msg)

    if IsValid(ui.currentPot) then
        sendRequest("open", ui.currentPot)
    end
end)

net.Receive("nexus_farm_notify", function()
    chat.AddText(Color(130, 200, 255), "[FARM] ", color_white, net.ReadString())
end)