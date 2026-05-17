if not CLIENT then return end

XPDRP = XPDRP or {}

local frame
local searchEntry
local listScroll
local refreshTimer = "XPDRP.ScoreboardRefresh"

local UI = {
    Bg = Color(10, 14, 22, 210),
    Panel = Color(12, 17, 27, 236),
    Border = Color(255, 255, 255, 12),
    Accent = Color(82, 162, 255),
    AccentSoft = Color(82, 162, 255, 58),
    Text = Color(230, 236, 245),
    TextDim = Color(166, 182, 205),
    Money = Color(112, 214, 136)
}

local function createPlayerRow(parent, ply)
    local row = vgui.Create("DButton", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 6)
    row:SetTall(48)
    row:SetText("")

    local avatar = vgui.Create("AvatarImage", row)
    avatar:SetSize(30, 30)
    avatar:SetPos(8, 9)
    avatar:SetPlayer(ply, 64)

    row.Paint = function(self, w, h)
        self.Hov = Lerp(FrameTime() * 16, self.Hov or 0, self:IsHovered() and 1 or 0)

        local bg = Color(255, 255, 255, 3 + self.Hov * 8)
        draw.RoundedBox(0, 0, 0, w, h, bg)
        surface.SetDrawColor(255, 255, 255, 13)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local nick = IsValid(ply) and ply:Nick() or "Отключился"
        local job = IsValid(ply) and (team.GetName(ply:Team()) or "Неизвестно") or "Неизвестно"
        local money = IsValid(ply) and (ply.getDarkRPVar and XPDRP.FormatMoney(ply:getDarkRPVar("money") or 0) or "-") or "-"
        local ping = IsValid(ply) and tostring(ply:Ping()) or "-"

        draw.SimpleText(nick, "xpgui_medium", 46, 15, UI.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(job, "xpgui_tiny", 46, 34, UI.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(money, "xpgui_medium", w - 90, 15, UI.Money, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(ping .. " мс", "xpgui_tiny", w - 10, 34, UI.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    row.DoClick = function()
        if not IsValid(ply) then return end

        local menu = XPGUI.Menu()
        menu:AddOption("Скопировать SteamID", function() SetClipboardText(ply:SteamID()) end)
        menu:AddOption("Открыть профиль", function() ply:ShowProfile() end)
        menu:AddOption(ply:IsMuted() and "Размутить" or "Замутить", function()
            ply:SetMuted(not ply:IsMuted())
        end)
        menu:Open()
    end
end

local function createGroupTitle(parent, text)
    local title = vgui.Create("DPanel", parent)
    title:Dock(TOP)
    title:DockMargin(0, 10, 0, 6)
    title:SetTall(22)
    title.Paint = function(_, w, h)
        draw.SimpleText(text, "xpgui_tiny", 0, h * 0.5, UI.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(255, 255, 255, 10)
        surface.DrawLine(0, h - 1, w, h - 1)
    end
end

local function rebuildList()
    if not IsValid(listScroll) then return end

    listScroll:Clear()

    local q = ""
    if IsValid(searchEntry) then
        q = string.lower(string.Trim(searchEntry:GetValue() or ""))
    end

    local grouped = {}
    for _, ply in ipairs(player.GetAll()) do
        local nick = string.lower(ply:Nick())
        local sid = string.lower(ply:SteamID())
        if q == "" or string.find(nick, q, 1, true) or string.find(sid, q, 1, true) then
            local teamID = ply:Team()
            grouped[teamID] = grouped[teamID] or {}
            grouped[teamID][#grouped[teamID] + 1] = ply
        end
    end

    local teams = {}
    for teamID in pairs(grouped) do
        teams[#teams + 1] = teamID
    end

    table.sort(teams, function(a, b)
        return string.lower(team.GetName(a) or "") < string.lower(team.GetName(b) or "")
    end)

    for _, teamID in ipairs(teams) do
        local players = grouped[teamID]
        table.sort(players, function(a, b) return a:Nick() < b:Nick() end)

        createGroupTitle(listScroll, (team.GetName(teamID) or "Неизвестно") .. "  [" .. tostring(#players) .. "]")

        for _, ply in ipairs(players) do
            createPlayerRow(listScroll, ply)
        end
    end
end

local function openBoard()
    if IsValid(frame) then frame:Remove() end

    frame = vgui.Create("XPFrame")
    frame:SetTitle("Таблица игроков")
    frame:SetSize(ScrW() * 0.66, ScrH() * 0.82)
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

    local top = vgui.Create("DPanel", root)
    top:Dock(TOP)
    top:SetTall(40)
    top.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, UI.Panel)
        draw.RoundedBox(0, 0, 0, w, 2, UI.AccentSoft)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    searchEntry = vgui.Create("XPTextEntry", top)
    searchEntry:Dock(FILL)
    searchEntry:DockMargin(8, 4, 8, 4)
    searchEntry:SetPlaceholderText("Поиск по нику или SteamID")
    searchEntry.OnValueChange = rebuildList

    listScroll = vgui.Create("XPScrollPanel", root)
    listScroll:Dock(FILL)
    listScroll:DockMargin(8, 8, 8, 8)

    rebuildList()

    timer.Create(refreshTimer, XPDRP.Config.TabRefreshInterval or 1, 0, function()
        if not IsValid(frame) then
            timer.Remove(refreshTimer)
            return
        end
        rebuildList()
    end)
end

local function closeBoard()
    timer.Remove(refreshTimer)
    if IsValid(frame) then frame:Remove() end
end

hook.Add("ScoreboardShow", "XPDRP.ScoreboardShow", function()
    openBoard()
    return false
end)

hook.Add("ScoreboardHide", "XPDRP.ScoreboardHide", function()
    closeBoard()
    return false
end)
