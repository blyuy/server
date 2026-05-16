if SERVER then return end

surface.CreateFont("NexusTabBrand", {
    font = "Roboto",
    size = 34,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusTabInfo", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true
})

surface.CreateFont("NexusTabHead", {
    font = "Roboto",
    size = 15,
    weight = 600,
    antialias = true
})

surface.CreateFont("NexusTabRow", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true
})

local function cfgValue(key, fallback)
    local cfg = NEXUS_UI_CONFIG and NEXUS_UI_CONFIG.Tab
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

local frame
local scroll
local rowsById = {}
local expandedRow
local lastSyncAt = 0
local isTabHeld = false

local DEFAULT_ACTIONS = {
    { id = "copy_steamid", label = "Скопировать SteamID", icon = "icon16/page_copy.png", enabled = true },
    { id = "open_steam_profile", label = "Открыть профиль Steam", icon = "icon16/world_link.png", enabled = true },
    { id = "teleport_sam", label = "Телепортировать (sam teleport)", icon = "icon16/arrow_right.png", enabled = true }
}

local function getConfiguredActions()
    local configured = cfgValue("actions", DEFAULT_ACTIONS)
    local result = {}

    for _, action in ipairs(configured) do
        local id = action.id
        if id and action.enabled ~= false then
            result[#result + 1] = action
        end
    end

    return result
end

local function getMoneyText(ply)
    if not IsValid(ply) then return "0" end

    if DarkRP and ply.getDarkRPVar then
        local money = ply:getDarkRPVar("money") or 0
        if DarkRP.formatMoney then
            return DarkRP.formatMoney(money)
        end

        return tostring(money)
    end

    return "0"
end

local function sortedPlayers()
    local list = player.GetAll()
    table.sort(list, function(a, b)
        if not IsValid(a) or not IsValid(b) then return false end
        if a:Team() == b:Team() then
            return string.lower(a:Nick()) < string.lower(b:Nick())
        end

        return a:Team() < b:Team()
    end)

    return list
end

local function setRowExpanded(row)
    if expandedRow == row then
        expandedRow = nil
        return
    end

    expandedRow = row
end

local function createActionButton(parent, label, iconMat)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn.label = label
    btn.icon = iconMat
    btn.hover = 0
    btn.fade = 0

    btn.Paint = function(self, w, h)
        self.hover = Lerp(FrameTime() * 12, self.hover, self:IsHovered() and 1 or 0)

        local alpha = math.floor(230 * self.fade)
        local c = Color(
            Lerp(self.hover, 41, 58),
            Lerp(self.hover, 46, 72),
            Lerp(self.hover, 64, 104),
            alpha
        )
        draw.RoundedBox(6, 0, 0, w, h, c)

        if self.icon then
            surface.SetMaterial(self.icon)
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawTexturedRect(8, 7, 16, 16)
        end

        draw.SimpleText(self.label, "NexusTabHead", 30, h * 0.5, Color(240, 244, 252, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    return btn
end

local ACTION_HANDLERS = {
    copy_steamid = function(row)
        if not IsValid(row.target) then return end
        SetClipboardText(row.target:SteamID())
        chat.AddText(Color(90, 210, 255), "[NEXUS] ", color_white, "SteamID скопирован: " .. row.target:SteamID())
    end,
    open_steam_profile = function(row)
        if not IsValid(row.target) then return end
        local sid64 = row.target:SteamID64()
        if sid64 and sid64 ~= "0" then
            gui.OpenURL("https://steamcommunity.com/profiles/" .. sid64)
        end
    end,
    teleport_sam = function(row)
        if not IsValid(row.target) then return end
        net.Start("nexus_tab_teleport")
        net.WriteEntity(row.target)
        net.SendToServer()
    end
}

local function createRow(parent, ply)
    local id = ply:SteamID64() or tostring(ply:EntIndex())
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 8)
    row:SetTall(cfgValue("rowHeight", 46))
    row.target = ply
    row.expand = 0
    row.hover = 0

    row.baseH = cfgValue("rowHeight", 46)
    row.extendedH = cfgValue("expandedRowHeight", 102)

    row.clickLayer = vgui.Create("DButton", row)
    row.clickLayer:SetText("")
    row.clickLayer.DoClick = function()
        setRowExpanded(row)
    end
    row.clickLayer.Paint = nil

    row.avatar = vgui.Create("AvatarImage", row)
    row.avatar:SetSize(30, 30)
    row.avatar:SetPos(8, 8)
    row.avatar:SetPlayer(ply, 32)

    row.actionButtons = {}
    for _, action in ipairs(getConfiguredActions()) do
        local handler = ACTION_HANDLERS[action.id]
        if handler then
            local icon = action.icon and Material(action.icon) or nil
            local btn = createActionButton(row, action.label or action.id, icon)
            btn.DoClick = function()
                handler(row)
            end

            row.actionButtons[#row.actionButtons + 1] = btn
        end
    end

    row.Think = function(self)
        local isExpanded = expandedRow == self
        local speed = cfgValue("rowAnimSpeed", 12)
        self.expand = Lerp(FrameTime() * speed, self.expand, isExpanded and 1 or 0)
        self.hover = Lerp(FrameTime() * 12, self.hover, self.clickLayer:IsHovered() and 1 or 0)

        local h = math.floor(Lerp(self.expand, self.baseH, self.extendedH))
        if self:GetTall() ~= h then
            self:SetTall(h)
        end

        self.clickLayer:SetPos(0, 0)
        self.clickLayer:SetSize(self:GetWide(), self.baseH)

        local visible = self.expand > 0.02
        local count = #self.actionButtons
        if count > 0 then
            local insetX = cfgValue("actionInsetX", 10)
            local gap = cfgValue("actionGap", 8)
            local y = self.baseH + cfgValue("actionTopOffset", 26)
            local btnH = cfgValue("actionButtonHeight", 30)
            local totalGaps = gap * (count - 1)
            local availableW = self:GetWide() - (insetX * 2) - totalGaps
            local btnW = math.floor(availableW / count)

            for index, btn in ipairs(self.actionButtons) do
                local x = insetX + (index - 1) * (btnW + gap)
                btn:SetPos(x, y)
                btn:SetSize(btnW, btnH)
                btn.fade = self.expand
                btn:SetMouseInputEnabled(visible)
            end
        end
    end

    row.Paint = function(self, w, h)
        local accent = Lerp(self.hover, 0, 12)
        draw.RoundedBox(8, 0, 0, w, h, Color(28 + accent, 31 + accent, 44 + accent, 245))
        draw.RoundedBox(0, 0, self.baseH - 1, w, 1, Color(255, 255, 255, math.floor(12 * self.expand)))

        local target = self.target
        local nick = IsValid(target) and target:Nick() or "Unknown"
        local job = IsValid(target) and team.GetName(target:Team()) or "N/A"
        local ping = IsValid(target) and target:Ping() or 0

        draw.SimpleText(nick, "NexusTabRow", 48, self.baseH * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(job, "NexusTabRow", w * 0.56, self.baseH * 0.5, Color(188, 196, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(getMoneyText(target), "NexusTabRow", w - 126, self.baseH * 0.5, Color(228, 234, 245), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(ping), "NexusTabRow", w - 18, self.baseH * 0.5, Color(228, 234, 245), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        if self.expand > 0.01 and #self.actionButtons > 0 then
            draw.SimpleText("Действия", "NexusTabHead", 10, self.baseH + 6, Color(157, 166, 192, math.floor(220 * self.expand)), TEXT_ALIGN_LEFT)
        end
    end

    rowsById[id] = row
    return row
end

local function syncRows()
    if not IsValid(scroll) then return end

    local players = sortedPlayers()
    local alive = {}

    for i, ply in ipairs(players) do
        if IsValid(ply) then
            local id = ply:SteamID64() or tostring(ply:EntIndex())
            alive[id] = true

            local row = rowsById[id]
            if not IsValid(row) then
                row = createRow(scroll, ply)
            else
                row.target = ply
                row.avatar:SetPlayer(ply, 32)
            end

            row:SetZPos(i)
        end
    end

    for id, row in pairs(rowsById) do
        if not alive[id] then
            if expandedRow == row then
                expandedRow = nil
            end

            if IsValid(row) then row:Remove() end
            rowsById[id] = nil
        end
    end
end

local function closeTabMenu()
    if IsValid(frame) then
        frame:Remove()
    end

    gui.EnableScreenClicker(false)
    frame = nil
    scroll = nil
    rowsById = {}
    expandedRow = nil
end

local function openTabMenu()
    if IsValid(frame) then return end

    frame = vgui.Create("DFrame")
    frame:SetSize(ScrW() * 0.72, ScrH() * 0.74)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false)

    gui.EnableScreenClicker(true)

    frame.anim = 0
    frame.Paint = function(self, w, h)
        local speed = cfgValue("openAnimSpeed", 10)
        self.anim = Lerp(FrameTime() * speed, self.anim, 1)

        local alpha = math.floor(Lerp(self.anim, 0, 238))
        local slide = math.floor(Lerp(self.anim, 20, 0))

        draw.RoundedBox(14, 0, slide + 8, w, h - 8 - slide, Color(16, 18, 26, alpha))

        draw.SimpleText("NEXUS DARKRP", "NexusTabBrand", 24, slide + 24, Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT)
        draw.SimpleText("Онлайн: " .. player.GetCount(), "NexusTabInfo", 24, slide + 64, Color(185, 190, 210, alpha), TEXT_ALIGN_LEFT)
        draw.SimpleText("Нажмите по игроку, чтобы открыть действия", "NexusTabInfo", w - 24, slide + 64, Color(165, 172, 196, alpha), TEXT_ALIGN_RIGHT)
    end

    scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(14, cfgValue("contentTop", 104), 14, 14)

    local header = vgui.Create("DPanel", scroll)
    header:Dock(TOP)
    header:DockMargin(0, 0, 0, 8)
    header:SetTall(22)
    header.Paint = function(_, w, h)
        draw.SimpleText("ИГРОК", "NexusTabHead", 8, h * 0.5, Color(156, 165, 188), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ПРОФЕССИЯ", "NexusTabHead", w * 0.56, h * 0.5, Color(156, 165, 188), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ДЕНЬГИ", "NexusTabHead", w - 126, h * 0.5, Color(156, 165, 188), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText("PING", "NexusTabHead", w - 18, h * 0.5, Color(156, 165, 188), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    syncRows()
end

local function onTabPressed()
    isTabHeld = true
    openTabMenu()
end

local function onTabReleased()
    isTabHeld = false
    closeTabMenu()
end

hook.Add("Think", "NexusTabSyncThink", function()
    if not isTabHeld or not IsValid(frame) then return end
    if lastSyncAt > CurTime() then return end

    lastSyncAt = CurTime() + cfgValue("refreshInterval", 0.4)
    syncRows()
end)

hook.Add("ScoreboardShow", "NexusScoreboardShow", function()
    onTabPressed()
    return false
end)

hook.Add("ScoreboardHide", "NexusScoreboardHide", function()
    onTabReleased()
    return false
end)

hook.Add("PlayerBindPress", "NexusScoreboardBind", function(_, bind, pressed)
    local key = string.lower(bind or "")
    if key ~= "+showscores" and key ~= "showscores" and key ~= "-showscores" then return end

    if key == "-showscores" or not pressed then
        onTabReleased()
    else
        onTabPressed()
    end

    return true
end)