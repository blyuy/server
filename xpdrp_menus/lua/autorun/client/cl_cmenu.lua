if not CLIENT then return end

XPDRP = XPDRP or {}

local frame

local UI = {
    Bg = Color(10, 14, 22, 210),
    Panel = Color(12, 17, 27, 236),
    Border = Color(255, 255, 255, 12),
    Accent = Color(82, 162, 255),
    AccentSoft = Color(82, 162, 255, 58),
    Text = Color(230, 236, 245),
    TextDim = Color(166, 182, 205)
}

local function createActionButton(parent, title, subtitle, callback)
    local btn = vgui.Create("DButton", parent)
    btn:Dock(TOP)
    btn:DockMargin(0, 0, 0, 7)
    btn:SetTall(52)
    btn:SetText("")

    btn.Paint = function(self, w, h)
        self.Hov = Lerp(FrameTime() * 16, self.Hov or 0, self:IsHovered() and 1 or 0)
        local bg = Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 24 + self.Hov * 28)

        draw.RoundedBox(0, 0, 0, w, h, bg)
        surface.SetDrawColor(255, 255, 255, 16)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText(title, "xpgui_medium", 12, 17, UI.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "xpgui_tiny", 12, 36, UI.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = callback
    return btn
end

local function createPanel(sheet)
    local panel = vgui.Create("DPanel", sheet)
    panel:Dock(FILL)
    panel.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local scroll = vgui.Create("XPScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)
    return panel, scroll
end

local function openContext()
    if IsValid(frame) then frame:Remove() end

    frame = vgui.Create("XPFrame")
    frame:SetTitle("Контекстное меню")
    frame:SetSize(560, 520)
    frame:Center()
    frame:MakePopup()

    local sheet = vgui.Create("XPPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:DockMargin(6, 6, 6, 6)

    do
        local panel, scroll = createPanel(sheet)
        createActionButton(scroll, "РП действие", "/me ...", function() XPDRP.RunDarkRPCommand("me ") end)
        createActionButton(scroll, "Объявление", "/advert ...", function() XPDRP.RunDarkRPCommand("advert ") end)
        createActionButton(scroll, "Выбросить деньги", "/dropmoney 100", function() XPDRP.RunDarkRPCommand("dropmoney 100") end)
        createActionButton(scroll, "Передать предмет", "/give", function() XPDRP.RunDarkRPCommand("give") end)
        createActionButton(scroll, "Открыть меню двери", "Управление дверью", function()
            if XPDRP.OpenDoorMenu then XPDRP.OpenDoorMenu() end
        end)
        sheet:AddSheet("Команды", panel)
    end

    do
        local panel, scroll = createPanel(sheet)
        createActionButton(scroll, "Жест: помахать", "act wave", function() RunConsoleCommand("act", "wave") end)
        createActionButton(scroll, "Жест: поклон", "act bow", function() RunConsoleCommand("act", "bow") end)
        createActionButton(scroll, "Жест: танец", "act dance", function() RunConsoleCommand("act", "dance") end)
        createActionButton(scroll, "Скриншот", "jpeg", function() RunConsoleCommand("jpeg") end)
        createActionButton(scroll, "Скрыть HUD", "cl_drawhud 0", function() RunConsoleCommand("cl_drawhud", "0") end)
        createActionButton(scroll, "Показать HUD", "cl_drawhud 1", function() RunConsoleCommand("cl_drawhud", "1") end)
        sheet:AddSheet("Жесты и утилиты", panel)
    end

    frame:SetBottomButton("Закрыть", RIGHT, function()
        if IsValid(frame) then frame:Close() end
    end)
end

local function closeContext()
    if IsValid(frame) then frame:Remove() end
end

hook.Add("OnContextMenuOpen", "XPDRP.ContextOpen", function()
    openContext()
end)

hook.Add("OnContextMenuClose", "XPDRP.ContextClose", function()
    closeContext()
end)
