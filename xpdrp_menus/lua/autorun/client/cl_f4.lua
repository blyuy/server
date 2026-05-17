if not CLIENT then return end

XPDRP = XPDRP or {}

local frame

local UI = {
    Bg = Color(10, 14, 22, 210),
    Panel = Color(12, 17, 27, 236),
    Border = Color(255, 255, 255, 12),
    Accent = Color(82, 162, 255),
    AccentSoft = Color(82, 162, 255, 60),
    TextDim = Color(173, 190, 212),
    Money = Color(112, 214, 136)
}

local function setModelSafe(panel, modelPath)
    if not IsValid(panel) then return end

    panel:SetModel(XPDRP.GetModelPath(modelPath))

    -- Keep default DModelPanel paint path; overriding Paint can break 3D camera setup.
    panel.Paint = nil

    local function applyCamera()
        if not IsValid(panel) then return end
        local ent = panel.Entity
        if not IsValid(ent) then return end

        local mins, maxs = ent:GetModelBounds()
        if not mins or not maxs then
            mins, maxs = ent:GetRenderBounds()
        end

        local center = (mins + maxs) * 0.5
        local size = 0
        size = math.max(size, math.abs(mins.x) + math.abs(maxs.x))
        size = math.max(size, math.abs(mins.y) + math.abs(maxs.y))
        size = math.max(size, math.abs(mins.z) + math.abs(maxs.z))
        size = math.max(size, 28)

        panel:SetFOV(40)
        panel:SetLookAt(center)
        panel:SetCamPos(center + Vector(size * 1.15, size * 1.15, size * 0.3))

        panel:SetAmbientLight(Color(105, 112, 130))
        panel:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
        panel:SetDirectionalLight(BOX_FRONT, Color(220, 220, 230))
        panel:SetDirectionalLight(BOX_RIGHT, Color(170, 185, 220))
    end

    panel.LayoutEntity = function(_, entity)
        entity:SetAngles(Angle(0, RealTime() * 20 % 360, 0))
    end

    applyCamera()
    timer.Simple(0, applyCamera)
end

local function toArray(input)
    local out = {}
    for _, v in pairs(input or {}) do
        out[#out + 1] = v
    end
    return out
end

local function sortByName(tbl, getter)
    table.sort(tbl, function(a, b)
        return string.lower(XPDRP.SafeText(getter(a))) < string.lower(XPDRP.SafeText(getter(b)))
    end)
end

local function createPrimaryAction(parent, text)
    local btn = vgui.Create("DButton", parent)
    btn:Dock(BOTTOM)
    btn:SetTall(44)
    btn:DockMargin(1, 8, 1, 1)
    btn:SetText("")
    btn.Label = text
    btn:SetEnabled(false)

    btn.Paint = function(self, w, h)
        self.Hov = Lerp(FrameTime() * 14, self.Hov or 0, self:IsHovered() and 1 or 0)
        local enabled = self:IsEnabled()

        local base = enabled and Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 120 + 70 * self.Hov) or Color(66, 76, 94, 70)
        local glow = enabled and Color(145, 210, 255, 24 + 40 * self.Hov) or Color(0, 0, 0, 0)

        draw.RoundedBox(0, 0, 0, w, h, Color(9, 14, 24, 250))
        draw.RoundedBox(0, 1, 1, w - 2, h - 2, base)
        draw.RoundedBox(0, 1, 1, w - 2, h * 0.42, glow)

        surface.SetDrawColor(255, 255, 255, enabled and 34 or 14)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText(self.Label, "xpgui_medium", 16, h * 0.5, enabled and color_white or Color(176, 186, 202), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(">", "xpgui_big", w - 14, h * 0.5 - 1, enabled and Color(220, 240, 255) or Color(130, 140, 155), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    return btn
end

local function createListItem(parent, item, selectedGetter, title, subtitle, value, onClick)
    local row = vgui.Create("DButton", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 7)
    row:SetTall(56)
    row:SetText("")

    row.Paint = function(self, w, h)
        local selected = selectedGetter() == item
        self.Hov = Lerp(FrameTime() * 14, self.Hov or 0, self:IsHovered() and 1 or 0)

        local bg = selected and Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 64) or Color(255, 255, 255, 4 + self.Hov * 8)
        draw.RoundedBox(0, 0, 0, w, h, bg)

        if selected then
            surface.SetDrawColor(UI.Accent.r, UI.Accent.g, UI.Accent.b, 140)
            surface.DrawRect(0, 0, 3, h)
        end

        surface.SetDrawColor(255, 255, 255, selected and 26 or 13)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText(title, "xpgui_medium", 12, 17, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(subtitle, "xpgui_tiny", 12, 38, UI.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "xpgui_medium", w - 12, 28, UI.Money, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    row.DoClick = onClick
    return row
end

local function createGroupLabel(parent, text)
    local pnl = vgui.Create("DPanel", parent)
    pnl:Dock(TOP)
    pnl:DockMargin(0, 10, 0, 6)
    pnl:SetTall(22)
    pnl.Paint = function(_, w, h)
        draw.SimpleText(text, "xpgui_tiny", 0, h * 0.5, Color(186, 201, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(255, 255, 255, 10)
        surface.DrawLine(0, h - 1, w, h - 1)
    end
end

local function createCatalogTab(sheet, cfg)
    local root = vgui.Create("EditablePanel", sheet)
    root.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local wrap = vgui.Create("EditablePanel", root)
    wrap:Dock(FILL)
    wrap:DockMargin(10, 10, 10, 10)

    local left = vgui.Create("DPanel", wrap)
    left:Dock(LEFT)
    left:SetWide(500)
    left.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Panel)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local leftInner = vgui.Create("EditablePanel", left)
    leftInner:Dock(FILL)
    leftInner:DockMargin(10, 10, 10, 10)

    local search = vgui.Create("XPTextEntry", leftInner)
    search:Dock(TOP)
    search:SetTall(34)
    search:SetPlaceholderText("Поиск")

    local listScroll = vgui.Create("XPScrollPanel", leftInner)
    listScroll:Dock(FILL)
    listScroll:DockMargin(0, 10, 0, 0)

    local right = vgui.Create("DPanel", wrap)
    right:Dock(FILL)
    right:DockMargin(10, 0, 0, 0)
    right.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Panel)
        draw.RoundedBox(10, 0, 0, w, 4, UI.AccentSoft)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local rightInner = vgui.Create("EditablePanel", right)
    rightInner:Dock(FILL)
    rightInner:DockMargin(0, 0, 0, 0)

    local modelPanel = vgui.Create("DModelPanel", rightInner)
    modelPanel:Dock(TOP)
    modelPanel:SetTall(320)
    modelPanel:DockMargin(10, 10, 10, 0)
    modelPanel:SetMouseInputEnabled(false)

    local title = vgui.Create("DLabel", rightInner)
    title:Dock(TOP)
    title:DockMargin(12, 10, 12, 2)
    title:SetFont("xpgui_big")
    title:SetTextColor(color_white)
    title:SetText("Ничего не выбрано")

    local subtitle = vgui.Create("DLabel", rightInner)
    subtitle:Dock(TOP)
    subtitle:DockMargin(12, 0, 12, 10)
    subtitle:SetFont("xpgui_medium")
    subtitle:SetTextColor(Color(173, 190, 212))
    subtitle:SetText("Выберите элемент в списке")

    local desc = vgui.Create("DLabel", rightInner)
    desc:Dock(FILL)
    desc:DockMargin(12, 0, 12, 0)
    desc:SetFont("xpgui_tiny")
    desc:SetWrap(true)
    desc:SetAutoStretchVertical(true)
    desc:SetTextColor(Color(160, 174, 192))
    desc:SetText("")

    local action = createPrimaryAction(rightInner, cfg.buttonText)

    local selected
    local data = cfg.getItems()

    local function selectedGetter()
        return selected
    end

    local function refill(query)
        query = string.lower(string.Trim(query or ""))
        listScroll:Clear()

        local grouped = {}
        for _, item in ipairs(data) do
            local n = string.lower(XPDRP.SafeText(cfg.getTitle(item)))
            if query == "" or string.find(n, query, 1, true) then
                local g = XPDRP.SafeText(cfg.getGroup and cfg.getGroup(item) or "Раздел")
                grouped[g] = grouped[g] or {}
                grouped[g][#grouped[g] + 1] = item
            end
        end

        local groups = {}
        for g in pairs(grouped) do
            groups[#groups + 1] = g
        end
        table.sort(groups, function(a, b)
            return string.lower(a) < string.lower(b)
        end)

        for _, g in ipairs(groups) do
            createGroupLabel(listScroll, g)
            for _, item in ipairs(grouped[g]) do
                createListItem(
                    listScroll,
                    item,
                    selectedGetter,
                    cfg.getTitle(item),
                    cfg.getSubtitle(item),
                    cfg.getValue(item),
                    function()
                        selected = item
                        title:SetText(cfg.getTitle(item))
                        subtitle:SetText(cfg.getSubtitle(item))
                        desc:SetText(cfg.getDescription(item))
                        action:SetEnabled(true)
                        setModelSafe(modelPanel, cfg.getModel(item))
                    end
                )
            end
        end
    end

    action.DoClick = function()
        if not selected then return end
        cfg.onUse(selected)
    end

    search.OnValueChange = function(self)
        refill(self:GetValue())
    end

    refill("")

    if data[1] then
        selected = data[1]
        title:SetText(cfg.getTitle(selected))
        subtitle:SetText(cfg.getSubtitle(selected))
        desc:SetText(cfg.getDescription(selected))
        action:SetEnabled(true)
        setModelSafe(modelPanel, cfg.getModel(selected))
    end

    return root
end

local function buildJobs(sheet)
    local jobs = toArray(RPExtraTeams)
    sortByName(jobs, function(it) return it.name end)

    return createCatalogTab(sheet, {
        buttonText = "Устроиться",
        getItems = function() return jobs end,
        getGroup = function(it) return it.category or "Профессии" end,
        getTitle = function(it) return XPDRP.SafeText(it.name) end,
        getSubtitle = function(it) return "/" .. XPDRP.SafeText(it.command) end,
        getValue = function(it) return XPDRP.FormatMoney(it.salary or 0) end,
        getDescription = function(it)
            return XPDRP.SafeText(it.description or (it.vote and "Требуется голосование") or "Описание отсутствует")
        end,
        getModel = function(it) return it.model end,
        onUse = function(it)
            if not it.command then return end
            XPDRP.RunDarkRPCommand(it.command)
            if IsValid(frame) then frame:Close() end
        end
    })
end

local function buildEntities(sheet)
    local entities = toArray(DarkRPEntities)
    sortByName(entities, function(it) return it.name end)

    return createCatalogTab(sheet, {
        buttonText = "Купить",
        getItems = function() return entities end,
        getGroup = function(it) return it.category or "Предметы" end,
        getTitle = function(it) return XPDRP.SafeText(it.name) end,
        getSubtitle = function(it) return "Команда: /buy " .. XPDRP.SafeText(it.cmd) end,
        getValue = function(it) return XPDRP.FormatMoney(it.price or 0) end,
        getDescription = function(it) return XPDRP.SafeText(it.ent or "Покупка предмета") end,
        getModel = function(it) return it.model end,
        onUse = function(it)
            if not it.cmd then return end
            XPDRP.RunDarkRPCommand("buy " .. it.cmd)
        end
    })
end

local function buildShipments(sheet)
    local shipments = {}
    for _, it in pairs(CustomShipments or {}) do
        if not it.noship then
            shipments[#shipments + 1] = it
        end
    end
    sortByName(shipments, function(it) return it.name end)

    return createCatalogTab(sheet, {
        buttonText = "Купить поставку",
        getItems = function() return shipments end,
        getGroup = function(it) return it.category or "Поставки" end,
        getTitle = function(it) return XPDRP.SafeText(it.name) end,
        getSubtitle = function(it) return XPDRP.SafeText(it.entity) end,
        getValue = function(it) return XPDRP.FormatMoney(it.price or 0) end,
        getDescription = function(it)
            return "Количество: " .. XPDRP.SafeText(it.amount) .. " | По одной: " .. (it.separate and "да" or "нет")
        end,
        getModel = function(it) return it.model end,
        onUse = function(it)
            if not it.entity then return end
            XPDRP.RunDarkRPCommand("buyshipment " .. it.entity)
        end
    })
end

local function buildWeapons(sheet)
    local weapons = {}
    for _, it in pairs(CustomShipments or {}) do
        if it.separate then
            weapons[#weapons + 1] = it
        end
    end
    sortByName(weapons, function(it) return it.name end)

    return createCatalogTab(sheet, {
        buttonText = "Купить 1 шт.",
        getItems = function() return weapons end,
        getGroup = function(it) return it.category or "Оружие" end,
        getTitle = function(it) return XPDRP.SafeText(it.name) end,
        getSubtitle = function(it) return XPDRP.SafeText(it.entity) end,
        getValue = function(it) return XPDRP.FormatMoney(it.pricesep or it.price or 0) end,
        getDescription = function(it) return "Цена поставки: " .. XPDRP.FormatMoney(it.price or 0) end,
        getModel = function(it) return it.model end,
        onUse = function(it)
            if not it.entity then return end
            XPDRP.RunDarkRPCommand("buy " .. it.entity)
        end
    })
end

local function openF4Menu()
    if IsValid(frame) then
        frame:Remove()
    end

    frame = vgui.Create("XPFrame")
    frame:SetTitle("F4 Меню")
    frame:SetSize(ScrW() * 0.88, ScrH() * 0.9)
    frame:Center()
    frame:MakePopup()

    local sheet = vgui.Create("XPPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:DockMargin(6, 6, 6, 6)

    sheet:AddSheet("Профессии", buildJobs(sheet))
    sheet:AddSheet("Предметы", buildEntities(sheet))
    sheet:AddSheet("Поставки", buildShipments(sheet))
    sheet:AddSheet("Оружие", buildWeapons(sheet))

    if XPDRP.Inventory and XPDRP.Inventory.BuildF4Tab then
        sheet:AddSheet("Инвентарь", XPDRP.Inventory.BuildF4Tab(sheet))
    else
        local fallback = vgui.Create("DPanel", sheet)
        fallback.Paint = function(_, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(12, 17, 27, 236))
            draw.SimpleText("Инвентарь не загружен", "xpgui_big", 24, 24, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Проверьте загрузку xpdrp_script в клиенте и сервере.", "xpgui_medium", 24, 58, Color(166, 182, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        sheet:AddSheet("Инвентарь", fallback)
    end
end

hook.Add("ShowSpare2", "XPDRP.OpenF4Menu", function()
    openF4Menu()
    return true
end)

concommand.Add("xpdrp_f4", openF4Menu)
