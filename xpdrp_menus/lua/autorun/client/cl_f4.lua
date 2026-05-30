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

local Theme = XPDRP.UI
if Theme and Theme.Colors then
    UI.Bg = Theme.Colors.Bg or UI.Bg
    UI.Panel = Theme.Colors.Surface or UI.Panel
    UI.Border = Theme.Colors.Border or UI.Border
    UI.Accent = Theme.Colors.Accent or UI.Accent
    UI.TextDim = Theme.Colors.Dim or UI.TextDim
    UI.Money = Theme.Colors.Money or UI.Money
end

local function rarityInfo(id)
    if Theme and Theme.GetRarityInfo then
        return Theme.GetRarityInfo(id)
    end
    return { Color = UI.Accent, Label = "Обычный" }
end

local function setModelSafe(panel, modelPath)
    if not IsValid(panel) then return end

    if XPDRP.GetModelPath then
        panel:SetModel(XPDRP.GetModelPath(modelPath))
    else
        panel:SetModel(modelPath or "models/error.mdl")
    end

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

local function safeText(v)
    if XPDRP.SafeText then return XPDRP.SafeText(v) end
    if XPDRP.Inv and XPDRP.Inv.SafeText then return XPDRP.Inv.SafeText(v) end
    return tostring(v or "")
end

local function formatMoney(v)
    if XPDRP.FormatMoney then return XPDRP.FormatMoney(v or 0) end
    if XPDRP.Inv and XPDRP.Inv.FormatMoney then return XPDRP.Inv.FormatMoney(v or 0) end
    return tostring(v or 0)
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
        return string.lower(safeText(getter(a))) < string.lower(safeText(getter(b)))
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

    local modelPanel = vgui.Create("DModelPanel", rightInner)
    modelPanel:Dock(TOP)
    modelPanel:SetTall(248)
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
    local function selectedGetter() return selected end

    local function refill(query)
        query = string.lower(string.Trim(query or ""))
        listScroll:Clear()

        local grouped = {}
        for _, item in ipairs(cfg.getItems() or {}) do
            local n = string.lower(safeText(cfg.getTitle(item)))
            if query == "" or string.find(n, query, 1, true) then
                local g = safeText(cfg.getGroup and cfg.getGroup(item) or "Раздел")
                grouped[g] = grouped[g] or {}
                grouped[g][#grouped[g] + 1] = item
            end
        end

        local groups = {}
        for g in pairs(grouped) do groups[#groups + 1] = g end
        table.sort(groups, function(a, b) return string.lower(a) < string.lower(b) end)

        for _, g in ipairs(groups) do
            createGroupLabel(listScroll, g)
            for _, item in ipairs(grouped[g]) do
                createListItem(listScroll, item, selectedGetter, cfg.getTitle(item), cfg.getSubtitle(item), cfg.getValue(item), function()
                    selected = item
                    title:SetText(cfg.getTitle(item))
                    subtitle:SetText(cfg.getSubtitle(item))
                    desc:SetText(cfg.getDescription(item))
                    action:SetEnabled(true)
                    setModelSafe(modelPanel, cfg.getModel(item))
                end)
            end
        end
    end

    action.DoClick = function()
        if not selected then return end
        cfg.onUse(selected)
        refill(search:GetValue())
    end

    search.OnValueChange = function(self)
        refill(self:GetValue())
    end

    refill("")
    return root
end

local function invSend(payload)
    payload.txid = payload.txid or ((XPDRP.Inv and XPDRP.Inv.GenerateTx and XPDRP.Inv.GenerateTx(payload.action)) or tostring(os.time()))
    net.Start("XPDRP.Inv.Action")
    net.WriteTable(payload)
    net.SendToServer()
end

local function invRequestSync()
    net.Start("XPDRP.Inv.RequestSync")
    net.SendToServer()
end

if XPDRP.Inv then
    net.Receive("XPDRP.Inv.Sync", function()
        XPDRP.Inv.State = net.ReadTable() or {}
        XPDRP.Inv.StateVersion = (XPDRP.Inv.StateVersion or 0) + 1
    end)
end

local function getInvRows()
    local out = {}
    local state = (XPDRP.Inv and XPDRP.Inv.State) or {}
    local items = state.items or {}
    for _, slot in ipairs(state.slots or {}) do
        local item = items[slot.id]
        if item then
            out[#out + 1] = {
                id = slot.id,
                name = item.name,
                category = item.category,
                model = item.model,
                qty = slot.qty,
                rarity = item.rarity or "common",
                desc = item.description or ""
            }
        end
    end
    sortByName(out, function(it) return it.name end)
    return out
end

local function buildInventory(sheet)
    invRequestSync()

    local root = vgui.Create("EditablePanel", sheet)
    root.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local sub = vgui.Create("XPPropertySheet", root)
    sub:Dock(FILL)
    sub:DockMargin(6, 6, 6, 6)

    local bag = vgui.Create("EditablePanel", sub)
    bag.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local wrap = vgui.Create("EditablePanel", bag)
    wrap:Dock(FILL)
    wrap:DockMargin(10, 10, 10, 10)

    local topBar = vgui.Create("EditablePanel", wrap)
    topBar:Dock(TOP)
    topBar:SetTall(46)
    topBar.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(7, 13, 21, 210))
        draw.RoundedBox(8, 0, 0, w, 3, Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 80))
        surface.SetDrawColor(255, 255, 255, 12)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local search = vgui.Create("XPTextEntry", topBar)
    search:Dock(LEFT)
    search:DockMargin(8, 6, 0, 6)
    search:SetWide(360)
    search:SetPlaceholderText("Поиск по сумке")

    local rarityFilter = vgui.Create("DComboBox", topBar)
    rarityFilter:Dock(LEFT)
    rarityFilter:DockMargin(8, 6, 0, 6)
    rarityFilter:SetWide(170)
    rarityFilter:SetValue("Редкость: Все")
    rarityFilter:AddChoice("Редкость: Все", "all")
    rarityFilter:AddChoice("Обычный", "common")
    rarityFilter:AddChoice("Необычный", "uncommon")
    rarityFilter:AddChoice("Редкий", "rare")
    rarityFilter:AddChoice("Эпический", "epic")
    rarityFilter:AddChoice("Легендарный", "legendary")

    local sortMode = vgui.Create("DComboBox", topBar)
    sortMode:Dock(LEFT)
    sortMode:DockMargin(8, 6, 0, 6)
    sortMode:SetWide(180)
    sortMode:SetValue("Сорт: Название")
    sortMode:AddChoice("Сорт: Название", "name")
    sortMode:AddChoice("Сорт: Количество", "qty")
    sortMode:AddChoice("Сорт: Редкость", "rarity")

    local hint = vgui.Create("DLabel", topBar)
    hint:Dock(FILL)
    hint:DockMargin(12, 0, 10, 0)
    hint:SetFont("xpgui_tiny")
    hint:SetTextColor(Color(170, 188, 210))
    hint:SetText("Drag & Drop: перетаскивай кубы, чтобы менять порядок | ЛКМ: выбрать")

    local left = vgui.Create("DPanel", wrap)
    left:Dock(LEFT)
    left:SetWide(780)
    left:DockMargin(0, 10, 10, 0)
    left.Paint = function(_, w, h)
        if Theme and Theme.DrawGlassGrid then
            Theme.DrawGlassGrid(w, h, 58, 218)
        else
            draw.RoundedBox(10, 0, 0, w, h, UI.Panel)
        end
        draw.RoundedBox(10, 0, 0, w, 3, Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 70))
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local gridScroll = vgui.Create("XPScrollPanel", left)
    gridScroll:Dock(FILL)
    gridScroll:DockMargin(10, 10, 10, 10)

    local grid = vgui.Create("DIconLayout", gridScroll)
    grid:Dock(TOP)
    grid:SetSpaceX(8)
    grid:SetSpaceY(8)

    local right = vgui.Create("DPanel", wrap)
    right:Dock(FILL)
    right:DockMargin(0, 10, 0, 0)
    right.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Panel)
        draw.RoundedBox(10, 0, 0, w, 4, Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 85))
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local rightInner = vgui.Create("EditablePanel", right)
    rightInner:Dock(FILL)

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
    subtitle:SetText("Выбери куб в сетке")

    local descWrap = vgui.Create("XPScrollPanel", rightInner)
    descWrap:Dock(FILL)
    descWrap:DockMargin(12, 0, 12, 8)

    local desc = vgui.Create("DLabel", descWrap)
    desc:Dock(TOP)
    desc:DockMargin(0, 0, 0, 0)
    desc:SetFont("xpgui_tiny")
    desc:SetWrap(true)
    desc:SetAutoStretchVertical(true)
    desc:SetTextColor(Color(160, 174, 192))
    desc:SetText("")

    local controls = vgui.Create("DPanel", rightInner)
    controls:Dock(BOTTOM)
    controls:SetTall(130)
    controls:DockMargin(0, 0, 0, 0)
    controls.Paint = nil

    local amountSlider = vgui.Create("DNumSlider", controls)
    amountSlider:Dock(TOP)
    amountSlider:DockMargin(12, 2, 12, 8)
    amountSlider:SetTall(32)
    amountSlider:SetText("Количество")
    amountSlider:SetMin(1)
    amountSlider:SetMax(1)
    amountSlider:SetDecimals(0)
    amountSlider:SetValue(1)

    local dropAction = createPrimaryAction(controls, "Выбросить")
    local useAction = createPrimaryAction(controls, "Использовать")

    local selected
    local seenStateVersion = -1
    local visualRows = {}
    local selectedRarity = "all"
    local selectedSort = "name"

    local rarityOrder = {
        common = 1,
        uncommon = 2,
        rare = 3,
        epic = 4,
        legendary = 5
    }

    local function applySelected(item)
        selected = item
        if not item then
            title:SetText("Ничего не выбрано")
            subtitle:SetText("Выбери куб в сетке")
            desc:SetText("")
            useAction:SetEnabled(false)
            dropAction:SetEnabled(false)
            amountSlider:SetMin(1)
            amountSlider:SetMax(1)
            amountSlider:SetValue(1)
            return
        end

        title:SetText(safeText(item.name))
        subtitle:SetText("ID: " .. safeText(item.id) .. " | x" .. tostring(item.qty))
        desc:SetText(safeText(item.desc or ""))
        useAction:SetEnabled(true)
        dropAction:SetEnabled((tonumber(item.qty) or 0) > 0)
        amountSlider:SetMin(1)
        amountSlider:SetMax(math.max(1, tonumber(item.qty) or 1))
        amountSlider:SetValue(1)
        setModelSafe(modelPanel, item.model)
    end

    local function drawGrid()
        grid:Clear()

        local state = (XPDRP.Inv and XPDRP.Inv.State) or {}
        local maxSlots = math.max(24, tonumber(state.maxSlots) or 48)
        local drawCount = math.max(#visualRows, maxSlots)

        for idx = 1, drawCount do
            local row = visualRows[idx]
            local cube = grid:Add("DButton")
            cube:SetSize(110, 118)
            cube:SetText("")
            cube.Item = row
            cube.OrderIndex = idx

            local icon
            if row then
                icon = vgui.Create("SpawnIcon", cube)
                icon:Dock(FILL)
                icon:DockMargin(8, 8, 8, 28)
                icon:SetModel(row.model or "models/error.mdl")
                icon:SetMouseInputEnabled(false)
            end

            cube:Droppable("XPDRP_INV_CUBE")
            cube:Receiver("XPDRP_INV_CUBE", function(self, panels, dropped)
                if not dropped then return end
                local src = panels and panels[1]
                if not IsValid(src) or src == self then return end
                local from = tonumber(src.OrderIndex or 0)
                local to = tonumber(self.OrderIndex or 0)
                if from <= 0 or to <= 0 or from == to then return end
                if not visualRows[from] or not visualRows[to] then return end
                visualRows[from], visualRows[to] = visualRows[to], visualRows[from]
                drawGrid()
            end)

            cube.DoClick = function()
                if not row then return end
                applySelected(row)
            end

            cube.Paint = function(self, w, h)
                self.Hov = Lerp(FrameTime() * 14, self.Hov or 0, self:IsHovered() and 1 or 0)
                if not row then
                    draw.RoundedBox(8, 0, 0, w, h, Color(8, 14, 22, 145))
                    surface.SetDrawColor(255, 255, 255, 10)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    return
                end

                local isSel = selected == row
                local sel = isSel and 1 or 0
                local rare = rarityInfo(row.rarity)
                local rc = rare.Color or UI.Accent
                local bg = Color(11 + sel * 10, 18 + sel * 14, 28 + sel * 18, 228)

                draw.RoundedBox(8, 0, 0, w, h, bg)
                if Theme and Theme.DrawRarityGradient then
                    Theme.DrawRarityGradient(0, 0, w, math.floor(h * 0.56), row.rarity, 105 + 45 * self.Hov)
                end
                draw.RoundedBox(8, 0, 0, w, 3, Color(rc.r, rc.g, rc.b, 70 + 120 * math.max(sel, self.Hov * 0.65)))
                draw.RoundedBox(0, 0, h - 24, w, 24, Color(6, 10, 16, 230))
                surface.SetDrawColor(255, 255, 255, isSel and 72 or (16 + 24 * self.Hov))
                surface.DrawOutlinedRect(0, 0, w, h, 1)

                surface.SetDrawColor(rc.r, rc.g, rc.b, 35 + 45 * self.Hov)
                surface.DrawRect(0, 0, 10, h)

                local label = utf8 and utf8.sub and utf8.sub(safeText(row.name), 1, 12) or string.sub(safeText(row.name), 1, 12)
                if #safeText(row.name) > 12 then
                    label = label .. ".."
                end
                draw.SimpleText(label, "xpgui_tiny", 8, h - 12, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("x" .. tostring(row.qty), "xpgui_medium", w - 8, h - 12, UI.Money, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                local chipW = 54
                draw.RoundedBox(4, w - chipW - 6, 6, chipW, 15, Color(8, 14, 22, 210))
                draw.SimpleText(rare.Label, "xpgui_tiny", w - 10, 13, Color(rc.r, rc.g, rc.b, 235), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
        grid:InvalidateLayout(true)
    end

    local function rebuildRows(keepId)
        local q = string.lower(string.Trim(search:GetValue() or ""))
        local rows = getInvRows()

        visualRows = {}
        for _, row in ipairs(rows) do
            local n = string.lower(safeText(row.name))
            local c = string.lower(safeText(row.category))
            local rarityOk = selectedRarity == "all" or tostring(row.rarity or "common") == selectedRarity
            if rarityOk and (q == "" or string.find(n, q, 1, true) or string.find(c, q, 1, true)) then
                visualRows[#visualRows + 1] = row
            end
        end

        if selectedSort == "qty" then
            table.sort(visualRows, function(a, b)
                if a.qty == b.qty then return safeText(a.name) < safeText(b.name) end
                return (tonumber(a.qty) or 0) > (tonumber(b.qty) or 0)
            end)
        elseif selectedSort == "rarity" then
            table.sort(visualRows, function(a, b)
                local ar = rarityOrder[a.rarity or "common"] or 0
                local br = rarityOrder[b.rarity or "common"] or 0
                if ar == br then return safeText(a.name) < safeText(b.name) end
                return ar > br
            end)
        end

        drawGrid()

        local found
        if keepId then
            for _, row in ipairs(visualRows) do
                if row.id == keepId then
                    found = row
                    break
                end
            end
        end
        applySelected(found)
    end

    search.OnValueChange = function()
        rebuildRows(selected and selected.id or nil)
    end

    rarityFilter.OnSelect = function(_, _, _, data)
        selectedRarity = tostring(data or "all")
        rebuildRows(selected and selected.id or nil)
    end

    sortMode.OnSelect = function(_, _, _, data)
        selectedSort = tostring(data or "name")
        rebuildRows(selected and selected.id or nil)
    end

    useAction.DoClick = function()
        if not selected then return end
        invSend({ action = "use_item", itemId = selected.id })
    end

    dropAction.DoClick = function()
        if not selected then return end
        local amount = math.max(1, math.floor(amountSlider:GetValue() or 1))
        invSend({ action = "drop_item", itemId = selected.id, qty = amount })
    end

    bag.Think = function()
        local rev = (XPDRP.Inv and XPDRP.Inv.StateVersion) or 0
        if rev ~= seenStateVersion then
            seenStateVersion = rev
            rebuildRows(selected and selected.id or nil)
        end
    end

    sub:AddSheet("Сумка", bag)

    local craft = vgui.Create("EditablePanel", sub)
    craft.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local cwrap = vgui.Create("EditablePanel", craft)
    cwrap:Dock(FILL)
    cwrap:DockMargin(10, 10, 10, 10)

    local cleft = vgui.Create("DPanel", cwrap)
    cleft:Dock(LEFT)
    cleft:SetWide(520)
    cleft.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Panel)
        draw.RoundedBox(10, 0, 0, w, 3, Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 70))
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local cright = vgui.Create("DPanel", cwrap)
    cright:Dock(FILL)
    cright:DockMargin(10, 0, 0, 0)
    cright.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Panel)
        draw.RoundedBox(10, 0, 0, w, 3, Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 70))
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local csearch = vgui.Create("XPTextEntry", cleft)
    csearch:Dock(TOP)
    csearch:DockMargin(10, 10, 10, 0)
    csearch:SetTall(34)
    csearch:SetPlaceholderText("Поиск рецептов")

    local ccatBar = vgui.Create("EditablePanel", cleft)
    ccatBar:Dock(TOP)
    ccatBar:DockMargin(10, 8, 10, 0)
    ccatBar:SetTall(34)
    ccatBar.Paint = nil

    local ccatScroll = vgui.Create("XPScrollPanel", ccatBar)
    ccatScroll:Dock(FILL)

    local ccatLayout = vgui.Create("DIconLayout", ccatScroll)
    ccatLayout:Dock(TOP)
    ccatLayout:SetSpaceX(6)
    ccatLayout:SetSpaceY(0)

    local cscroll = vgui.Create("XPScrollPanel", cleft)
    cscroll:Dock(FILL)
    cscroll:DockMargin(10, 10, 10, 10)

    local cmodel = vgui.Create("DModelPanel", cright)
    cmodel:Dock(TOP)
    cmodel:SetTall(300)
    cmodel:DockMargin(10, 10, 10, 0)
    cmodel:SetMouseInputEnabled(false)

    local ctitle = vgui.Create("DLabel", cright)
    ctitle:Dock(TOP)
    ctitle:DockMargin(12, 10, 12, 2)
    ctitle:SetFont("xpgui_big")
    ctitle:SetTextColor(color_white)
    ctitle:SetText("Выбери рецепт")

    local csub = vgui.Create("DLabel", cright)
    csub:Dock(TOP)
    csub:DockMargin(12, 0, 12, 8)
    csub:SetFont("xpgui_medium")
    csub:SetTextColor(Color(173, 190, 212))
    csub:SetText("Станция: -")

    local reqWrap = vgui.Create("XPScrollPanel", cright)
    reqWrap:Dock(FILL)
    reqWrap:DockMargin(12, 0, 12, 0)

    local craftAction = createPrimaryAction(cright, "Скрафтить")
    craftAction:SetEnabled(false)

    local selectedRecipe
    local seenCraftVersion = -1
    local selectedCraftCategory = "Все"

    local function playerCounts()
        local state = (XPDRP.Inv and XPDRP.Inv.State) or {}
        local counts = {}
        for _, slot in ipairs(state.slots or {}) do
            counts[slot.id] = (counts[slot.id] or 0) + (slot.qty or 0)
        end
        return counts
    end

    local function showRecipe(recipe)
        selectedRecipe = recipe
        reqWrap:Clear()
        if not recipe then
            ctitle:SetText("Выбери рецепт")
            csub:SetText("Станция: -")
            craftAction:SetEnabled(false)
            return
        end

        ctitle:SetText(safeText(recipe.name))
        csub:SetText("Станция: " .. safeText(recipe.station))
        local map = (XPDRP.Inv and XPDRP.Inv.State and XPDRP.Inv.State.items) or {}
        local out = map[recipe.result and recipe.result.id or ""]
        setModelSafe(cmodel, out and out.model or "models/error.mdl")

        local counts = playerCounts()
        local canCraft = true
        for _, ing in ipairs(recipe.ingredients or {}) do
            local have = counts[ing.id] or 0
            local need = tonumber(ing.qty) or 0
            if have < need then canCraft = false end

            local row = vgui.Create("DPanel", reqWrap)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 6)
            row:SetTall(36)
            row.Paint = function(_, w, h)
                draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 8))
                local ok = have >= need
                draw.SimpleText(safeText(ing.id), "xpgui_tiny", 10, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(have) .. " / " .. tostring(need), "xpgui_tiny", w - 10, h * 0.5, ok and Color(112, 214, 136) or Color(235, 120, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
        craftAction:SetEnabled(canCraft)
    end

    local function refillCraft(keepId)
        cscroll:Clear()
        ccatLayout:Clear()
        local state = (XPDRP.Inv and XPDRP.Inv.State) or {}
        local recipes = toArray(state.recipes or {})
        sortByName(recipes, function(it) return it.name end)
        local q = string.lower(string.Trim(csearch:GetValue() or ""))

        local categories = { "Все" }
        local seen = { ["Все"] = true }
        for _, recipe in ipairs(recipes) do
            local cat = safeText(recipe.category or recipe.station or "Прочее")
            if not seen[cat] then
                seen[cat] = true
                categories[#categories + 1] = cat
            end
        end

        if not seen[selectedCraftCategory] then
            selectedCraftCategory = "Все"
        end

        surface.SetFont("xpgui_tiny")
        for _, cat in ipairs(categories) do
            local tw = surface.GetTextSize(cat)
            local b = ccatLayout:Add("DButton")
            b:SetSize(math.max(80, tw + 24), 28)
            b:SetText("")
            b.Paint = function(self, w, h)
                local hov = self:IsHovered()
                local active = selectedCraftCategory == cat
                draw.RoundedBox(6, 0, 0, w, h, active and Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 85) or (hov and Color(255, 255, 255, 18) or Color(255, 255, 255, 10)))
                surface.SetDrawColor(255, 255, 255, active and 38 or 16)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(cat, "xpgui_tiny", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                selectedCraftCategory = cat
                refillCraft(selectedRecipe and selectedRecipe.id or nil)
            end
        end
        ccatLayout:InvalidateLayout(true)

        local picked
        for _, recipe in ipairs(recipes) do
            local cat = safeText(recipe.category or recipe.station or "Прочее")
            local categoryOk = (selectedCraftCategory == "Все") or (cat == selectedCraftCategory)
            local searchOk = q == "" or string.find(string.lower(safeText(recipe.name)), q, 1, true)
            if categoryOk and searchOk then
                local b = vgui.Create("DButton", cscroll)
                b:Dock(TOP)
                b:DockMargin(0, 0, 0, 8)
                b:SetTall(54)
                b:SetText("")
                b.Paint = function(self, w, h)
                    self.H = Lerp(FrameTime() * 14, self.H or 0, self:IsHovered() and 1 or 0)
                    local sel = (selectedRecipe == recipe) and 1 or 0
                    draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 8 + self.H * 10 + sel * 8))
                    draw.RoundedBox(6, 0, 0, w, 3, Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 40 + self.H * 60 + sel * 60))
                    surface.SetDrawColor(255, 255, 255, 14 + self.H * 12 + sel * 12)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText(safeText(recipe.name), "xpgui_medium", 10, 17, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(cat .. " | " .. safeText(recipe.result and recipe.result.id), "xpgui_tiny", 10, 37, Color(174, 191, 214), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
                b.DoClick = function()
                    showRecipe(recipe)
                end
                if keepId and recipe.id == keepId then
                    picked = recipe
                end
            end
        end

        if picked then
            showRecipe(picked)
        else
            showRecipe(nil)
        end
    end

    csearch.OnValueChange = function()
        refillCraft(selectedRecipe and selectedRecipe.id or nil)
    end

    craftAction.DoClick = function()
        if not selectedRecipe then return end
        invSend({ action = "craft", recipeId = selectedRecipe.id })
    end

    craft.Think = function()
        local rev = (XPDRP.Inv and XPDRP.Inv.StateVersion) or 0
        if rev ~= seenCraftVersion then
            seenCraftVersion = rev
            refillCraft(selectedRecipe and selectedRecipe.id or nil)
            if selectedRecipe then
                showRecipe(selectedRecipe)
            end
        end
    end

    sub:AddSheet("Крафт", craft)

    return root
end

local function buildSkills(sheet)
    local root = vgui.Create("EditablePanel", sheet)
    root.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local wrap = vgui.Create("EditablePanel", root)
    wrap:Dock(FILL)
    wrap:DockMargin(10, 10, 10, 10)

    local top = vgui.Create("DPanel", wrap)
    top:Dock(TOP)
    top:SetTall(54)
    top.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(7, 13, 21, 220))
        draw.RoundedBox(8, 0, 0, w, 3, Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 85))
        surface.SetDrawColor(255, 255, 255, 14)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local pointsLabel = vgui.Create("DLabel", top)
    pointsLabel:Dock(LEFT)
    pointsLabel:DockMargin(12, 0, 0, 0)
    pointsLabel:SetWide(340)
    pointsLabel:SetFont("xpgui_medium")
    pointsLabel:SetTextColor(color_white)
    pointsLabel:SetText("Очки навыков: 0")

    local timerLabel = vgui.Create("DLabel", top)
    timerLabel:Dock(FILL)
    timerLabel:DockMargin(12, 0, 12, 0)
    timerLabel:SetFont("xpgui_tiny")
    timerLabel:SetTextColor(Color(174, 191, 214))
    timerLabel:SetContentAlignment(6)
    timerLabel:SetText("До следующего очка: -")

    local scroll = vgui.Create("XPScrollPanel", wrap)
    scroll:Dock(FILL)
    scroll:DockMargin(0, 10, 0, 0)

    local seenVersion = -1

    local function fmtTime(sec)
        sec = math.max(0, math.floor(tonumber(sec) or 0))
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        return string.format("%02d:%02d", h, m)
    end

    local function refill()
        local state = (XPDRP.Inv and XPDRP.Inv.State) or {}
        local skills = state.skills or {}
        local cfg = state.skillsConfig or ((XPDRP.Skills and XPDRP.Skills.Config) or {})
        local defs = cfg.Definitions or {}
        local maxGlobal = tonumber(cfg.MaxLevel) or 5
        local secPerPoint = math.max(600, tonumber(cfg.SecondsPerPoint) or 36000)

        local points = math.max(0, tonumber(state.skillPoints) or 0)
        pointsLabel:SetText("Очки навыков: " .. tostring(points))
        timerLabel:SetText("До следующего очка: " .. fmtTime(secPerPoint - (tonumber(state.playtimeSeconds) or 0)))

        scroll:Clear()

        local ordered = { "marathoner", "sadist", "parkourist" }
        local used = {}
        for _, id in ipairs(ordered) do used[id] = true end
        for id in pairs(defs) do
            if not used[id] then
                ordered[#ordered + 1] = id
            end
        end

        for _, id in ipairs(ordered) do
            local def = defs[id]
            if def then
                local lvl = math.max(0, tonumber(skills[id]) or 0)
                local maxLvl = tonumber(def.maxLevel) or maxGlobal

                local row = vgui.Create("DPanel", scroll)
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 10)
                row:SetTall(206)
                row.Paint = function(_, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, Color(12, 17, 27, 236))
                    draw.RoundedBox(8, 0, 0, w, 3, Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 70))
                    surface.SetDrawColor(255, 255, 255, 14)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)

                    draw.SimpleText(safeText(def.name), "xpgui_medium", 12, 16, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("Уровень: " .. tostring(lvl) .. "/" .. tostring(maxLvl), "xpgui_tiny", 12, 38, Color(174, 191, 214), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    if def.unlockTeam then
                        draw.SimpleText("Профессия на 5 ур.: " .. safeText(def.unlockTeam), "xpgui_tiny", 230, 38, Color(174, 191, 214), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end

                    local barX, barY, barW, barH = 12, 50, w - 170, 14
                    draw.RoundedBox(4, barX, barY, barW, barH, Color(6, 12, 20, 230))
                    local fill = maxLvl > 0 and math.Clamp(lvl / maxLvl, 0, 1) or 0
                    draw.RoundedBox(4, barX + 1, barY + 1, (barW - 2) * fill, barH - 2, Color(82, 162, 255, 170))

                    draw.SimpleText("Награды по уровням", "xpgui_tiny", 12, 76, Color(210, 222, 236), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                local rewards = vgui.Create("EditablePanel", row)
                rewards:Dock(FILL)
                rewards:DockMargin(12, 86, 160, 10)
                rewards.Paint = function(_, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, Color(6, 12, 20, 210))
                    surface.SetDrawColor(255, 255, 255, 10)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end

                local rewardsScroll = vgui.Create("XPScrollPanel", rewards)
                rewardsScroll:Dock(FILL)
                rewardsScroll:DockMargin(6, 6, 6, 6)

                for levelIdx = 1, maxLvl do
                    local line = vgui.Create("DPanel", rewardsScroll)
                    line:Dock(TOP)
                    line:DockMargin(0, 0, 0, 4)
                    line:SetTall(24)
                    line.Paint = function(_, w, h)
                        local done = levelIdx <= lvl
                        local active = levelIdx == (lvl + 1)
                        local bg = done and Color(112, 214, 136, 20) or (active and Color(82, 162, 255, 22) or Color(255, 255, 255, 6))
                        draw.RoundedBox(4, 0, 0, w, h, bg)
                        draw.SimpleText("Ур. " .. tostring(levelIdx), "xpgui_tiny", 8, h * 0.5, done and Color(112, 214, 136) or Color(174, 191, 214), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        draw.SimpleText(safeText((def.levels and def.levels[levelIdx]) or "-"), "xpgui_tiny", 60, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                end

                local up = vgui.Create("DButton", row)
                up:Dock(RIGHT)
                up:DockMargin(0, 12, 12, 12)
                up:SetWide(142)
                up:SetText("")
                up:SetEnabled(points > 0 and lvl < maxLvl)
                up.Paint = function(self, w, h)
                    self.H = Lerp(FrameTime() * 14, self.H or 0, self:IsHovered() and 1 or 0)
                    local enabled = self:IsEnabled()
                    local base = enabled and Color(UI.Accent.r, UI.Accent.g, UI.Accent.b, 90 + self.H * 80) or Color(66, 76, 94, 80)
                    draw.RoundedBox(6, 0, 0, w, h, Color(6, 12, 20, 230))
                    draw.RoundedBox(6, 1, 1, w - 2, h - 2, base)
                    surface.SetDrawColor(255, 255, 255, enabled and 24 or 12)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText("Прокачать", "xpgui_tiny", w * 0.5, h * 0.5, enabled and color_white or Color(170, 180, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                up.DoClick = function()
                    invSend({ action = "skill_upgrade", skillId = id })
                end
            end
        end
    end

    root.Think = function()
        local rev = (XPDRP.Inv and XPDRP.Inv.StateVersion) or 0
        if rev ~= seenVersion then
            seenVersion = rev
            refill()
        end
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
        getTitle = function(it) return safeText(it.name) end,
        getSubtitle = function(it) return "/" .. safeText(it.command) end,
        getValue = function(it) return formatMoney(it.salary or 0) end,
        getDescription = function(it)
            return safeText(it.description or (it.vote and "Требуется голосование") or "Описание отсутствует")
        end,
        getModel = function(it) return it.model end,
        onUse = function(it)
            if not it.command then return end
            if XPDRP.RunDarkRPCommand then XPDRP.RunDarkRPCommand(it.command) end
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
        getTitle = function(it) return safeText(it.name) end,
        getSubtitle = function(it) return "Команда: /buy " .. safeText(it.cmd) end,
        getValue = function(it) return formatMoney(it.price or 0) end,
        getDescription = function(it) return safeText(it.ent or "Покупка предмета") end,
        getModel = function(it) return it.model end,
        onUse = function(it)
            if not it.cmd then return end
            if XPDRP.RunDarkRPCommand then XPDRP.RunDarkRPCommand("buy " .. it.cmd) end
        end
    })
end

local function buildShipments(sheet)
    local shipments = {}
    for _, it in pairs(CustomShipments or {}) do
        if not it.noship then shipments[#shipments + 1] = it end
    end
    sortByName(shipments, function(it) return it.name end)

    return createCatalogTab(sheet, {
        buttonText = "Купить поставку",
        getItems = function() return shipments end,
        getGroup = function(it) return it.category or "Поставки" end,
        getTitle = function(it) return safeText(it.name) end,
        getSubtitle = function(it) return safeText(it.entity) end,
        getValue = function(it) return formatMoney(it.price or 0) end,
        getDescription = function(it)
            return "Количество: " .. safeText(it.amount) .. " | По одной: " .. (it.separate and "да" or "нет")
        end,
        getModel = function(it) return it.model end,
        onUse = function(it)
            if not it.entity then return end
            if XPDRP.RunDarkRPCommand then XPDRP.RunDarkRPCommand("buyshipment " .. it.entity) end
        end
    })
end

local function buildWeapons(sheet)
    local weapons = {}
    for _, it in pairs(CustomShipments or {}) do
        if it.separate then weapons[#weapons + 1] = it end
    end
    sortByName(weapons, function(it) return it.name end)

    return createCatalogTab(sheet, {
        buttonText = "Купить 1 шт.",
        getItems = function() return weapons end,
        getGroup = function(it) return it.category or "Оружие" end,
        getTitle = function(it) return safeText(it.name) end,
        getSubtitle = function(it) return safeText(it.entity) end,
        getValue = function(it) return formatMoney(it.pricesep or it.price or 0) end,
        getDescription = function(it) return "Цена поставки: " .. formatMoney(it.price or 0) end,
        getModel = function(it) return it.model end,
        onUse = function(it)
            if not it.entity then return end
            if XPDRP.RunDarkRPCommand then XPDRP.RunDarkRPCommand("buy " .. it.entity) end
        end
    })
end

local function openF4Menu()
    if IsValid(frame) then frame:Remove() end

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
    sheet:AddSheet("Инвентарь", buildInventory(sheet))
    sheet:AddSheet("Навыки", buildSkills(sheet))
end

hook.Add("ShowSpare2", "XPDRP.OpenF4Menu", function()
    openF4Menu()
    return true
end)

concommand.Add("xpdrp_f4", openF4Menu)