if SERVER then return end

local function cfgValue(group, key, fallback)
    local cfg = NEXUS_PLUS_CONFIG and NEXUS_PLUS_CONFIG[group]
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

surface.CreateFont("NexusPlusCBrand", {
    font = "Roboto",
    size = 28,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusPlusCText", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true
})

local cFrame

local function runCommand(cmd)
    local text = tostring(cmd or "")
    if text == "" then return end

    local parts = string.Explode(" ", text)
    local root = table.remove(parts, 1)
    if not root then return end

    RunConsoleCommand(root, unpack(parts))
end

local function openCMenu()
    if IsValid(cFrame) then return end

    local width = cfgValue("CMenu", "width", 390)
    local height = 90 + (#cfgValue("CMenu", "commands", {}) * (cfgValue("CMenu", "itemHeight", 42) + 8))
    local x = cfgValue("CMenu", "anchorRight", true)
        and (ScrW() - width - cfgValue("CMenu", "rightOffset", 24))
        or cfgValue("CMenu", "leftOffset", 24)
    local y = cfgValue("CMenu", "topOffset", 210)

    cFrame = vgui.Create("DFrame")
    cFrame:SetSize(width, height)
    cFrame:SetPos(math.max(0, x), math.max(0, y))
    cFrame:SetTitle("")
    cFrame:ShowCloseButton(false)
    cFrame:SetDraggable(false)
    cFrame:MakePopup()
    cFrame.anim = 0

    cFrame.Paint = function(self, w, h)
        local speed = cfgValue("CMenu", "openAnimSpeed", 12)
        self.anim = Lerp(FrameTime() * speed, self.anim, 1)
        local alpha = math.floor(Lerp(self.anim, 0, 238))
        draw.RoundedBox(12, 0, 0, w, h, Color(16, 18, 26, alpha))
        draw.SimpleText(cfgValue("General", "brand", "NEXUS DARKRP") .. " - CMenu", "NexusPlusCBrand", 16, 30, Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local list = vgui.Create("DPanel", cFrame)
    list:Dock(FILL)
    list:DockMargin(10, 56, 10, 10)
    list.Paint = nil

    for _, item in ipairs(cfgValue("CMenu", "commands", {})) do
        local btn = vgui.Create("DButton", list)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 8)
        btn:SetTall(cfgValue("CMenu", "itemHeight", 42))
        btn:SetText("")
        btn.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(37, 42, 60, self:IsHovered() and 240 or 214))
            draw.SimpleText(item.label or "Команда", "NexusPlusCText", 14, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            runCommand(item.cmd)
        end
    end
end

local function closeCMenu()
    if IsValid(cFrame) then
        cFrame:Remove()
    end
    cFrame = nil
end

hook.Add("OnContextMenuOpen", "NexusPlusContextOpen", function()
    openCMenu()
    return false
end)

hook.Add("OnContextMenuClose", "NexusPlusContextClose", function()
    closeCMenu()
end)