if not CLIENT then return end

XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

local function tx(prefix)
    return XPDRP.Inv.GenerateTx(prefix)
end

local function sendAction(payload)
    payload.txid = payload.txid or tx(payload.action or "tx")
    net.Start("XPDRP.Inv.Action")
    net.WriteTable(payload)
    net.SendToServer()
end

net.Receive("XPDRP.Inv.Sync", function()
    local data = net.ReadTable() or {}
    XPDRP.Inv.State = data
end)

local function requestSync()
    net.Start("XPDRP.Inv.RequestSync")
    net.SendToServer()
end

local function getStateItemsArray()
    local out = {}
    local state = XPDRP.Inv.State or {}
    local items = state.items or {}
    for _, slot in ipairs(state.slots or {}) do
        local item = items[slot.id]
        if item then
            out[#out + 1] = {
                id = slot.id,
                name = item.name,
                model = item.model,
                category = item.category,
                qty = slot.qty,
                value = (item.value or 0) * (slot.qty or 0),
                description = item.description or ""
            }
        end
    end
    XPDRP.Inv.SortByName(out, function(it) return it.name end)
    return out
end

local function getRecipeArray()
    local out = {}
    for _, recipe in pairs((XPDRP.Inv.State and XPDRP.Inv.State.recipes) or {}) do
        out[#out + 1] = recipe
    end
    XPDRP.Inv.SortByName(out, function(it) return it.name end)
    return out
end

local function getTraderOffers(mode)
    local out = {}
    local state = XPDRP.Inv.State or {}
    for traderId, trader in pairs(state.traders or {}) do
        local list = mode == "buy" and (trader.sells or {}) or (trader.buys or {})
        for idx, offer in ipairs(list) do
            local item = state.items and state.items[offer.id]
            out[#out + 1] = {
                traderId = traderId,
                traderName = trader.name,
                offerIndex = idx,
                id = offer.id,
                name = item and item.name or offer.id,
                model = item and item.model or "models/error.mdl",
                qty = offer.qty,
                price = offer.price,
                description = "x" .. tostring(offer.qty) .. " | " .. XPDRP.Inv.FormatMoney(offer.price)
            }
        end
    end
    XPDRP.Inv.SortByName(out, function(it) return it.name end)
    return out
end

local function createCustomTab(sheet, UI)
    local root = vgui.Create("EditablePanel", sheet)
    root.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local wrap = vgui.Create("EditablePanel", root)
    wrap:Dock(FILL)
    wrap:DockMargin(14, 14, 14, 14)

    local function makeEntry(placeholder)
        local e = vgui.Create("XPTextEntry", wrap)
        e:Dock(TOP)
        e:DockMargin(0, 0, 0, 8)
        e:SetTall(32)
        e:SetPlaceholderText(placeholder)
        return e
    end

    local name = makeEntry("Название")
    local category = makeEntry("Категория")
    local model = makeEntry("Модель (models/...)")
    local maxStack = makeEntry("Макс. стак")
    local value = makeEntry("Цена")
    local desc = makeEntry("Описание")

    local btn = vgui.Create("DButton", wrap)
    btn:Dock(TOP)
    btn:SetTall(40)
    btn:SetText("Создать предмет")
    btn.DoClick = function()
        sendAction({
            action = "custom_create",
            name = name:GetValue(),
            category = category:GetValue(),
            model = model:GetValue(),
            maxStack = tonumber(maxStack:GetValue()) or 1,
            value = tonumber(value:GetValue()) or 100,
            description = desc:GetValue()
        })
    end

    return root
end

local function createAdminTab(sheet, UI)
    local root = vgui.Create("EditablePanel", sheet)
    root.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local wrap = vgui.Create("EditablePanel", root)
    wrap:Dock(FILL)
    wrap:DockMargin(14, 14, 14, 14)

    local function makeEntry(placeholder)
        local e = vgui.Create("XPTextEntry", wrap)
        e:Dock(TOP)
        e:DockMargin(0, 0, 0, 8)
        e:SetTall(32)
        e:SetPlaceholderText(placeholder)
        return e
    end

    local sid = makeEntry("SteamID64 игрока")
    local itemId = makeEntry("ID предмета")
    local qty = makeEntry("Количество")

    local give = vgui.Create("DButton", wrap)
    give:Dock(TOP)
    give:DockMargin(0, 0, 0, 6)
    give:SetTall(38)
    give:SetText("Выдать")
    give.DoClick = function()
        sendAction({
            action = "admin",
            mode = "give",
            targetSid64 = sid:GetValue(),
            itemId = itemId:GetValue(),
            qty = tonumber(qty:GetValue()) or 1
        })
    end

    local take = vgui.Create("DButton", wrap)
    take:Dock(TOP)
    take:SetTall(38)
    take:SetText("Забрать")
    take.DoClick = function()
        sendAction({
            action = "admin",
            mode = "take",
            targetSid64 = sid:GetValue(),
            itemId = itemId:GetValue(),
            qty = tonumber(qty:GetValue()) or 1
        })
    end

    return root
end

function XPDRP.Inv.BuildF4InventoryTab(sheet, helpers, UI)
    requestSync()

    local root = vgui.Create("EditablePanel", sheet)
    root.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, UI.Bg)
        surface.SetDrawColor(UI.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local sub = vgui.Create("XPPropertySheet", root)
    sub:Dock(FILL)
    sub:DockMargin(6, 6, 6, 6)

    sub:AddSheet("Сумка", helpers.createCatalogTab(sub, {
        buttonText = "Обновить",
        getItems = function() return getStateItemsArray() end,
        getGroup = function(it) return it.category or "Инвентарь" end,
        getTitle = function(it) return XPDRP.Inv.SafeText(it.name) end,
        getSubtitle = function(it) return "ID: " .. XPDRP.Inv.SafeText(it.id) .. " | x" .. tostring(it.qty) end,
        getValue = function(it) return XPDRP.Inv.FormatMoney(it.value or 0) end,
        getDescription = function(it) return XPDRP.Inv.SafeText(it.description) end,
        getModel = function(it) return it.model end,
        onUse = function() requestSync() end
    }))

    sub:AddSheet("Крафт", helpers.createCatalogTab(sub, {
        buttonText = "Скрафтить",
        getItems = function() return getRecipeArray() end,
        getGroup = function(it) return it.station or "Крафт" end,
        getTitle = function(it) return XPDRP.Inv.SafeText(it.name) end,
        getSubtitle = function(it)
            local result = it.result or {}
            return "Результат: " .. XPDRP.Inv.SafeText(result.id) .. " x" .. tostring(result.qty or 1)
        end,
        getValue = function() return "" end,
        getDescription = function(it)
            local parts = {}
            for _, ingredient in ipairs(it.ingredients or {}) do
                parts[#parts + 1] = XPDRP.Inv.SafeText(ingredient.id) .. " x" .. tostring(ingredient.qty)
            end
            return "Нужно: " .. table.concat(parts, ", ")
        end,
        getModel = function(it)
            local result = it.result or {}
            local map = (XPDRP.Inv.State and XPDRP.Inv.State.items) or {}
            local item = map[result.id]
            return item and item.model or "models/error.mdl"
        end,
        onUse = function(it) sendAction({ action = "craft", recipeId = it.id }) end
    }))

    sub:AddSheet("Торговля: купить", helpers.createCatalogTab(sub, {
        buttonText = "Купить",
        getItems = function() return getTraderOffers("buy") end,
        getGroup = function(it) return it.traderName end,
        getTitle = function(it) return XPDRP.Inv.SafeText(it.name) end,
        getSubtitle = function(it) return "x" .. tostring(it.qty) .. " | " .. XPDRP.Inv.SafeText(it.id) end,
        getValue = function(it) return XPDRP.Inv.FormatMoney(it.price or 0) end,
        getDescription = function(it) return XPDRP.Inv.SafeText(it.description) end,
        getModel = function(it) return it.model end,
        onUse = function(it) sendAction({ action = "trader_buy", traderId = it.traderId, offerIndex = it.offerIndex }) end
    }))

    sub:AddSheet("Торговля: продать", helpers.createCatalogTab(sub, {
        buttonText = "Продать",
        getItems = function() return getTraderOffers("sell") end,
        getGroup = function(it) return it.traderName end,
        getTitle = function(it) return XPDRP.Inv.SafeText(it.name) end,
        getSubtitle = function(it) return "x" .. tostring(it.qty) .. " | " .. XPDRP.Inv.SafeText(it.id) end,
        getValue = function(it) return XPDRP.Inv.FormatMoney(it.price or 0) end,
        getDescription = function(it) return XPDRP.Inv.SafeText(it.description) end,
        getModel = function(it) return it.model end,
        onUse = function(it) sendAction({ action = "trader_sell", traderId = it.traderId, offerIndex = it.offerIndex }) end
    }))

    sub:AddSheet("Кастом", createCustomTab(sub, UI))
    sub:AddSheet("Админ", createAdminTab(sub, UI))

    return root
end