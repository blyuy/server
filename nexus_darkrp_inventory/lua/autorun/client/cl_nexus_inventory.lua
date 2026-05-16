if SERVER then return end

local function cfg(group, key, fallback)
    local section = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG[group]
    if not section then return fallback end
    local value = section[key]
    if value == nil then return fallback end
    return value
end

local invFrame
local inventoryData = {}
local vendorEntity = NULL
local f4InventoryHost = nil

surface.CreateFont("NexusInvTitle", {
    font = "Roboto",
    size = 28,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusInvText", {
    font = "Roboto",
    size = 17,
    weight = 500,
    antialias = true
})

surface.CreateFont("NexusInvSmall", {
    font = "Roboto",
    size = 14,
    weight = 500,
    antialias = true
})

local function itemDef(itemId)
    local static = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.Items and NEXUS_INV_CONFIG.Items[itemId] or nil
    if static then return static end

    if string.sub(itemId or "", 1, 8) ~= "weapon::" then
        return nil
    end

    local class = string.sub(itemId, 9)
    local stored = weapons.GetStored(class)
    local name = (stored and stored.PrintName and stored.PrintName ~= "") and stored.PrintName or class
    local model = (stored and stored.WorldModel and stored.WorldModel ~= "") and stored.WorldModel or "models/weapons/w_pistol.mdl"

    return {
        name = name,
        model = model,
        description = "Складированное оружие. Используйте для выдачи.",
        maxStack = 1,
        canDrop = true,
        canSell = false,
        useType = "equip_weapon"
    }
end

local function isLocalItem(itemId)
    for _, localItem in ipairs(NEXUS_INV_CONFIG.LocalItems or {}) do
        if localItem.id == itemId then return true end
    end
    return false
end

local function sendAction(action, itemId, amount)
    net.Start("nexus_inv_action")
    net.WriteString(action)
    net.WriteString(itemId)
    net.WriteUInt(math.max(1, amount or 1), 16)
    net.SendToServer()
end

local function sendVendorAction(action, itemId, amount)
    net.Start("nexus_inv_vendor_action")
    net.WriteString(action)
    net.WriteString(itemId)
    net.WriteUInt(math.max(1, amount or 1), 16)
    net.WriteEntity(vendorEntity)
    net.SendToServer()
end

local function requestSync()
    net.Start("nexus_inv_request_sync")
    net.SendToServer()
end

local function currentVendorProfile()
    if not IsValid(vendorEntity) then return nil end
    local id = vendorEntity.GetProfileId and vendorEntity:GetProfileId() or ""
    if id == "" then return nil end

    return NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.VendorProfiles and NEXUS_INV_CONFIG.VendorProfiles[id] or nil
end

local function createItemCard(parent, itemId, amount, onClick)
    local def = itemDef(itemId)
    if not def then return end

    local btn = vgui.Create("DButton", parent)
    btn:SetSize(120, 120)
    btn:SetText("")
    btn.hover = 0
    btn.DoClick = onClick

    local model = vgui.Create("DModelPanel", btn)
    model:Dock(FILL)
    model:DockMargin(6, 6, 6, 28)
    model:SetModel(def.model or "models/props_junk/cardboard_box003a.mdl")
    model:SetFOV(30)
    model.LayoutEntity = function() end

    btn.Paint = function(self, w, h)
        self.hover = Lerp(FrameTime() * 12, self.hover, self:IsHovered() and 1 or 0)
        local r = Lerp(self.hover, 24, 38)
        local g = Lerp(self.hover, 27, 48)
        local b = Lerp(self.hover, 38, 68)

        draw.RoundedBox(8, 0, 0, w, h, Color(r, g, b, 238))
        draw.SimpleText(def.name or itemId, "NexusInvSmall", 6, h - 18, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("x" .. amount, "NexusInvSmall", w - 6, h - 18, Color(210, 220, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    return btn
end

local function rebuildInventoryTab(panel)
    panel:Clear()

    local left = vgui.Create("DPanel", panel)
    left:Dock(LEFT)
    left:SetWide(430)
    left.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(19, 22, 33, 235))
    end

    local right = vgui.Create("DPanel", panel)
    right:Dock(FILL)
    right:DockMargin(10, 0, 0, 0)
    right.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(19, 22, 33, 235))
    end

    local selectedId = nil

    local titleLabel = vgui.Create("DLabel", right)
    titleLabel:Dock(TOP)
    titleLabel:DockMargin(12, 12, 12, 0)
    titleLabel:SetTall(24)
    titleLabel:SetFont("NexusInvText")
    titleLabel:SetTextColor(color_white)
    titleLabel:SetText("Выберите предмет")

    local infoLabel = vgui.Create("DLabel", right)
    infoLabel:Dock(FILL)
    infoLabel:DockMargin(12, 6, 12, 60)
    infoLabel:SetFont("NexusInvSmall")
    infoLabel:SetTextColor(Color(220, 228, 245))
    infoLabel:SetWrap(true)
    infoLabel:SetAutoStretchVertical(true)
    infoLabel:SetText("Инвентарь пуст.\n\nПодбор: Shift + E\nОружие и коробки из F4 поддерживаются.")

    local dropBtn = vgui.Create("DButton", right)
    dropBtn:Dock(BOTTOM)
    dropBtn:DockMargin(12, 0, 12, 8)
    dropBtn:SetTall(24)
    dropBtn:SetText("Выбросить")
    dropBtn:SetFont("NexusInvSmall")
    dropBtn:SetTextColor(color_white)
    dropBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(69, 98, 160, self:IsHovered() and 245 or 220))
    end
    dropBtn:SetEnabled(false)

    local useBtn = vgui.Create("DButton", right)
    useBtn:Dock(BOTTOM)
    useBtn:DockMargin(12, 0, 12, 8)
    useBtn:SetTall(24)
    useBtn:SetText("Использовать")
    useBtn:SetFont("NexusInvSmall")
    useBtn:SetTextColor(color_white)
    useBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(69, 98, 160, self:IsHovered() and 245 or 220))
    end
    useBtn:SetEnabled(false)

    local list = vgui.Create("DScrollPanel", left)
    list:Dock(FILL)
    list:DockMargin(8, 8, 8, 8)

    local function updateInfo(itemId)
        selectedId = itemId
        local def = itemDef(itemId)
        local amount = inventoryData[itemId] or 0
        if not def then return end

        titleLabel:SetText(def.name or itemId)
        infoLabel:SetText(
            (def.description or "") .. "\n\n"
            .. "Количество: " .. amount .. "\n"
            .. "Макс. стак: " .. (def.maxStack or 1) .. "\n"
            .. "Продажа: " .. tostring(def.sellPrice or 0) .. "\n"
            .. "Локальный: " .. (isLocalItem(itemId) and "Да" or "Нет")
        )

        useBtn:SetEnabled(def.useType ~= nil)
        dropBtn:SetEnabled(def.canDrop ~= false and not isLocalItem(itemId))
    end

    local hasAny = false
    for itemId, amount in pairs(inventoryData) do
        local def = itemDef(itemId)
        if def then
            hasAny = true

            local row = vgui.Create("DButton", list)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 8)
            row:SetTall(58)
            row:SetText("")
            row.hover = 0

            local icon = vgui.Create("DModelPanel", row)
            icon:SetPos(6, 6)
            icon:SetSize(46, 46)
            icon:SetModel(def.model or "models/props_junk/cardboard_box003a.mdl")
            icon:SetFOV(30)
            icon.LayoutEntity = function() end

            row.Paint = function(self, w, h)
                self.hover = Lerp(FrameTime() * 12, self.hover, self:IsHovered() and 1 or 0)
                local r = Lerp(self.hover, 28, 44)
                local g = Lerp(self.hover, 32, 52)
                local b = Lerp(self.hover, 46, 76)

                draw.RoundedBox(8, 0, 0, w, h, Color(r, g, b, 236))
                draw.SimpleText(def.name or itemId, "NexusInvText", 58, 20, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("x" .. amount, "NexusInvSmall", w - 10, 20, Color(205, 218, 245), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                draw.SimpleText(def.description or "", "NexusInvSmall", 58, 40, Color(160, 174, 206), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            row.DoClick = function()
                updateInfo(itemId)
            end
        end
    end

    if not hasAny then
        titleLabel:SetText("Инвентарь пуст")
        infoLabel:SetText("В инвентаре пока нет предметов.\n\nПодберите предметы через Shift + E.")
    end

    useBtn.DoClick = function()
        if not selectedId then return end
        sendAction("use", selectedId, 1)
    end

    dropBtn.DoClick = function()
        if not selectedId then return end
        sendAction("drop", selectedId, 1)
    end
end

local function rebuildVendorTab(panel)
    panel:Clear()

    local left = vgui.Create("DPanel", panel)
    left:Dock(LEFT)
    left:SetWide(470)
    left.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(19, 22, 33, 235))
        draw.SimpleText("Покупка", "NexusInvText", 12, 14, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local right = vgui.Create("DPanel", panel)
    right:Dock(FILL)
    right:DockMargin(10, 0, 0, 0)
    right.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(19, 22, 33, 235))
        draw.SimpleText("Продажа", "NexusInvText", 12, 14, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local buyList = vgui.Create("DScrollPanel", left)
    buyList:Dock(FILL)
    buyList:DockMargin(8, 34, 8, 8)

    local sellList = vgui.Create("DScrollPanel", right)
    sellList:Dock(FILL)
    sellList:DockMargin(8, 34, 8, 8)

    local profile = currentVendorProfile()
    for _, entry in ipairs((profile and profile.stock) or {}) do
        local def = itemDef(entry.id)
        if not def then continue end

        local buy = vgui.Create("DButton", buyList)
        buy:Dock(TOP)
        buy:DockMargin(0, 0, 0, 6)
        buy:SetTall(34)
        buy:SetText("")
        buy.Paint = function(self, w, h)
            draw.RoundedBox(7, 0, 0, w, h, Color(37, 42, 60, self:IsHovered() and 240 or 214))
            draw.SimpleText((def.name or entry.id) .. " - " .. tostring(entry.buyPrice or def.buyPrice or 0), "NexusInvSmall", 8, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        buy.DoClick = function()
            sendVendorAction("buy", entry.id, 1)
        end

        local sell = vgui.Create("DButton", sellList)
        sell:Dock(TOP)
        sell:DockMargin(0, 0, 0, 6)
        sell:SetTall(34)
        sell:SetText("")
        sell.Paint = function(self, w, h)
            draw.RoundedBox(7, 0, 0, w, h, Color(37, 42, 60, self:IsHovered() and 240 or 214))
            draw.SimpleText((def.name or entry.id) .. " +" .. tostring(entry.sellPrice or def.sellPrice or 0), "NexusInvSmall", 8, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        sell.DoClick = function()
            sendVendorAction("sell", entry.id, 1)
        end
    end
end

local function buildInventoryEmbedded(parent)
    if not IsValid(parent) then return end

    local host = parent
    if parent.GetCanvas then
        host = parent:GetCanvas()
    end

    if not IsValid(host) then return end
    host:Clear()

    local root = vgui.Create("DPanel", host)
    root:Dock(TOP)
    root:SetTall(math.max(parent:GetTall() - 6, 300))
    root:SetWide(math.max(parent:GetWide() - 6, 300))
    root.Paint = nil

    if parent.GetWide and parent.GetTall then
        root.Think = function(self)
            local targetH = math.max(parent:GetTall() - 6, 300)
            local targetW = math.max(parent:GetWide() - 6, 300)
            if self:GetTall() ~= targetH then self:SetTall(targetH) end
            if self:GetWide() ~= targetW then self:SetWide(targetW) end
        end
    end

    rebuildInventoryTab(root)
end

_G.NEXUS_INV_F4_BUILD = function(parent)
    if not IsValid(parent) then return end
    vendorEntity = NULL
    f4InventoryHost = parent
    buildInventoryEmbedded(parent)
    requestSync()

    timer.Simple(0.3, function()
        if IsValid(f4InventoryHost) then
            requestSync()
        end
    end)
end

hook.Run("NexusInvBuilderReady")

local function openInventoryUI(isVendor, vendorEnt)
    if IsValid(invFrame) then invFrame:Remove() end
    vendorEntity = vendorEnt or NULL

    invFrame = vgui.Create("DFrame")
    invFrame:SetSize(980, 600)
    invFrame:Center()
    invFrame:SetTitle("")
    invFrame:ShowCloseButton(false)
    invFrame:SetDraggable(false)
    invFrame:MakePopup()

    invFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(16, 18, 26, 238))
        draw.SimpleText("NEXUS INVENTORY", "NexusInvTitle", 16, 24, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Shift + E подбирает только разрешенные предметы", "NexusInvSmall", 16, 48, Color(165, 176, 201), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", invFrame)
    closeBtn:SetPos(invFrame:GetWide() - 44, 10)
    closeBtn:SetSize(30, 24)
    closeBtn:SetText("X")
    closeBtn:SetFont("NexusInvText")
    closeBtn:SetTextColor(color_white)
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(58, 66, 92, self:IsHovered() and 240 or 210))
    end
    closeBtn.DoClick = function()
        invFrame:Remove()
    end

    local content = vgui.Create("DPanel", invFrame)
    content:SetPos(12, 72)
    content:SetSize(invFrame:GetWide() - 24, invFrame:GetTall() - 84)
    content.Paint = nil

    local invTabBtn = vgui.Create("DButton", invFrame)
    invTabBtn:SetPos(12, 44)
    invTabBtn:SetSize(120, 22)
    invTabBtn:SetText("Инвентарь")
    invTabBtn:SetFont("NexusInvSmall")
    invTabBtn:SetTextColor(color_white)
    invTabBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(69, 98, 160, self:IsHovered() and 245 or 220))
    end

    local vendorTabBtn
    if isVendor then
        vendorTabBtn = vgui.Create("DButton", invFrame)
        vendorTabBtn:SetPos(136, 44)
        vendorTabBtn:SetSize(120, 22)
        vendorTabBtn:SetText("Торговец")
        vendorTabBtn:SetFont("NexusInvSmall")
        vendorTabBtn:SetTextColor(color_white)
        vendorTabBtn.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(69, 98, 160, self:IsHovered() and 245 or 220))
        end
    end

    local function showInventory()
        rebuildInventoryTab(content)
    end

    local function showVendor()
        rebuildVendorTab(content)
    end

    invTabBtn.DoClick = showInventory
    if IsValid(vendorTabBtn) then
        vendorTabBtn.DoClick = showVendor
    end

    showInventory()
end

net.Receive("nexus_inv_sync", function()
    local count = net.ReadUInt(12)
    inventoryData = {}
    for _ = 1, count do
        local itemId = net.ReadString()
        local amount = net.ReadUInt(16)
        inventoryData[itemId] = amount
    end

    if IsValid(invFrame) then
        openInventoryUI(IsValid(vendorEntity), vendorEntity)
    end

    if IsValid(f4InventoryHost) then
        buildInventoryEmbedded(f4InventoryHost)
    end
end)

net.Receive("nexus_inv_open", function()
    local isVendor = net.ReadBool()
    local vEnt = net.ReadEntity()
    openInventoryUI(isVendor, vEnt)
end)

hook.Add("PlayerBindPress", "NexusInvShiftPickup", function(_, bind, pressed)
    if not pressed then return end
    if not string.find(string.lower(bind or ""), "+use", 1, true) then return end
    if not cfg("Settings", "shiftPickupEnabled", true) then return end

    if not (input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)) then return end
    if IsValid(vgui.GetKeyboardFocus()) then return end

    net.Start("nexus_inv_pickup")
    net.SendToServer()
    return true
end)