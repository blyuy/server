XPDRP = XPDRP or {}
XPDRP.Inventory = XPDRP.Inventory or {}

local state = {
    slots = {},
    maxSlots = XPDRP.Inventory.Config.MaxSlots,
    selectedSlot = nil,
    merchantId = nil,
    merchant = nil,
    search = ""
}

local openPanels = {}

local function getSlotItem(slot)
    if not slot then return nil end
    return XPDRP.Inventory.GetItem(slot.id)
end

local function notifyPanels()
    for pnl in pairs(openPanels) do
        if IsValid(pnl) and pnl.XPDRPRefresh then
            pnl:XPDRPRefresh()
        else
            openPanels[pnl] = nil
        end
    end
end

net.Receive("xpdrp_inv_sync", function()
    state.maxSlots = net.ReadUInt(8)
    state.slots = net.ReadTable() or {}
    if state.selectedSlot and not state.slots[state.selectedSlot] then
        state.selectedSlot = nil
    end
    notifyPanels()
end)

net.Receive("xpdrp_inv_open_merchant", function()
    state.merchantId = net.ReadString()
    state.merchant = net.ReadTable()
    notifyPanels()
end)

local function reqUse(slot)
    net.Start("xpdrp_inv_req_use")
    net.WriteUInt(slot, 8)
    net.SendToServer()
end

local function reqDrop(slot, amount)
    net.Start("xpdrp_inv_req_drop")
    net.WriteUInt(slot, 8)
    net.WriteUInt(math.Clamp(amount, 1, 255), 8)
    net.SendToServer()
end

local function reqCraft(id, amount)
    net.Start("xpdrp_inv_req_craft")
    net.WriteString(id)
    net.WriteUInt(math.Clamp(amount, 1, 255), 8)
    net.SendToServer()
end

local function reqMerchantOpen()
    net.Start("xpdrp_inv_req_open_merchant")
    net.SendToServer()
end

local function reqBuy(itemId, amount)
    if not state.merchantId then return end
    net.Start("xpdrp_inv_req_buy")
    net.WriteString(state.merchantId)
    net.WriteString(itemId)
    net.WriteUInt(math.Clamp(amount, 1, 255), 8)
    net.SendToServer()
end

local function reqSell(slot, amount)
    if not state.merchantId then return end
    net.Start("xpdrp_inv_req_sell")
    net.WriteString(state.merchantId)
    net.WriteUInt(slot, 8)
    net.WriteUInt(math.Clamp(amount, 1, 255), 8)
    net.SendToServer()
end

local function sortedRecipes()
    local out = {}
    for id, recipe in pairs(XPDRP.Inventory.Recipes or {}) do
        out[#out + 1] = { id = id, data = recipe }
    end
    table.sort(out, function(a, b)
        return string.lower(a.data.name) < string.lower(b.data.name)
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
    openPanels[root] = true

    root.OnRemove = function(self)
        openPanels[self] = nil
    end

    local left = vgui.Create("DPanel", root)
    left:Dock(LEFT)
    left:SetWide(500)
    left:DockMargin(0, 0, 10, 0)
    left.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(12, 17, 27, 236))
        surface.SetDrawColor(255, 255, 255, 12)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local leftTop = vgui.Create("DPanel", left)
    leftTop:Dock(TOP)
    leftTop:SetTall(40)
    leftTop:DockMargin(10, 10, 10, 0)
    leftTop.Paint = nil

    local search = vgui.Create("XPTextEntry", leftTop)
    search:Dock(FILL)
    search:SetPlaceholderText("Поиск предметов")
    search.OnValueChange = function(self)
        state.search = string.lower(string.Trim(self:GetValue() or ""))
        root:XPDRPRefresh()
    end

    local leftScroll = vgui.Create("XPScrollPanel", left)
    leftScroll:Dock(FILL)
    leftScroll:DockMargin(10, 8, 10, 10)

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

    local function fillLeft()
        leftScroll:Clear()
        local q = state.search or ""

        for i = 1, state.maxSlots do
            local slot = state.slots[i]
            local item = getSlotItem(slot)
            local name = item and item.name or "Пусто"
            local sub = slot and ("id: " .. slot.id) or "Свободный слот"
            local amount = slot and slot.amount or 0

            if q == "" or string.find(string.lower(name), q, 1, true) or string.find(string.lower(sub), q, 1, true) then
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
                    root:XPDRPRefresh()
                end
            end
        end
    end

    local function fillRight()
        rightScroll:Clear()

        local slot = state.selectedSlot and state.slots[state.selectedSlot] or nil
        local item = getSlotItem(slot)

        local title = vgui.Create("DLabel", rightScroll)
        title:Dock(TOP)
        title:SetFont("xpgui_big")
        title:SetTextColor(color_white)
        title:SetText("Инвентарь")
        title:SizeToContentsY()

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
            info:SetText("Выберите слот слева")
        end

        local useBtn = vgui.Create("XPButton", rightScroll)
        useBtn:Dock(TOP)
        useBtn:DockMargin(0, 0, 0, 6)
        useBtn:SetText("Использовать")
        useBtn:SetTall(34)
        useBtn:SetEnabled(item and isfunction(item.use) or false)
        useBtn.DoClick = function()
            if state.selectedSlot then reqUse(state.selectedSlot) end
        end

        local dropBtn = vgui.Create("XPButton", rightScroll)
        dropBtn:Dock(TOP)
        dropBtn:DockMargin(0, 0, 0, 12)
        dropBtn:SetText("Выбросить 1")
        dropBtn:SetTall(34)
        dropBtn:SetEnabled(slot ~= nil)
        dropBtn.DoClick = function()
            if state.selectedSlot then reqDrop(state.selectedSlot, 1) end
        end

        local craftHeader = vgui.Create("DLabel", rightScroll)
        craftHeader:Dock(TOP)
        craftHeader:SetFont("xpgui_medium")
        craftHeader:SetTextColor(color_white)
        craftHeader:SetText("Крафт")
        craftHeader:SizeToContentsY()

        for _, r in ipairs(sortedRecipes()) do
            local req = {}
            for reqId, reqAmount in pairs(r.data.require) do
                local reqItem = XPDRP.Inventory.GetItem(reqId)
                req[#req + 1] = (reqItem and reqItem.name or reqId) .. " x" .. reqAmount
            end

            local btn = vgui.Create("DButton", rightScroll)
            btn:Dock(TOP)
            btn:DockMargin(0, 6, 0, 0)
            btn:SetTall(54)
            btn:SetText("")
            btn.Paint = function(self, w, h)
                drawCard(self, w, h, false)
                draw.SimpleText(r.data.name, "xpgui_medium", 10, 16, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(table.concat(req, ", "), "xpgui_tiny", 10, 36, Color(166, 182, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function() reqCraft(r.id, 1) end
        end

        local mHeader = vgui.Create("DLabel", rightScroll)
        mHeader:Dock(TOP)
        mHeader:DockMargin(0, 16, 0, 0)
        mHeader:SetFont("xpgui_medium")
        mHeader:SetTextColor(color_white)
        mHeader:SetText("Торговец")
        mHeader:SizeToContentsY()

        local openBtn = vgui.Create("XPButton", rightScroll)
        openBtn:Dock(TOP)
        openBtn:DockMargin(0, 6, 0, 6)
        openBtn:SetText("Открыть торговца перед собой")
        openBtn:SetTall(34)
        openBtn.DoClick = reqMerchantOpen

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
                btn.DoClick = function() reqBuy(itemId, 1) end
            end

            local sellBtn = vgui.Create("XPButton", rightScroll)
            sellBtn:Dock(TOP)
            sellBtn:DockMargin(0, 8, 0, 0)
            sellBtn:SetText("Продать выбранный слот")
            sellBtn:SetTall(34)
            sellBtn:SetEnabled(slot ~= nil)
            sellBtn.DoClick = function()
                if state.selectedSlot then reqSell(state.selectedSlot, 1) end
            end
        end
    end

    function root:XPDRPRefresh()
        fillLeft()
        fillRight()
    end

    root:XPDRPRefresh()
    return root
end
