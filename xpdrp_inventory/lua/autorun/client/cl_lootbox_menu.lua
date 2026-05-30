if not CLIENT then return end

XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}
XPDRP.UI = XPDRP.UI or {}

local frame
local current
local Theme = XPDRP.UI

local function rarityInfo(id)
    if Theme and Theme.GetRarityInfo then
        return Theme.GetRarityInfo(id)
    end
    return { Color = Color(82, 162, 255), Label = "Обычный" }
end

local function sendClaim(lootIndex, qty)
    if not current then return end
    net.Start("XPDRP.Inv.LootBoxClaim")
    net.WriteTable({
        sessionId = current.sessionId,
        entIndex = current.entIndex,
        lootIndex = lootIndex,
        qty = qty
    })
    net.SendToServer()
end

local function requestRefresh()
    net.Start("XPDRP.Inv.LootBoxRefresh")
    net.SendToServer()
end

local function buildMenu(payload)
    current = payload
    if IsValid(frame) then frame:Remove() end

    frame = vgui.Create("XPFrame")
    frame:SetTitle("Лутбокс: " .. tostring(payload.boxName or payload.boxId or ""))
    frame:SetSize(math.min(ScrW() * 0.72, 1200), math.min(ScrH() * 0.82, 860))
    frame:Center()
    frame:MakePopup()

    local root = vgui.Create("EditablePanel", frame)
    root:Dock(FILL)
    root:DockMargin(6, 6, 6, 6)
    root.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(10, 14, 22, 230))
        surface.SetDrawColor(255, 255, 255, 14)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local header = vgui.Create("DPanel", root)
    header:Dock(TOP)
    header:SetTall(42)
    header:DockMargin(10, 10, 10, 8)
    header.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(7, 13, 21, 220))
        draw.RoundedBox(8, 0, 0, w, 3, Color(82, 162, 255, 85))
        surface.SetDrawColor(255, 255, 255, 14)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Перетаскивай лут в инвентарь", "xpgui_medium", 10, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Drag & Drop", "xpgui_tiny", w - 10, h * 0.5, Color(174, 191, 214), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
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
    search:SetWide(260)
    search:SetPlaceholderText("Поиск в лутбоксе")

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

    local left = vgui.Create("DPanel", body)
    left:Dock(LEFT)
    left:SetWide(620)
    left.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(12, 17, 27, 236))
        draw.RoundedBox(10, 0, 0, w, 3, Color(82, 162, 255, 70))
        surface.SetDrawColor(255, 255, 255, 12)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local right = vgui.Create("DPanel", body)
    right:Dock(FILL)
    right:DockMargin(10, 0, 0, 0)
    right.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(12, 17, 27, 236))
        draw.RoundedBox(10, 0, 0, w, 3, Color(112, 214, 136, 80))
        surface.SetDrawColor(255, 255, 255, 12)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local lLabel = vgui.Create("DLabel", left)
    lLabel:Dock(TOP)
    lLabel:DockMargin(10, 10, 10, 6)
    lLabel:SetTall(22)
    lLabel:SetFont("xpgui_medium")
    lLabel:SetTextColor(color_white)
    lLabel:SetText("Содержимое")

    local rLabel = vgui.Create("DLabel", right)
    rLabel:Dock(TOP)
    rLabel:DockMargin(10, 10, 10, 6)
    rLabel:SetTall(22)
    rLabel:SetFont("xpgui_medium")
    rLabel:SetTextColor(color_white)
    rLabel:SetText("Инвентарь (зона приема)")

    local leftScroll = vgui.Create("XPScrollPanel", left)
    leftScroll:Dock(FILL)
    leftScroll:DockMargin(10, 0, 10, 10)

    local leftGrid = vgui.Create("DIconLayout", leftScroll)
    leftGrid:Dock(TOP)
    leftGrid:SetSpaceX(8)
    leftGrid:SetSpaceY(8)

    local invZone = vgui.Create("DPanel", right)
    invZone:Dock(FILL)
    invZone:DockMargin(10, 0, 10, 10)
    invZone.Paint = function(self, w, h)
        self.H = Lerp(FrameTime() * 16, self.H or 0, self:IsHovered() and 1 or 0)
        draw.RoundedBox(8, 0, 0, w, h, Color(6, 12, 20, 210))
        draw.RoundedBox(8, 0, 0, w, 3, Color(112, 214, 136, 80 + 80 * self.H))
        surface.SetDrawColor(112, 214, 136, 30 + 60 * self.H)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.SimpleText("Бросай предметы сюда", "xpgui_medium", w * 0.5, h * 0.5 - 10, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("чтобы забрать в сумку", "xpgui_tiny", w * 0.5, h * 0.5 + 14, Color(174, 191, 214), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    invZone:Receiver("XPDRP_LOOT_DRAG", function(_, panels, dropped)
        if not dropped then return end
        local pnl = panels and panels[1]
        if not IsValid(pnl) then return end
        local idx = tonumber(pnl.LootIndex or 0)
        if idx <= 0 then return end
        sendClaim(idx, math.max(1, tonumber(pnl.LootQty or 1) or 1))
    end)

    local function rebuildDrops()
        leftGrid:Clear()
        local q = string.lower(string.Trim(search:GetValue() or ""))

        for idx, drop in ipairs(payload.drops or {}) do
            local item = payload.items and payload.items[drop.itemId]
            local name = item and item.name or tostring(drop.itemId)
            local r = item and item.rarity or "common"
            local passR = selectedRarity == "all" or selectedRarity == r
            local passQ = q == "" or string.find(string.lower(tostring(name)), q, 1, true)
            if passR and passQ then
                local cube = leftGrid:Add("DButton")
                cube:SetSize(110, 118)
                cube:SetText("")
                cube.LootIndex = idx
                cube.LootQty = tonumber(drop.qty) or 1
                cube:Droppable("XPDRP_LOOT_DRAG")

                local icon = vgui.Create("SpawnIcon", cube)
                icon:Dock(FILL)
                icon:DockMargin(8, 8, 8, 28)
                icon:SetModel((item and item.model) or "models/error.mdl")
                icon:SetMouseInputEnabled(false)

                cube.Paint = function(self, w, h)
                    local hov = self:IsHovered()
                    local rare = rarityInfo(r)
                    local rc = (rare and rare.Color) or Color(82, 162, 255)
                    local rLabel = (rare and rare.Label) or "Обычный"
                    draw.RoundedBox(8, 0, 0, w, h, hov and Color(255, 255, 255, 18) or Color(255, 255, 255, 10))
                    draw.RoundedBox(8, 0, 0, w, 3, Color(rc.r, rc.g, rc.b, hov and 110 or 58))
                    draw.RoundedBox(0, 0, h - 24, w, 24, Color(6, 10, 16, 230))
                    surface.SetDrawColor(255, 255, 255, hov and 34 or 16)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    surface.SetDrawColor(rc.r, rc.g, rc.b, 35)
                    surface.DrawRect(0, 0, 8, h)

                    draw.SimpleText(name, "xpgui_tiny", 8, h - 12, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("x" .. tostring(drop.qty), "xpgui_medium", w - 8, h - 12, Color(112, 214, 136), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    draw.SimpleText(rLabel, "xpgui_tiny", w - 8, 9, Color(rc.r, rc.g, rc.b, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                end
            end
        end
        leftGrid:InvalidateLayout(true)
    end

    search.OnValueChange = rebuildDrops
    rarity.OnSelect = function(_, _, _, data)
        selectedRarity = tostring(data or "all")
        rebuildDrops()
    end

    rebuildDrops()

    local refreshBtn = vgui.Create("DButton", root)
    refreshBtn:Dock(BOTTOM)
    refreshBtn:DockMargin(10, 0, 10, 10)
    refreshBtn:SetTall(36)
    refreshBtn:SetText("")
    refreshBtn.Paint = function(self, w, h)
        self.H = Lerp(FrameTime() * 14, self.H or 0, self:IsHovered() and 1 or 0)
        draw.RoundedBox(8, 0, 0, w, h, Color(6, 12, 20, 230))
        draw.RoundedBox(8, 1, 1, w - 2, h - 2, Color(82, 162, 255, 80 + self.H * 80))
        draw.RoundedBox(8, 1, 1, w - 2, math.floor(h * 0.45), Color(145, 210, 255, 30 + self.H * 55))
        surface.SetDrawColor(255, 255, 255, 16 + self.H * 20)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Обновить окно", "xpgui_medium", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("R", "xpgui_big", w - 12, h * 0.5 - 1, Color(220, 240, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    refreshBtn.DoClick = requestRefresh
end

net.Receive("XPDRP.Inv.OpenLootBox", function()
    buildMenu(net.ReadTable() or {})
end)