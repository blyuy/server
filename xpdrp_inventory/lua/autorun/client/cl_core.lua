XPDRP = XPDRP or {}
XPDRP.Inventory = XPDRP.Inventory or {}

local state = {
    slots = {},
    maxSlots = XPDRP.Inventory.Config.MaxSlots,
    selectedSlot = nil,
    merchantId = nil,
    merchant = nil
}

local function getItem(slot)
    if not slot then return nil end
    return XPDRP.Inventory.GetItem(slot.id)
end

local function sendUse(slot)
    net.Start("xpdrp_inv_req_use")
    net.WriteUInt(slot, 8)
    net.SendToServer()
end

local function sendDrop(slot, amount)
    net.Start("xpdrp_inv_req_drop")
    net.WriteUInt(slot, 8)
    net.WriteUInt(math.Clamp(amount, 1, 255), 8)
    net.SendToServer()
end

local function sendCraft(id, amount)
    net.Start("xpdrp_inv_req_craft")
    net.WriteString(id)
    net.WriteUInt(math.Clamp(amount, 1, 255), 8)
    net.SendToServer()
end

local function sendBuy(itemId, amount)
    if not state.merchantId then return end
    net.Start("xpdrp_inv_req_buy")
    net.WriteString(state.merchantId)
    net.WriteString(itemId)
    net.WriteUInt(math.Clamp(amount, 1, 255), 8)
    net.SendToServer()
end

local function sendSell(slot, amount)
    if not state.merchantId then return end
    net.Start("xpdrp_inv_req_sell")
    net.WriteString(state.merchantId)
    net.WriteUInt(slot, 8)
    net.WriteUInt(math.Clamp(amount, 1, 255), 8)
    net.SendToServer()
end

local function requestMerchant()
    net.Start("xpdrp_inv_req_open_merchant")
    net.SendToServer()
end

net.Receive("xpdrp_inv_sync", function()
    state.maxSlots = net.ReadUInt(8)
    state.slots = net.ReadTable() or {}
    state.selectedSlot = nil
end)

net.Receive("xpdrp_inv_open_merchant", function()
    state.merchantId = net.ReadString()
    state.merchant = net.ReadTable()
end)

local function sortedRecipes()
    local out = {}
    for id, recipe in pairs(XPDRP.Inventory.Recipes or {}) do
        out[#out + 1] = { id = id, recipe = recipe }
    end
    table.sort(out, function(a, b)
        return string.lower(a.recipe.name) < string.lower(b.recipe.name)
    end)
    return out
end

local function drawCard(self, w, h, selected)
    local bg = selected and Color(82, 162, 255, 60) or Color(255, 255, 255, self:IsHovered() and 10 or 5)
    draw.RoundedBox(0, 0, 0, w, h, bg)
    surface.SetDrawColor(255, 255, 255, selected and 24 or 12)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

function XPDRP.Inventory.BuildF4Tab(parent)
    local root = vgui.Create("EditablePanel", parent)
    local rebuildRight

    local left = vgui.Create("DPanel", root)
    left:Dock(LEFT)
    left:SetWide(500)
    left:DockMargin(0, 0, 10, 0)
    left.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(12, 17, 27, 236))
        surface.SetDrawColor(255, 255, 255, 12)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local leftScroll = vgui.Create("XPScrollPanel", left)
    leftScroll:Dock(FILL)
    leftScroll:DockMargin(10, 10, 10, 10)

    local right = vgui.Create("DPanel", root)
    right:Dock(FILL)
    right.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(12, 17, 27, 236))
        surface.SetDrawColor(255, 255, 255, 12)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local rightScroll = vgui.Create("XPScrollPanel", right)
    rightScroll:Dock(FILL)
    rightScroll:DockMargin(10, 10, 10, 10)

    local function rebuildLeft()
        leftScroll:Clear()

        for i = 1, state.maxSlots do
            local slot = state.slots[i]
            local item = getItem(slot)
            local name = item and item.name or "Пусто"
            local amount = slot and slot.amount or 0
            local sub = slot and ("id: " .. slot.id) or "Свободный слот"

            local btn = vgui.Create("DButton", leftScroll)
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, 6)
            btn:SetTall(50)
            btn:SetText("")
            btn.Paint = function(self, w, h)
                drawCard(self, w, h, state.selectedSlot == i)
                draw.SimpleText("#" .. i .. "  " .. name, "xpgui_medium", 10, 14, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(sub, "xpgui_tiny", 10, 34, Color(166, 182, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                if slot then
                    draw.SimpleText("x" .. amount, "xpgui_medium", w - 10, 24, Color(112, 214, 136), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
            btn.DoClick = function()
                state.selectedSlot = i
                rebuildLeft()
                rebuildRight()
            end
        end
    end

    rebuildRight = function()
        rightScroll:Clear()

        local title = vgui.Create("DLabel", rightScroll)
        title:Dock(TOP)
        title:SetFont("xpgui_big")
        title:SetTextColor(color_white)
        title:SetText("Инвентарь и крафт")
        title:SizeToContentsY()

        local slot = state.selectedSlot and state.slots[state.selectedSlot] or nil
        local item = getItem(slot)

        local info = vgui.Create("DLabel", rightScroll)
        info:Dock(TOP)
        info:DockMargin(0, 6, 0, 10)
        info:SetFont("xpgui_tiny")
        info:SetTextColor(Color(166, 182, 205))
        info:SetWrap(true)
        info:SetAutoStretchVertical(true)

        if item then
            info:SetText(item.name .. "\n" .. (item.description or "") .. "\nКоличество: " .. tostring(slot.amount))
        else
            info:SetText("Выберите слот слева.")
        end

        local useBtn = vgui.Create("XPButton", rightScroll)
        useBtn:Dock(TOP)
        useBtn:DockMargin(0, 0, 0, 6)
        useBtn:SetText("Использовать")
        useBtn:SetTall(34)
        useBtn:SetEnabled(item and isfunction(item.use) or false)
        useBtn.DoClick = function()
            if not state.selectedSlot then return end
            sendUse(state.selectedSlot)
        end

        local dropBtn = vgui.Create("XPButton", rightScroll)
        dropBtn:Dock(TOP)
        dropBtn:DockMargin(0, 0, 0, 14)
        dropBtn:SetText("Выбросить 1")
        dropBtn:SetTall(34)
        dropBtn:SetEnabled(item ~= nil)
        dropBtn.DoClick = function()
            if not state.selectedSlot then return end
            sendDrop(state.selectedSlot, 1)
        end

        local craftTitle = vgui.Create("DLabel", rightScroll)
        craftTitle:Dock(TOP)
        craftTitle:SetFont("xpgui_medium")
        craftTitle:SetTextColor(color_white)
        craftTitle:SetText("Крафт")
        craftTitle:SizeToContentsY()

        for _, row in ipairs(sortedRecipes()) do
            local recipe = row.recipe
            local req = {}
            for reqId, reqAmount in pairs(recipe.require) do
                local reqItem = XPDRP.Inventory.GetItem(reqId)
                req[#req + 1] = (reqItem and reqItem.name or reqId) .. " x" .. reqAmount
            end

            local btn = vgui.Create("DButton", rightScroll)
            btn:Dock(TOP)
            btn:DockMargin(0, 6, 0, 0)
            btn:SetTall(56)
            btn:SetText("")
            btn.Paint = function(self, w, h)
                drawCard(self, w, h, false)
                draw.SimpleText(recipe.name, "xpgui_medium", 10, 16, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(table.concat(req, ", "), "xpgui_tiny", 10, 38, Color(166, 182, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function()
                sendCraft(row.id, 1)
            end
        end

        local merchantTitle = vgui.Create("DLabel", rightScroll)
        merchantTitle:Dock(TOP)
        merchantTitle:DockMargin(0, 16, 0, 0)
        merchantTitle:SetFont("xpgui_medium")
        merchantTitle:SetTextColor(color_white)
        merchantTitle:SetText("Торговец")
        merchantTitle:SizeToContentsY()

        local openM = vgui.Create("XPButton", rightScroll)
        openM:Dock(TOP)
        openM:DockMargin(0, 6, 0, 6)
        openM:SetText("Открыть торговца перед собой")
        openM:SetTall(34)
        openM.DoClick = requestMerchant

        if state.merchant then
            local mName = vgui.Create("DLabel", rightScroll)
            mName:Dock(TOP)
            mName:SetFont("xpgui_tiny")
            mName:SetTextColor(Color(166, 182, 205))
            mName:SetText("Подключен: " .. (state.merchant.name or "Торговец"))
            mName:SizeToContentsY()

            for itemId, price in pairs(state.merchant.buy or {}) do
                local itemData = XPDRP.Inventory.GetItem(itemId)
                local btn = vgui.Create("XPButton", rightScroll)
                btn:Dock(TOP)
                btn:DockMargin(0, 4, 0, 0)
                btn:SetTall(32)
                btn:SetText("Купить: " .. (itemData and itemData.name or itemId) .. " за " .. XPDRP.FormatMoney(price))
                btn.DoClick = function()
                    sendBuy(itemId, 1)
                end
            end

            local sellBtn = vgui.Create("XPButton", rightScroll)
            sellBtn:Dock(TOP)
            sellBtn:DockMargin(0, 10, 0, 0)
            sellBtn:SetTall(34)
            sellBtn:SetText("Продать выбранный слот")
            sellBtn:SetEnabled(slot ~= nil)
            sellBtn.DoClick = function()
                if not state.selectedSlot then return end
                sendSell(state.selectedSlot, 1)
            end
        end
    end

    rebuildLeft()
    rebuildRight()

    net.Receive("xpdrp_inv_sync", function()
        if not IsValid(root) then return end
        rebuildLeft()
        rebuildRight()
    end)

    net.Receive("xpdrp_inv_open_merchant", function()
        if not IsValid(root) then return end
        rebuildRight()
    end)

    return root
end
