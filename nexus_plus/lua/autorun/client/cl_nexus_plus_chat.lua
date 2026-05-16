if SERVER then return end

local function cfgValue(key, fallback)
    local cfg = NEXUS_PLUS_CONFIG and NEXUS_PLUS_CONFIG.ChatBox
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

surface.CreateFont("NexusChatTitle", {
    font = "Roboto",
    size = 17,
    weight = 700,
    antialias = true
})

surface.CreateFont("NexusChatText", {
    font = "Roboto",
    size = 17,
    weight = 500,
    antialias = true
})

surface.CreateFont("NexusChatMeta", {
    font = "Roboto",
    size = 14,
    weight = 600,
    antialias = true
})

local frame
local scroll
local input
local hintLabel
local channelsWrap
local channelButtons = {}
local currentFilter = "all"
local isTeamChat = false
local openChatFrame
local closeChat

local messages = {}
local history = {}
local historyIndex = 0

_G.NEXUS_PLUS_CHAT_IS_OPEN = false

local CHANNEL_COLORS = {
    all = Color(90, 140, 230),
    ic = Color(88, 157, 232),
    ooc = Color(115, 182, 116),
    team = Color(222, 161, 66),
    advert = Color(182, 114, 230),
    system = Color(140, 146, 168),
    private = Color(224, 126, 82)
}

local function colorForChannel(channel)
    return CHANNEL_COLORS[channel] or CHANNEL_COLORS.all
end

local function sendChatMessage(text, teamChat)
    local message = tostring(text or "")
    if message == "" then return end

    -- Use client console command directly for reliable DarkRP slash-command handling.
    local ply = LocalPlayer()
    if IsValid(ply) then
        local escaped = string.format("%q", message)
        ply:ConCommand((teamChat and "say_team " or "say ") .. escaped)
    end
end

local function classifyMessage(text, teamChat, isSystem)
    if isSystem then return "system" end
    if teamChat then return "team" end

    local lowered = string.lower(string.Trim(text or ""))
    if string.find(lowered, "[advert]", 1, true) or string.find(lowered, "(advert)", 1, true) then return "advert" end
    if string.sub(lowered, 1, 1) == "*" then return "ic" end
    if string.sub(lowered, 1, 2) == "//" then return "ooc" end
    if string.sub(lowered, 1, 4) == "/ooc" then return "ooc" end
    if string.sub(lowered, 1, 3) == "/ad" then return "advert" end
    if string.sub(lowered, 1, 2) == "/w" or string.sub(lowered, 1, 3) == "/pm" then return "private" end

    return "ic"
end

local function channelLabelFromText(text, channel)
    local lowered = string.lower(string.Trim(text or ""))

    if channel == "advert" then return "ADVERT" end
    if channel == "team" then return "TEAM" end
    if channel == "system" then return "SYSTEM" end
    if channel == "private" then return "PM" end
    if channel == "ooc" then return "OOC" end
    if string.sub(lowered, 1, 3) == "/me" or string.sub(lowered, 1, 1) == "*" then
        return "ME"
    end

    return "IC"
end

local function shouldShowMessage(msg)
    if currentFilter == "all" then return true end
    if currentFilter == "ooc" then
        return msg.channel == "ooc" or msg.channel == "advert"
    end

    return msg.channel == currentFilter
end

local function messageAlpha(msg)
    if IsValid(input) and input:HasFocus() then return 255 end

    if msg.fadeAt > CurTime() then return 255 end
    if msg.fadeEnd <= CurTime() then return 0 end

    local ratio = 1 - ((CurTime() - msg.fadeAt) / math.max(0.01, msg.fadeEnd - msg.fadeAt))
    return math.floor(255 * math.Clamp(ratio, 0, 1))
end

local function createMessageLine(parent, msg)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 6)
    row:SetTall(26)
    row.msg = msg

    row.Paint = function(self, w, h)
        local m = self.msg
        local alpha = messageAlpha(m)
        if alpha <= 0 then return end

        draw.RoundedBox(6, 0, 0, w, h, Color(14, 16, 24, math.floor(alpha * 0.22)))

        local x = 8

        if cfgValue("showTimestamps", true) then
            draw.SimpleText(m.timeText, "NexusChatMeta", x, h * 0.5, Color(155, 164, 188, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetFont("NexusChatMeta")
            local tw = surface.GetTextSize(m.timeText)
            x = x + tw + 6
        end

        local channelColor = colorForChannel(m.channel)
        channelColor = Color(channelColor.r, channelColor.g, channelColor.b, alpha)
        local tagText = "[" .. string.upper(m.channelLabel) .. "]"
        draw.SimpleText(tagText, "NexusChatMeta", x, h * 0.5, channelColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetFont("NexusChatMeta")
        local cw = surface.GetTextSize(tagText)
        x = x + cw + 8

        if m.name ~= "" then
            draw.SimpleText(m.name .. ":", "NexusChatText", x, h * 0.5, Color(235, 240, 252, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetFont("NexusChatText")
            local nw = surface.GetTextSize(m.name .. ":")
            x = x + nw + 6
        end

        draw.SimpleText(m.text, "NexusChatText", x, h * 0.5, Color(225, 230, 245, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    return row
end

local function refreshChatList()
    if not IsValid(scroll) then return end
    scroll:Clear()

    local canvas = scroll:GetCanvas()
    for _, msg in ipairs(messages) do
        if shouldShowMessage(msg) then
            createMessageLine(canvas, msg)
        end
    end

    scroll:InvalidateLayout(true)
    local children = canvas:GetChildren()
    if #children > 0 then
        scroll:ScrollToChild(children[#children])
    end
end

local function addMessage(name, text, teamChat, isSystem)
    if not IsValid(frame) and openChatFrame then
        openChatFrame()
    end

    local now = CurTime()
    local channel = classifyMessage(text, teamChat, isSystem)
    local line = {
        time = now,
        fadeAt = now + cfgValue("fadeDelay", 9),
        fadeEnd = now + cfgValue("fadeDelay", 9) + cfgValue("fadeDuration", 5),
        timeText = os.date("%H:%M"),
        channel = channel,
        channelLabel = channelLabelFromText(text, channel),
        name = name or "",
        text = tostring(text or "")
    }

    messages[#messages + 1] = line

    local max = cfgValue("maxMessages", 140)
    while #messages > max do
        table.remove(messages, 1)
    end

    refreshChatList()
end

local function updateHintText()
    if not IsValid(hintLabel) or not IsValid(input) then return end
    local text = string.Trim(input:GetText() or "")

    if string.sub(text, 1, 1) ~= "/" then
        hintLabel:SetText("")
        return
    end

    local first = nil
    local lowered = string.lower(text)
    for _, cmd in ipairs(cfgValue("commandSuggestions", {})) do
        local c = string.lower(cmd)
        if string.find(c, lowered, 1, true) == 1 then
            first = cmd
            break
        end
    end

    if first then
        hintLabel:SetText("TAB: " .. first)
    else
        hintLabel:SetText("")
    end
end

local function applySuggestion()
    if not IsValid(input) then return false end
    local text = string.Trim(input:GetText() or "")
    if string.sub(text, 1, 1) ~= "/" then return false end

    local lowered = string.lower(text)
    for _, cmd in ipairs(cfgValue("commandSuggestions", {})) do
        local c = string.lower(cmd)
        if string.find(c, lowered, 1, true) == 1 then
            input:SetText(cmd .. " ")
            input:SetCaretPos(string.len(cmd) + 1)
            updateHintText()
            return true
        end
    end

    return false
end

local function historySet(offset)
    if #history == 0 then return end

    historyIndex = math.Clamp(historyIndex + offset, 1, #history + 1)
    if historyIndex == #history + 1 then
        input:SetText("")
        input:SetCaretPos(0)
        return
    end

    local value = history[historyIndex] or ""
    input:SetText(value)
    input:SetCaretPos(string.len(value))
end

local function styleChannelButtons()
    for _, btn in ipairs(channelButtons) do
        btn:SetSelected(btn.channelId == currentFilter)
    end
end

openChatFrame = function()
    if IsValid(frame) then return end

    local w = cfgValue("width", 640)
    local h = cfgValue("height", 300)
    local x = cfgValue("x", 22)
    local y = ScrH() - h - cfgValue("yFromBottom", 170)
    local rounded = cfgValue("rounded", 10)

    frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:SetPos(x, y)
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetSizable(false)
    frame:SetKeyboardInputEnabled(true)
    frame:SetMouseInputEnabled(true)
    frame:SetAlpha(0)
    frame:SetVisible(true)

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetSize(24, 20)
    closeBtn:SetPos(w - 30, 8)
    closeBtn:SetText("X")
    closeBtn:SetFont("NexusChatMeta")
    closeBtn:SetTextColor(color_white)
    closeBtn.Paint = function(self, bw, bh)
        draw.RoundedBox(6, 0, 0, bw, bh, Color(58, 66, 92, self:IsHovered() and 240 or 210))
    end
    closeBtn.DoClick = function()
        closeChat()
    end

    frame.Paint = function(self, fw, fh)
        local target = _G.NEXUS_PLUS_CHAT_IS_OPEN and 238 or 145
        local speed = cfgValue("openAnimSpeed", 14)
        self:SetAlpha(Lerp(FrameTime() * speed, self:GetAlpha(), target))

        local a = self:GetAlpha()
        draw.RoundedBox(rounded, 0, 0, fw, fh, Color(16, 18, 26, a))
        draw.SimpleText(isTeamChat and "Командный чат" or "Чат", "NexusChatTitle", 10, 16, Color(235, 240, 252, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Фильтр", "NexusChatMeta", fw - 56, 16, Color(165, 174, 202, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.RoundedBox(0, 0, fh - cfgValue("inputHeight", 34) - 14, fw, 1, Color(255, 255, 255, 24))
    end

    channelsWrap = vgui.Create("DPanel", frame)
    channelsWrap:SetPos(112, 6)
    channelsWrap:SetSize(w - 122, 22)
    channelsWrap.Paint = nil

    local xOffset = 0
    channelButtons = {}
    for _, channel in ipairs(cfgValue("channels", {})) do
        local btn = vgui.Create("DButton", channelsWrap)
        btn:SetText(channel.label or channel.id)
        btn:SetFont("NexusChatMeta")
        btn:SetTextColor(color_white)
        btn:SetSize(68, 20)
        btn:SetPos(xOffset, 1)
        btn.channelId = channel.id
        btn.selected = false

        btn.SetSelected = function(self, state)
            self.selected = state == true
        end

        btn.Paint = function(self, bw, bh)
            local c = self.selected and Color(74, 123, 214, 238) or Color(39, 45, 66, self:IsHovered() and 232 or 205)
            draw.RoundedBox(6, 0, 0, bw, bh, c)
        end

        btn.DoClick = function(self)
            currentFilter = self.channelId
            styleChannelButtons()
            refreshChatList()
        end

        channelButtons[#channelButtons + 1] = btn
        xOffset = xOffset + 74
    end

    scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(8, 32)
    scroll:SetSize(w - 16, h - cfgValue("inputHeight", 34) - 56)

    hintLabel = vgui.Create("DLabel", frame)
    hintLabel:SetPos(10, h - cfgValue("inputHeight", 34) - 30)
    hintLabel:SetSize(w - 20, 14)
    hintLabel:SetFont("NexusChatMeta")
    hintLabel:SetTextColor(Color(142, 178, 235))
    hintLabel:SetText("")

    input = vgui.Create("DTextEntry", frame)
    input:SetPos(8, h - cfgValue("inputHeight", 34) - 8)
    input:SetSize(w - 16, cfgValue("inputHeight", 34))
    input:SetFont("NexusChatText")
    input:SetPlaceholderText("Введите сообщение...")
    input.Paint = function(self, iw, ih)
        draw.RoundedBox(8, 0, 0, iw, ih, Color(28, 31, 44, 245))
        self:DrawTextEntryText(Color(235, 240, 252), Color(90, 140, 230), color_white)
    end

    input.OnTextChanged = function()
        updateHintText()
    end

    input.OnKeyCodeTyped = function(self, key)
        if key == KEY_TAB then
            if applySuggestion() then return true end
        elseif key == KEY_UP then
            historySet(-1)
            return true
        elseif key == KEY_DOWN then
            historySet(1)
            return true
        elseif key == KEY_ENTER or key == KEY_PAD_ENTER then
            self:OnEnter()
            return true
        end
    end

    input.OnEnter = function(self)
        local text = string.Trim(self:GetText() or "")
        if text ~= "" then
            history[#history + 1] = text
            historyIndex = #history + 1
            sendChatMessage(text, isTeamChat)
        end

        self:SetText("")
        updateHintText()
        closeChat()
    end

    frame:SetKeyboardInputEnabled(false)
    frame:SetMouseInputEnabled(false)
    input:SetVisible(false)
    hintLabel:SetVisible(false)
    channelsWrap:SetVisible(false)

    styleChannelButtons()
    refreshChatList()
end

local function openChat(teamChat)
    if not cfgValue("enabled", true) then return end

    openChatFrame()
    isTeamChat = teamChat == true

    frame:SetVisible(true)
    frame:SetKeyboardInputEnabled(true)
    frame:SetMouseInputEnabled(true)
    frame:MakePopup()
    if IsValid(input) then input:SetVisible(true) end
    if IsValid(hintLabel) then hintLabel:SetVisible(true) end
    if IsValid(channelsWrap) then channelsWrap:SetVisible(true) end
    input:RequestFocus()
    historyIndex = #history + 1
    updateHintText()
    _G.NEXUS_PLUS_CHAT_IS_OPEN = true
end

closeChat = function()
    if not IsValid(frame) then return end
    frame:SetVisible(true)
    frame:SetKeyboardInputEnabled(false)
    frame:SetMouseInputEnabled(false)
    if IsValid(input) then input:SetVisible(false) end
    if IsValid(hintLabel) then hintLabel:SetVisible(false) end
    if IsValid(channelsWrap) then channelsWrap:SetVisible(false) end
    _G.NEXUS_PLUS_CHAT_IS_OPEN = false
end

_G.NEXUS_PLUS_CHAT_CLOSE = closeChat

hook.Add("StartChat", "NexusPlusStartChat", function(teamChat)
    if not cfgValue("enabled", true) then return end
    openChat(teamChat)
    return true
end)

hook.Add("FinishChat", "NexusPlusFinishChat", function()
    if not cfgValue("enabled", true) then return end
    closeChat()
    return true
end)

hook.Add("OnPlayerChat", "NexusPlusOnPlayerChat", function(ply, text, teamChat)
    if not cfgValue("enabled", true) then return end
    local name = IsValid(ply) and ply:Nick() or "Console"
    addMessage(name, text, teamChat, false)
end)

hook.Add("ChatText", "NexusPlusChatText", function(_, _, text)
    if not cfgValue("enabled", true) then return end
    addMessage("", text, false, true)
end)

-- Backup capture path if another addon blocks OnPlayerChat hooks.
gameevent.Listen("player_say")
hook.Add("player_say", "NexusPlusPlayerSayEvent", function(data)
    if not cfgValue("enabled", true) then return end

    local text = tostring(data.text or "")
    local teamChat = data.teamchat == 1
    local speaker = Player(data.userid or 0)
    local name = IsValid(speaker) and speaker:Nick() or tostring(data.name or "Игрок")

    addMessage(name, text, teamChat, false)
end)

hook.Add("HUDShouldDraw", "NexusPlusHideDefaultChat", function(name)
    if not cfgValue("enabled", true) then return end
    if name == "CHudChat" then
        return false
    end
end)

hook.Add("Think", "NexusPlusChatFadeGC", function()
    if not cfgValue("enabled", true) then return end
    if IsValid(input) and input:HasFocus() then return end

    local changed = false
    for i = #messages, 1, -1 do
        if messageAlpha(messages[i]) <= 0 then
            table.remove(messages, i)
            changed = true
        end
    end

    if changed then
        refreshChatList()
    end
end)

hook.Add("Think", "NexusPlusChatEscClose", function()
    if not IsValid(frame) or not frame:IsVisible() then return end
    if not _G.NEXUS_PLUS_CHAT_IS_OPEN then return end

    if _G.input and _G.input.IsKeyDown and _G.input.IsKeyDown(KEY_ESCAPE) then
        closeChat()
    end
end)