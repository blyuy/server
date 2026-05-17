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

local function setInfo(label, door)
    if not IsValid(label) then return end

    local class = IsValid(door) and door:GetClass() or "-"
    local owner = XPDRP.GetDoorOwnerName(door)
    local title = IsValid(door) and XPDRP.SafeText(door.getKeysTitle and door:getKeysTitle() or "Без названия") or "Без названия"

    label:SetText("Класс: " .. class .. "\nВладелец: " .. owner .. "\nНазвание: " .. title)
end

local function createActionButton(parent, title, subtitle, callback)
    local btn = vgui.Create("DButton", parent)
    btn:Dock(TOP)
    btn:DockMargin(0, 0, 0, 7)
    btn:SetTall(52)
    btn:SetText("")

    btn.Paint = function(self, w, h)
        self.Hov = Lerp(FrameTime() * 16, self.Hov or 0, self:IsHovered() and 1 or 0)
        local bg = Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 24 + self.Hov * 26)

        draw.RoundedBox(0, 0, 0, w, h, bg)
        surface.SetDrawColor(255, 255, 255, 16)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText(title, "xpgui_medium", 12, 17, UI.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "xpgui_tiny", 12, 36, UI.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = callback
    return btn
end

function XPDRP.OpenDoorMenu(door)
    if not IsValid(door) then
        door = XPDRP.GetLookDoor()
    end

    if not IsValid(door) then
        chat.AddText(Color(255, 140, 140), "[XPDRP] Смотрите на дверь для открытия меню.")
        return
    end

    if IsValid(frame) then frame:Remove() end

    frame = vgui.Create("XPFrame")
    frame:SetTitle("Меню двери")
    frame:SetSize(620, 460)
    frame:Center()
    frame:MakePopup()

    local root = vgui.Create("DPanel", frame)
    root:Dock(FILL)
    root:DockMargin(8, 8, 8, 8)
    root.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local left = vgui.Create("DPanel", root)
    left:Dock(LEFT)
    left:SetWide(250)
    left:DockMargin(8, 8, 8, 8)
    left.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, UI.Panel)
        draw.RoundedBox(0, 0, 0, w, 2, UI.AccentSoft)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local info = vgui.Create("DLabel", left)
    info:Dock(TOP)
    info:DockMargin(10, 10, 10, 10)
    info:SetFont("xpgui_medium")
    info:SetTextColor(UI.Text)
    info:SetWrap(true)
    info:SetAutoStretchVertical(true)
    setInfo(info, door)

    local titleEntry = vgui.Create("XPTextEntry", left)
    titleEntry:Dock(TOP)
    titleEntry:DockMargin(10, 0, 10, 8)
    titleEntry:SetTall(32)
    titleEntry:SetPlaceholderText("Новое название двери")
    titleEntry:SetText(door.getKeysTitle and door:getKeysTitle() or "")

    local playerSelect = vgui.Create("XPComboBox", left)
    playerSelect:Dock(TOP)
    playerSelect:DockMargin(10, 0, 10, 10)
    playerSelect:SetTall(32)
    playerSelect:SetValue("Выберите игрока")

    local selected
    for _, ply in ipairs(player.GetAll()) do
        if ply ~= LocalPlayer() then
            playerSelect:AddChoice(ply:Nick() .. " [" .. ply:SteamID() .. "]", ply)
        end
    end

    playerSelect.OnSelect = function(_, _, _, data)
        selected = data
    end

    local right = vgui.Create("DPanel", root)
    right:Dock(FILL)
    right:DockMargin(0, 8, 8, 8)
    right.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, UI.Panel)
        draw.RoundedBox(0, 0, 0, w, 2, UI.AccentSoft)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local scroll = vgui.Create("XPScrollPanel", right)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)

    createActionButton(scroll, "Купить дверь", "Команда: /buydoor", function()
        XPDRP.RunDarkRPCommand("buydoor")
    end)

    createActionButton(scroll, "Продать дверь", "Команда: /selldoor", function()
        XPDRP.RunDarkRPCommand("selldoor")
    end)

    createActionButton(scroll, "Добавить совладельца", "Команда: /addowner <steamid>", function()
        if not IsValid(selected) then return end
        XPDRP.RunDarkRPCommand("addowner " .. selected:SteamID())
    end)

    createActionButton(scroll, "Удалить совладельца", "Команда: /removeowner <steamid>", function()
        if not IsValid(selected) then return end
        XPDRP.RunDarkRPCommand("removeowner " .. selected:SteamID())
    end)

    createActionButton(scroll, "Изменить название", "Команда: /title <название>", function()
        local title = string.Trim(titleEntry:GetText() or "")
        if title == "" then return end
        XPDRP.RunDarkRPCommand("title " .. title)
        timer.Simple(0.15, function()
            if IsValid(info) and IsValid(door) then setInfo(info, door) end
        end)
    end)

    createActionButton(scroll, "Переключить ownable (админ)", "Команда: /toggleownable", function()
        XPDRP.RunDarkRPCommand("toggleownable")
    end)

    frame:SetBottomButton("Обновить", LEFT, function()
        setInfo(info, door)
    end)

    frame:SetBottomButton("Закрыть", RIGHT, function()
        if IsValid(frame) then frame:Close() end
    end)
end

concommand.Add("xpdrp_door_menu", function()
    XPDRP.OpenDoorMenu()
end)
