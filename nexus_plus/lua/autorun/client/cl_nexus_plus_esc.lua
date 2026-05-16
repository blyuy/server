if SERVER then return end

local function cfgValue(key, fallback)
    local cfg = NEXUS_PLUS_CONFIG and NEXUS_PLUS_CONFIG.EscMenu
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

surface.CreateFont("NexusEscBrand", {
    font = "Roboto",
    size = 30,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusEscText", {
    font = "Roboto",
    size = 18,
    weight = 600,
    antialias = true
})

surface.CreateFont("NexusEscSub", {
    font = "Roboto",
    size = 15,
    weight = 500,
    antialias = true
})

local escFrame

local ACTIONS = {
    resume = function()
        if IsValid(escFrame) then escFrame:Remove() end
    end,
    f4 = function()
        RunConsoleCommand("nexus_plus_f4")
        if IsValid(escFrame) then escFrame:Remove() end
    end,
    door = function()
        RunConsoleCommand("nexus_plus_door_menu")
        if IsValid(escFrame) then escFrame:Remove() end
    end,
    open_options = function()
        gui.ActivateGameUI()
        RunConsoleCommand("gamemenucommand", "openoptionsdialog")
        if IsValid(escFrame) then escFrame:Remove() end
    end,
    disconnect = function()
        RunConsoleCommand("disconnect")
    end
}

local function closeEscMenu()
    if IsValid(escFrame) then
        escFrame:Remove()
    end
    escFrame = nil
end

local function openEscMenu()
    if not cfgValue("enabled", true) then return end
    if IsValid(escFrame) then
        closeEscMenu()
        return
    end

    local buttons = cfgValue("buttons", {})
    local width = cfgValue("width", 560)
    local headerH = cfgValue("headerHeight", 78)
    local itemH = cfgValue("itemHeight", 46)
    local height = headerH + 20 + (#buttons * (itemH + 8)) + 14

    escFrame = vgui.Create("DFrame")
    escFrame:SetSize(width, height)
    escFrame:Center()
    escFrame:SetTitle("")
    escFrame:ShowCloseButton(false)
    escFrame:SetDraggable(false)
    escFrame:MakePopup()
    escFrame.anim = 0

    escFrame.Paint = function(self, w, h)
        self.anim = Lerp(FrameTime() * cfgValue("openAnimSpeed", 12), self.anim, 1)
        local alpha = math.floor(Lerp(self.anim, 0, 238))
        local slide = math.floor(Lerp(self.anim, 12, 0))

        draw.RoundedBox(12, 0, slide, w, h - slide, Color(16, 18, 26, alpha))
        draw.SimpleText(generalValue("brand", "NEXUS DARKRP"), "NexusEscBrand", 16, 24 + slide, Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Пауза | ESC меню", "NexusEscSub", 16, 54 + slide, Color(168, 178, 206, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", escFrame)
    closeBtn:SetPos(width - 42, 10)
    closeBtn:SetSize(30, 24)
    closeBtn:SetText("X")
    closeBtn:SetFont("NexusEscText")
    closeBtn:SetTextColor(color_white)
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(58, 66, 92, self:IsHovered() and 240 or 210))
    end
    closeBtn.DoClick = function()
        closeEscMenu()
    end

    local list = vgui.Create("DPanel", escFrame)
    list:SetPos(12, headerH)
    list:SetSize(width - 24, height - headerH - 12)
    list.Paint = nil

    for _, item in ipairs(buttons) do
        local btn = vgui.Create("DButton", list)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 8)
        btn:SetTall(itemH)
        btn:SetText("")
        btn.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(37, 42, 60, self:IsHovered() and 240 or 214))
            draw.SimpleText(item.label or "Кнопка", "NexusEscText", 14, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            local action = ACTIONS[item.action or ""]
            if action then action() end
        end
    end
end

hook.Add("OnPauseMenuShow", "NexusPlusOpenEscMenu", function()
    if _G.NEXUS_PLUS_CHAT_IS_OPEN then
        if isfunction(_G.NEXUS_PLUS_CHAT_CLOSE) then
            _G.NEXUS_PLUS_CHAT_CLOSE()
        end
        return false
    end

    if not cfgValue("enabled", true) then return end
    openEscMenu()
    return false
end)

hook.Add("Think", "NexusPlusEscCloseOnUnfocus", function()
    if not IsValid(escFrame) then return end
    if gui.IsGameUIVisible() then
        closeEscMenu()
    end
end)