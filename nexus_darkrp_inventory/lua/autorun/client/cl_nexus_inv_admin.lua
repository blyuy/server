if SERVER then return end

surface.CreateFont("NexusInvAdminTitle", {
    font = "Roboto",
    size = 24,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusInvAdminText", {
    font = "Roboto",
    size = 16,
    weight = 500,
    antialias = true
})

local adminFrame
local payload = {
    localItems = {},
    vendorProfiles = {},
    customItems = {},
    itemIds = {}
}

local function sendAction(action, data)
    net.Start("nexus_inv_admin_action")
    net.WriteString(action)
    net.WriteString(util.TableToJSON(data or {}, false) or "{}")
    net.SendToServer()
end

local function makeButton(parent, text, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetText(text)
    btn:SetFont("NexusInvAdminText")
    btn:SetTextColor(color_white)
    btn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(69, 98, 160, self:IsHovered() and 245 or 220))
    end
    btn.DoClick = onClick
    return btn
end

local function baseLocalIds()
    local out = {}
    for _, row in ipairs((NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.LocalItems) or {}) do
        if isstring(row.id) and row.id ~= "" then
            out[#out + 1] = row.id
        end
    end
    table.sort(out, function(a, b) return a < b end)
    return out
end

local function rebuildLocalItemsTab(panel)
    panel:Clear()

    local info = vgui.Create("DLabel", panel)
    info:SetPos(10, 10)
    info:SetSize(panel:GetWide() - 20, 22)
    info:SetText("Здесь редактируются только базовые локальные предметы (они защищены от удаления в инвентаре).")
    info:SetFont("NexusInvAdminText")
    info:SetTextColor(Color(205, 214, 235))

    local itemBox = vgui.Create("DComboBox", panel)
    itemBox:SetPos(10, 40)
    itemBox:SetSize(260, 28)
    itemBox:SetValue("Выберите базовый локальный предмет")
    for _, itemId in ipairs(baseLocalIds()) do
        itemBox:AddChoice(itemId)
    end

    local amount = vgui.Create("DTextEntry", panel)
    amount:SetPos(276, 40)
    amount:SetSize(80, 28)
    amount:SetValue("1")

    local addBtn = makeButton(panel, "Обновить amount", function()
        local itemId = itemBox:GetValue()
        if not itemId or itemId == "" or itemId == "Выберите базовый локальный предмет" then return end
        sendAction("local_add", {
            itemId = itemId,
            amount = tonumber(amount:GetValue()) or 1
        })
    end)
    addBtn:SetPos(362, 40)
    addBtn:SetSize(170, 28)

    local list = vgui.Create("DListView", panel)
    list:SetPos(10, 78)
    list:SetSize(panel:GetWide() - 20, panel:GetTall() - 88)
    list:AddColumn("Item ID")
    list:AddColumn("Amount")

    for _, row in ipairs(payload.localItems or {}) do
        list:AddLine(row.id or "", tostring(row.amount or 1))
    end

    list.OnRowRightClick = function(_, _, line)
        local id = line:GetColumnText(1)
        local isBase = false
        for _, baseId in ipairs(baseLocalIds()) do
            if baseId == id then
                isBase = true
                break
            end
        end

        local menu = DermaMenu()
        if isBase then
            local opt = menu:AddOption("Удаление запрещено для базовых локальных", function() end)
            opt:SetEnabled(false)
        else
            menu:AddOption("Удалить", function()
                sendAction("local_remove", { itemId = id })
            end)
        end
        menu:Open()
    end

    panel.OnSizeChanged = function(self, w, h)
        info:SetSize(w - 20, 22)
        list:SetSize(w - 20, h - 88)
    end
end

local function rebuildGiveTab(panel)
    panel:Clear()

    local selectedTargetSid64 = LocalPlayer():SteamID64()

    local targetBox = vgui.Create("DComboBox", panel)
    targetBox:SetPos(10, 10)
    targetBox:SetSize(380, 28)
    targetBox:SetValue("Цель: я")
    targetBox:AddChoice("Я", LocalPlayer():SteamID64())

    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            targetBox:AddChoice(p:Nick() .. " (" .. p:SteamID64() .. ")", p:SteamID64())
        end
    end

    targetBox.OnSelect = function(_, _, _, data)
        selectedTargetSid64 = tostring(data or LocalPlayer():SteamID64())
    end

    local itemBox = vgui.Create("DComboBox", panel)
    itemBox:SetPos(10, 44)
    itemBox:SetSize(300, 28)
    itemBox:SetValue("Выберите предмет")
    for _, itemId in ipairs(payload.itemIds or {}) do
        itemBox:AddChoice(itemId)
    end

    local amount = vgui.Create("DTextEntry", panel)
    amount:SetPos(316, 44)
    amount:SetSize(80, 28)
    amount:SetValue("1")

    local giveBtn = makeButton(panel, "Выдать предмет", function()
        local itemId = itemBox:GetValue()
        if not itemId or itemId == "" or itemId == "Выберите предмет" then return end

        local amt = math.max(1, math.floor(tonumber(amount:GetValue()) or 1))
        RunConsoleCommand("nexus_inv_admin_give", tostring(selectedTargetSid64), tostring(itemId), tostring(amt))
    end)
    giveBtn:SetPos(402, 44)
    giveBtn:SetSize(190, 28)

    local hint = vgui.Create("DLabel", panel)
    hint:SetPos(10, 80)
    hint:SetSize(panel:GetWide() - 20, 22)
    hint:SetText("Выдача не делает предмет локальным. Его можно удалить/выбросить по обычным правилам предмета.")
    hint:SetFont("NexusInvAdminText")
    hint:SetTextColor(Color(200, 212, 236))

    panel.OnSizeChanged = function(self, w)
        hint:SetSize(w - 20, 22)
    end
end

local function rebuildVendorsTab(panel)
    panel:Clear()

    local profiles = vgui.Create("DListView", panel)
    profiles:SetPos(10, 10)
    profiles:SetSize(300, panel:GetTall() - 20)
    profiles:AddColumn("Profile ID")
    profiles:AddColumn("Name")

    local selected = nil

    local function refreshProfiles()
        profiles:Clear()
        local rows = {}
        for id, prof in pairs(payload.vendorProfiles or {}) do
            rows[#rows + 1] = { id = id, name = (prof and prof.name) or "Торговец" }
        end
        table.sort(rows, function(a, b) return a.id < b.id end)
        for _, row in ipairs(rows) do
            profiles:AddLine(row.id, row.name)
        end
    end

    local right = vgui.Create("DPanel", panel)
    right:SetPos(320, 10)
    right:SetSize(panel:GetWide() - 330, panel:GetTall() - 20)
    right.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(23, 27, 39, 235))
    end

    local idEntry = vgui.Create("DTextEntry", right)
    idEntry:SetPos(10, 10)
    idEntry:SetSize(140, 26)
    idEntry:SetPlaceholderText("profile_id")

    local nameEntry = vgui.Create("DTextEntry", right)
    nameEntry:SetPos(156, 10)
    nameEntry:SetSize(180, 26)
    nameEntry:SetPlaceholderText("Имя")

    local modelEntry = vgui.Create("DTextEntry", right)
    modelEntry:SetPos(10, 40)
    modelEntry:SetSize(326, 26)
    modelEntry:SetPlaceholderText("Модель")

    local distanceEntry = vgui.Create("DTextEntry", right)
    distanceEntry:SetPos(10, 70)
    distanceEntry:SetSize(80, 26)
    distanceEntry:SetValue("140")

    local saveProfile = makeButton(right, "Сохранить профиль", function()
        local pid = string.Trim(idEntry:GetValue() or "")
        if pid == "" then return end
        sendAction("vendor_upsert", {
            profileId = pid,
            name = string.Trim(nameEntry:GetValue() or ""),
            model = string.Trim(modelEntry:GetValue() or ""),
            useDistance = tonumber(distanceEntry:GetValue()) or 140
        })
    end)
    saveProfile:SetPos(96, 70)
    saveProfile:SetSize(120, 26)

    local delProfile = makeButton(right, "Удалить", function()
        local pid = selected or string.Trim(idEntry:GetValue() or "")
        if pid == "" then return end
        sendAction("vendor_remove", { profileId = pid })
    end)
    delProfile:SetPos(220, 70)
    delProfile:SetSize(116, 26)

    local spawnProfile = makeButton(right, "Спавн торговца", function()
        local pid = selected or string.Trim(idEntry:GetValue() or "")
        if pid == "" then return end
        sendAction("vendor_spawn", { profileId = pid })
    end)
    spawnProfile:SetPos(10, 100)
    spawnProfile:SetSize(326, 26)

    local stockItem = vgui.Create("DComboBox", right)
    stockItem:SetPos(10, 136)
    stockItem:SetSize(180, 26)
    stockItem:SetValue("Item")
    for _, itemId in ipairs(payload.itemIds or {}) do
        stockItem:AddChoice(itemId)
    end

    local buy = vgui.Create("DTextEntry", right)
    buy:SetPos(196, 136)
    buy:SetSize(68, 26)
    buy:SetValue("0")

    local sell = vgui.Create("DTextEntry", right)
    sell:SetPos(268, 136)
    sell:SetSize(68, 26)
    sell:SetValue("0")

    local addStock = makeButton(right, "Добавить/обновить товар", function()
        local pid = selected or string.Trim(idEntry:GetValue() or "")
        local itemId = stockItem:GetValue()
        if pid == "" or itemId == "" or itemId == "Item" then return end
        sendAction("vendor_stock_upsert", {
            profileId = pid,
            itemId = itemId,
            buyPrice = tonumber(buy:GetValue()) or 0,
            sellPrice = tonumber(sell:GetValue()) or 0
        })
    end)
    addStock:SetPos(10, 166)
    addStock:SetSize(326, 26)

    local stockList = vgui.Create("DListView", right)
    stockList:SetPos(10, 198)
    stockList:SetSize(326, right:GetTall() - 208)
    stockList:AddColumn("Item")
    stockList:AddColumn("Buy")
    stockList:AddColumn("Sell")

    local function refreshStock(pid)
        stockList:Clear()
        local prof = payload.vendorProfiles and payload.vendorProfiles[pid] or nil
        if not prof then return end
        for _, row in ipairs(prof.stock or {}) do
            stockList:AddLine(row.id or "", tostring(row.buyPrice or 0), tostring(row.sellPrice or 0))
        end
    end

    profiles.OnRowSelected = function(_, _, line)
        selected = line:GetColumnText(1)
        local prof = payload.vendorProfiles[selected]
        if not prof then return end
        idEntry:SetText(selected)
        nameEntry:SetText(prof.name or "")
        modelEntry:SetText(prof.model or "")
        distanceEntry:SetText(tostring(prof.useDistance or 140))
        refreshStock(selected)
    end

    stockList.OnRowRightClick = function(_, _, line)
        local menu = DermaMenu()
        menu:AddOption("Удалить товар", function()
            if not selected then return end
            sendAction("vendor_stock_remove", {
                profileId = selected,
                itemId = line:GetColumnText(1)
            })
        end)
        menu:Open()
    end

    panel.OnSizeChanged = function(self, w, h)
        profiles:SetSize(300, h - 20)
        right:SetPos(320, 10)
        right:SetSize(w - 330, h - 20)
        stockList:SetSize(right:GetWide() - 20, right:GetTall() - 208)
    end

    refreshProfiles()
end

local function rebuildCustomItemsTab(panel)
    panel:Clear()

    local list = vgui.Create("DListView", panel)
    list:SetPos(10, 10)
    list:SetSize(420, panel:GetTall() - 20)
    list:AddColumn("Item ID")
    list:AddColumn("Название")
    list:AddColumn("Stack")
    list:AddColumn("Buy")
    list:AddColumn("Sell")

    local right = vgui.Create("DScrollPanel", panel)
    right:SetPos(440, 10)
    right:SetSize(panel:GetWide() - 450, panel:GetTall() - 20)

    local y = 0
    local function addLabel(text)
        local lbl = vgui.Create("DLabel", right)
        lbl:SetPos(0, y)
        lbl:SetSize(320, 18)
        lbl:SetText(text)
        lbl:SetFont("NexusInvAdminText")
        y = y + 20
        return lbl
    end

    local function addEntry(defaultValue)
        local e = vgui.Create("DTextEntry", right)
        e:SetPos(0, y)
        e:SetSize(360, 26)
        e:SetValue(defaultValue or "")
        y = y + 32
        return e
    end

    local function addCheck(text, defaultValue)
        local c = vgui.Create("DCheckBoxLabel", right)
        c:SetPos(0, y)
        c:SetText(text)
        c:SetValue(defaultValue and 1 or 0)
        c:SizeToContents()
        y = y + 24
        return c
    end

    addLabel("itemId (a-z0-9_)")
    local itemId = addEntry("")

    addLabel("Название")
    local name = addEntry("")

    addLabel("Модель")
    local model = addEntry("models/props_junk/cardboard_box003a.mdl")

    addLabel("Описание")
    local description = addEntry("")

    addLabel("maxStack")
    local maxStack = addEntry("1")

    addLabel("buyPrice")
    local buyPrice = addEntry("0")

    addLabel("sellPrice")
    local sellPrice = addEntry("0")

    local canDrop = addCheck("Можно выбрасывать", true)
    local canSell = addCheck("Можно продавать", true)

    addLabel("useType (например: heal)")
    local useType = addEntry("")

    addLabel("healAmount")
    local healAmount = addEntry("0")

    local function fillForm(id, item)
        itemId:SetValue(id or "")
        name:SetValue(item.name or "")
        model:SetValue(item.model or "")
        description:SetValue(item.description or "")
        maxStack:SetValue(tostring(item.maxStack or 1))
        buyPrice:SetValue(tostring(item.buyPrice or 0))
        sellPrice:SetValue(tostring(item.sellPrice or 0))
        canDrop:SetChecked(item.canDrop ~= false)
        canSell:SetChecked(item.canSell ~= false)
        useType:SetValue(item.useType or "")
        healAmount:SetValue(tostring(item.healAmount or 0))
    end

    local saveBtn = makeButton(right, "Сохранить предмет", function()
        local id = string.Trim(itemId:GetValue() or "")
        if id == "" then return end

        sendAction("item_upsert", {
            itemId = id,
            item = {
                name = string.Trim(name:GetValue() or ""),
                model = string.Trim(model:GetValue() or ""),
                description = string.Trim(description:GetValue() or ""),
                maxStack = tonumber(maxStack:GetValue()) or 1,
                buyPrice = tonumber(buyPrice:GetValue()) or 0,
                sellPrice = tonumber(sellPrice:GetValue()) or 0,
                canDrop = canDrop:GetChecked(),
                canSell = canSell:GetChecked(),
                useType = string.Trim(useType:GetValue() or ""),
                healAmount = tonumber(healAmount:GetValue()) or 0
            }
        })
    end)
    saveBtn:SetPos(0, y)
    saveBtn:SetSize(360, 28)
    y = y + 36

    local removeBtn = makeButton(right, "Удалить предмет", function()
        local id = string.Trim(itemId:GetValue() or "")
        if id == "" then return end
        sendAction("item_remove", { itemId = id })
    end)
    removeBtn:SetPos(0, y)
    removeBtn:SetSize(360, 28)

    local rows = {}
    for id, item in pairs(payload.customItems or {}) do
        rows[#rows + 1] = {
            id = id,
            name = item.name or "",
            stack = tostring(item.maxStack or 1),
            buy = tostring(item.buyPrice or 0),
            sell = tostring(item.sellPrice or 0)
        }
    end
    table.sort(rows, function(a, b) return a.id < b.id end)

    for _, row in ipairs(rows) do
        list:AddLine(row.id, row.name, row.stack, row.buy, row.sell)
    end

    list.OnRowSelected = function(_, _, line)
        local id = line:GetColumnText(1)
        local item = payload.customItems and payload.customItems[id]
        if not item then return end
        fillForm(id, item)
    end

    list.OnRowRightClick = function(_, _, line)
        local id = line:GetColumnText(1)
        local menu = DermaMenu()
        menu:AddOption("Загрузить в форму", function()
            local item = payload.customItems and payload.customItems[id]
            if not item then return end
            fillForm(id, item)
        end)
        menu:AddOption("Удалить", function()
            sendAction("item_remove", { itemId = id })
        end)
        menu:Open()
    end

    panel.OnSizeChanged = function(self, w, h)
        list:SetSize(420, h - 20)
        right:SetPos(440, 10)
        right:SetSize(w - 450, h - 20)
    end
end

local function openAdminUI()
    if IsValid(adminFrame) then
        adminFrame:Remove()
    end

    adminFrame = vgui.Create("DFrame")
    adminFrame:SetSize(1120, 680)
    adminFrame:Center()
    adminFrame:SetTitle("")
    adminFrame:ShowCloseButton(false)
    adminFrame:SetDraggable(false)
    adminFrame:MakePopup()

    adminFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(16, 18, 26, 238))
        draw.SimpleText("NEXUS INVENTORY ADMIN", "NexusInvAdminTitle", 16, 22, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = makeButton(adminFrame, "X", function()
        adminFrame:Remove()
    end)
    close:SetPos(adminFrame:GetWide() - 42, 10)
    close:SetSize(28, 22)

    local tabs = vgui.Create("DPropertySheet", adminFrame)
    tabs:SetPos(12, 48)
    tabs:SetSize(adminFrame:GetWide() - 24, adminFrame:GetTall() - 60)

    local localItemsTab = vgui.Create("DPanel", tabs)
    localItemsTab:Dock(FILL)
    localItemsTab.Paint = nil
    rebuildLocalItemsTab(localItemsTab)
    tabs:AddSheet("Локальные (база)", localItemsTab)

    local giveTab = vgui.Create("DPanel", tabs)
    giveTab:Dock(FILL)
    giveTab.Paint = nil
    rebuildGiveTab(giveTab)
    tabs:AddSheet("Выдача предметов", giveTab)

    local vendorsTab = vgui.Create("DPanel", tabs)
    vendorsTab:Dock(FILL)
    vendorsTab.Paint = nil
    rebuildVendorsTab(vendorsTab)
    tabs:AddSheet("Торговцы", vendorsTab)

    local customItemsTab = vgui.Create("DPanel", tabs)
    customItemsTab:Dock(FILL)
    customItemsTab.Paint = nil
    rebuildCustomItemsTab(customItemsTab)
    tabs:AddSheet("Кастомные предметы", customItemsTab)
end

net.Receive("nexus_inv_admin_open", function()
    openAdminUI()
end)

net.Receive("nexus_inv_admin_sync", function()
    payload = util.JSONToTable(net.ReadString() or "") or payload
    payload.localItems = payload.localItems or {}
    payload.vendorProfiles = payload.vendorProfiles or {}
    payload.customItems = payload.customItems or {}
    payload.itemIds = payload.itemIds or {}

    _G.NEXUS_INV_RUNTIME_CUSTOM_ITEMS = payload.customItems

    if IsValid(adminFrame) then
        openAdminUI()
    end
end)