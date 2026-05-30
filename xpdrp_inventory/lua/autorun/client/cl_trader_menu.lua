if not CLIENT then return end

XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}
XPDRP.UI = XPDRP.UI or {}

local traderFrame
local Theme = XPDRP.UI

local function rarityInfo(id)
    if Theme and Theme.GetRarityInfo then
        return Theme.GetRarityInfo(id)
    end
    return { Color = Color(82, 162, 255), Label = "Обычный" }
end

local function fmtMoney(v)
    if XPDRP.Inv and XPDRP.Inv.FormatMoney then
        return XPDRP.Inv.FormatMoney(v)
    end
    return tostring(v)
end

local function sendAction(payload)
    payload.txid = payload.txid or ((XPDRP.Inv and XPDRP.Inv.GenerateTx and XPDRP.Inv.GenerateTx(payload.action)) or tostring(os.time()))
    net.Start("XPDRP.Inv.Action")
    net.WriteTable(payload)
    net.SendToServer()
end

local function requestTrader(traderId, traderEnt)
    net.Start("XPDRP.Inv.RequestTrader")
    net.WriteString(traderId)
    net.WriteUInt(math.max(0, tonumber(traderEnt) or 0), 16)
    net.SendToServer()
end

local function makeOfferRow(parent, cfg)
    local row = vgui.Create("EditablePanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 8)
    row:SetTall(68)
    row.Hov = 0

    local icon = vgui.Create("SpawnIcon", row)
    icon:SetPos(8, 8)
    icon:SetSize(52, 52)
    icon:SetModel(cfg.model or "models/error.mdl")
    icon:SetMouseInputEnabled(false)

    local action = vgui.Create("DButton", row)
    action:Dock(RIGHT)
    action:SetWide(134)
    action:DockMargin(0, 8, 8, 8)
    action:SetText("")
    action.Paint = function(self, w, h)
        self.H = Lerp(FrameTime() * 14, self.H or 0, self:IsHovered() and 1 or 0)
        local col = cfg.actionColor or Color(82, 162, 255)
        draw.RoundedBox(0, 0, 0, w, h, Color(6, 12, 20, 230))
        draw.RoundedBox(0, 1, 1, w - 2, h - 2, Color(col.r, col.g, col.b, 90 + 70 * self.H))
        draw.SimpleText(cfg.actionText or "Выбрать", "xpgui_tiny", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    action.DoClick = cfg.onClick

    local clicker = vgui.Create("DButton", row)
    clicker:Dock(FILL)
    clicker:DockMargin(68, 8, 8 + action:GetWide() + 8, 8)
    clicker:SetText("")
    clicker.DoClick = cfg.onClick

    row.Paint = function(self, w, h)
        self.Hov = Lerp(FrameTime() * 14, self.Hov or 0, (clicker:IsHovered() or action:IsHovered()) and 1 or 0)
        local rare = rarityInfo(cfg.rarity)
        local rc = (rare and rare.Color) or Color(82, 162, 255)
        local rLabel = (rare and rare.Label) or "Обычный"
        draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 9 + self.Hov * 10))
        draw.RoundedBox(6, 0, 0, w, 3, Color(rc.r, rc.g, rc.b, 40 + self.Hov * 80))
        surface.SetDrawColor(rc.r, rc.g, rc.b, 35)
        surface.DrawRect(0, 0, 8, h)
        surface.SetDrawColor(255, 255, 255, 14 + self.Hov * 14)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText(cfg.title or "Предмет", "xpgui_medium", 68, 16, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.subtitle or "", "xpgui_tiny", 68, 40, Color(174, 191, 214), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(cfg.priceText or "", "xpgui_medium", w - 148, 16, Color(112, 214, 136), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(rLabel, "xpgui_tiny", w - 148, 39, Color(rc.r, rc.g, rc.b, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    return row
end

local function openTraderMenu(payload)
    if IsValid(traderFrame) then traderFrame:Remove() end

    local traderId = tostring(payload.traderId or "")
    local trader = payload.trader or {}
    local traderEnt = tonumber(payload.traderEnt or 0) or 0
    local items = payload.items or {}
    local counts = payload.counts or {}

    traderFrame = vgui.Create("XPFrame")
    traderFrame:SetTitle("Торговец: " .. tostring(trader.name or traderId))
    traderFrame:SetSize(math.min(ScrW() * 0.72, 1100), math.min(ScrH() * 0.82, 820))
    traderFrame:Center()
    traderFrame:MakePopup()

    local root = vgui.Create("EditablePanel", traderFrame)
    root:Dock(FILL)
    root:DockMargin(6, 6, 6, 6)
    root.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(10, 14, 22, 230))
        surface.SetDrawColor(255, 255, 255, 12)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local top = vgui.Create("DPanel", root)
    top:Dock(TOP)
    top:SetTall(44)
    top:DockMargin(12, 8, 12, 8)
    top.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(7, 13, 21, 220))
        draw.RoundedBox(8, 0, 0, w, 3, Color(82, 162, 255, 85))
        surface.SetDrawColor(255, 255, 255, 14)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Баланс: " .. fmtMoney(payload.balance or 0), "xpgui_medium", 10, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Shift+E рядом с NPC", "xpgui_tiny", w - 10, h * 0.5, Color(173, 190, 212), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local body = vgui.Create("EditablePanel", root)
    body:Dock(FILL)
    body:DockMargin(10, 0, 10, 10)

    local controls = vgui.Create("DPanel", body)
    controls:Dock(TOP)
    controls:SetTall(40)
    controls:DockMargin(0, 0, 0, 8)
    controls.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(7, 13, 21, 220))
        surface.SetDrawColor(255, 255, 255, 12)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local search = vgui.Create("XPTextEntry", controls)
    search:Dock(LEFT)
    search:DockMargin(8, 5, 0, 5)
    search:SetWide(280)
    search:SetPlaceholderText("Поиск по торговцу")

    local rarity = vgui.Create("DComboBox", controls)
    rarity:Dock(LEFT)
    rarity:DockMargin(8, 5, 0, 5)
    rarity:SetWide(170)
    rarity:SetValue("Редкость: Все")
    rarity:AddChoice("Редкость: Все", "all")
    rarity:AddChoice("Обычный", "common")
    rarity:AddChoice("Необычный", "uncommon")
    rarity:AddChoice("Редкий", "rare")
    rarity:AddChoice("Эпический", "epic")
    rarity:AddChoice("Легендарный", "legendary")

    local selectedRarity = "all"

    local sub = vgui.Create("XPPropertySheet", body)
    sub:Dock(FILL)

    local buyTab = vgui.Create("DPanel", sub)
    buyTab.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(12, 17, 27, 236))
    end
    local buyScroll = vgui.Create("XPScrollPanel", buyTab)
    buyScroll:Dock(FILL)
    buyScroll:DockMargin(10, 10, 10, 10)

    local function rebuildBuy()
        buyScroll:Clear()
        local q = string.lower(string.Trim(search:GetValue() or ""))
        for idx, offer in ipairs(trader.sells or {}) do
            local item = items[offer.id]
            local name = item and item.name or offer.id
            local r = item and item.rarity or "common"
            local passR = selectedRarity == "all" or selectedRarity == r
            local passQ = q == "" or string.find(string.lower(tostring(name)), q, 1, true)
            if passR and passQ then
                makeOfferRow(buyScroll, {
                    model = item and item.model or "models/error.mdl",
                    title = name,
                    subtitle = "Количество: x" .. tostring(offer.qty),
                    rarity = r,
                    priceText = fmtMoney(offer.price),
                    actionText = "Купить",
                    actionColor = Color(82, 162, 255),
                    onClick = function()
                        sendAction({ action = "trader_buy", traderId = traderId, traderEnt = traderEnt, offerIndex = idx })
                        timer.Simple(0.1, function() requestTrader(traderId, traderEnt) end)
                    end
                })
            end
        end
    end

    local sellTab = vgui.Create("DPanel", sub)
    sellTab.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(12, 17, 27, 236))
    end
    local sellScroll = vgui.Create("XPScrollPanel", sellTab)
    sellScroll:Dock(FILL)
    sellScroll:DockMargin(10, 10, 10, 10)

    local function rebuildSell()
        sellScroll:Clear()
        local q = string.lower(string.Trim(search:GetValue() or ""))
        for idx, offer in ipairs(trader.buys or {}) do
            local item = items[offer.id]
            local have = counts[offer.id] or 0
            local name = item and item.name or offer.id
            local r = item and item.rarity or "common"
            local passR = selectedRarity == "all" or selectedRarity == r
            local passQ = q == "" or string.find(string.lower(tostring(name)), q, 1, true)
            if passR and passQ then
                makeOfferRow(sellScroll, {
                    model = item and item.model or "models/error.mdl",
                    title = name,
                    subtitle = "Нужно: x" .. tostring(offer.qty) .. " | У тебя: " .. tostring(have),
                    rarity = r,
                    priceText = fmtMoney(offer.price),
                    actionText = "Продать",
                    actionColor = Color(112, 214, 136),
                    onClick = function()
                        sendAction({ action = "trader_sell", traderId = traderId, traderEnt = traderEnt, offerIndex = idx })
                        timer.Simple(0.1, function() requestTrader(traderId, traderEnt) end)
                    end
                })
            end
        end
    end

    sub:AddSheet("Покупка", buyTab)
    sub:AddSheet("Продажа", sellTab)

    local function rebuildAll()
        rebuildBuy()
        rebuildSell()
    end

    search.OnValueChange = rebuildAll
    rarity.OnSelect = function(_, _, _, data)
        selectedRarity = tostring(data or "all")
        rebuildAll()
    end

    rebuildAll()
end

net.Receive("XPDRP.Inv.OpenTrader", function()
    local payload = net.ReadTable() or {}
    openTraderMenu(payload)
end)