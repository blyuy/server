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

local function rebuildLocalItemsTab(panel)
    panel:Clear()

    local itemBox = vgui.Create("DComboBox", panel)
    itemBox:SetPos(10, 10)
    itemBox:SetSize(260, 28)
    itemBox:SetValue("Выберите предмет")
    for _, itemId in ipairs(payload.itemIds or {}) do
        itemBox:AddChoice(itemId)
    end

    local amount = vgui.Create("DTextEntry", panel)
    amount:SetPos(276, 10)
    amount:SetSize(80, 28)
    amount:SetValue("1")

    local addBtn = makeButton(panel, "Добавить/обновить", function()
        local itemId = itemBox:GetValue()
        if not itemId or itemId == "" or itemId == "Выберите предмет" then return end
        sendAction("local_add", {
            itemId = itemId,
            amount = tonumber(amount:GetValue()) or 1
        })
    end)
    addBtn:SetPos(362, 10)
    addBtn:SetSize(170, 28)

    local list = vgui.Create("DListView", panel)
    list:SetPos(10, 48)
    list:SetSize(panel:GetWide() - 20, panel:GetTall() - 58)
    list:AddColumn("Item ID")
    list:AddColumn("Amount")

    for _, row in ipairs(payload.localItems or {}) do
        list:AddLine(row.id or "", tostring(row.amount or 1))
    end

    list.OnRowRightClick = function(_, id, line)
        local menu = DermaMenu()
        menu:AddOption("Удалить", function()
            sendAction("local_remove", { itemId = line:GetColumnText(1) })
        end)
        menu:Open()
    end

    panel.OnSizeChanged = function(self, w, h)
        list:SetSize(w - 20, h - 58)
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
        for id, prof in pairs(payload.vendorProfiles or {}) do
            profiles:AddLine(id, prof.name or "Торговец")
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

local function openAdminUI()
    if IsValid(adminFrame) then
        adminFrame:Remove()
    end

    adminFrame = vgui.Create("DFrame")
    adminFrame:SetSize(980, 640)
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
    tabs:AddSheet("Локальные предметы", localItemsTab)

    local vendorsTab = vgui.Create("DPanel", tabs)
    vendorsTab:Dock(FILL)
    vendorsTab.Paint = nil
    rebuildVendorsTab(vendorsTab)
    tabs:AddSheet("Торговцы", vendorsTab)
end

net.Receive("nexus_inv_admin_open", function()
    openAdminUI()
end)

net.Receive("nexus_inv_admin_sync", function()
    payload = util.JSONToTable(net.ReadString() or "") or payload

    if IsValid(adminFrame) then
        openAdminUI()
    end
end)