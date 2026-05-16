if SERVER then return end

local lootFrame
local adminFrame
local payload = {
    profiles = {},
    profileIds = {},
    itemIds = {}
}

surface.CreateFont("NexusLootTitle", {
    font = "Roboto",
    size = 30,
    weight = 900,
    antialias = true
})

surface.CreateFont("NexusLootSub", {
    font = "Roboto",
    size = 15,
    weight = 500,
    antialias = true
})

surface.CreateFont("NexusLootCardTitle", {
    font = "Roboto",
    size = 18,
    weight = 700,
    antialias = true
})

surface.CreateFont("NexusLootCardMeta", {
    font = "Roboto",
    size = 13,
    weight = 500,
    antialias = true
})

local function sendAdminAction(action, data)
    net.Start("nexus_lootbin_admin_action")
    net.WriteString(action)
    net.WriteString(util.TableToJSON(data or {}, false) or "{}")
    net.SendToServer()
end

local function formatRefresh(sec)
    sec = math.max(0, tonumber(sec) or 0)
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d", m, s)
end

local function openLootUI(ent, binName, itemRows, refreshLeft)
    if IsValid(lootFrame) then lootFrame:Remove() end

    itemRows = istable(itemRows) and itemRows or {}
    table.sort(itemRows, function(a, b)
        local an = tostring(a.name or a.id or "")
        local bn = tostring(b.name or b.id or "")
        if an == bn then return tostring(a.id or "") < tostring(b.id or "") end
        return an < bn
    end)

    lootFrame = vgui.Create("DFrame")
    lootFrame:SetSize(860, 620)
    lootFrame:Center()
    lootFrame:SetTitle("")
    lootFrame:ShowCloseButton(false)
    lootFrame:SetDraggable(false)
    lootFrame:MakePopup()

    lootFrame.refreshEndsAt = CurTime() + (tonumber(refreshLeft) or 0)
    lootFrame.Paint = function(self, w, h)
        draw.RoundedBox(16, 0, 0, w, h, Color(12, 14, 22, 248))
        draw.RoundedBox(0, 0, 86, w, 1, Color(255, 255, 255, 14))
        draw.SimpleText(binName or "Мусорка", "NexusLootTitle", 20, 30, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Лут сразу уходит в ваш инвентарь", "NexusLootSub", 20, 58, Color(148, 214, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Обновление: " .. formatRefresh(math.ceil(self.refreshEndsAt - CurTime())), "NexusLootSub", w - 20, 58, Color(170, 184, 214), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", lootFrame)
    closeBtn:SetPos(lootFrame:GetWide() - 46, 12)
    closeBtn:SetSize(30, 24)
    closeBtn:SetText("X")
    closeBtn:SetFont("NexusLootSub")
    closeBtn:SetTextColor(color_white)
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(64, 74, 104, self:IsHovered() and 245 or 220))
    end
    closeBtn.DoClick = function() lootFrame:Remove() end

    local body = vgui.Create("DScrollPanel", lootFrame)
    body:SetPos(14, 98)
    body:SetSize(lootFrame:GetWide() - 28, lootFrame:GetTall() - 112)

    local grid = vgui.Create("DIconLayout", body)
    grid:Dock(FILL)
    grid:SetSpaceX(12)
    grid:SetSpaceY(12)

    if #itemRows == 0 then
        local empty = vgui.Create("DPanel")
        empty:SetSize(816, 76)
        empty.Paint = function(_, w, h)
            draw.RoundedBox(12, 0, 0, w, h, Color(30, 35, 52, 232))
            draw.SimpleText("Мусорка пустая. Ждите следующего обновления.", "NexusLootCardTitle", w * 0.5, h * 0.5, Color(206, 214, 232), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        grid:Add(empty)
        return
    end

    for _, row in ipairs(itemRows) do
        local itemId = tostring(row.id or "")
        local amount = tonumber(row.amount or 0) or 0
        local itemName = tostring(row.name or itemId)

        local card = vgui.Create("DButton")
        card:SetSize(260, 92)
        card:SetText("")
        card.hover = 0
        card.Paint = function(self, w, h)
            self.hover = Lerp(FrameTime() * 10, self.hover, self:IsHovered() and 1 or 0)
            local r = Lerp(self.hover, 32, 50)
            local g = Lerp(self.hover, 38, 66)
            local b = Lerp(self.hover, 58, 106)

            draw.RoundedBox(12, 0, 0, w, h, Color(r, g, b, 238))
            draw.SimpleText(itemName, "NexusLootCardTitle", 14, 28, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("ID: " .. itemId, "NexusLootCardMeta", 14, 48, Color(168, 182, 214), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Количество: x" .. tostring(amount), "NexusLootCardMeta", 14, 66, Color(186, 198, 224), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Забрать в инвентарь", "NexusLootCardMeta", w - 14, h - 16, Color(150, 230, 176), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        card.DoClick = function()
            net.Start("nexus_lootbin_take")
            net.WriteEntity(ent)
            net.WriteString(itemId)
            net.SendToServer()
        end

        grid:Add(card)
    end
end

local function openAdminUI()
    if IsValid(adminFrame) then adminFrame:Remove() end

    adminFrame = vgui.Create("DFrame")
    adminFrame:SetSize(1080, 660)
    adminFrame:Center()
    adminFrame:SetTitle("")
    adminFrame:ShowCloseButton(false)
    adminFrame:SetDraggable(false)
    adminFrame:MakePopup()

    adminFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(16, 18, 26, 238))
        draw.SimpleText("NEXUS LOOTBINS ADMIN", "DermaLarge", 16, 22, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", adminFrame)
    closeBtn:SetPos(adminFrame:GetWide() - 42, 10)
    closeBtn:SetSize(30, 24)
    closeBtn:SetText("X")
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(62, 72, 98, self:IsHovered() and 240 or 214))
    end
    closeBtn.DoClick = function() adminFrame:Remove() end

    local profiles = vgui.Create("DListView", adminFrame)
    profiles:SetPos(12, 52)
    profiles:SetSize(320, adminFrame:GetTall() - 64)
    profiles:AddColumn("Profile ID")
    profiles:AddColumn("Name")

    local right = vgui.Create("DPanel", adminFrame)
    right:SetPos(340, 52)
    right:SetSize(adminFrame:GetWide() - 352, adminFrame:GetTall() - 64)
    right.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(23, 27, 39, 235))
    end

    local selected

    local idEntry = vgui.Create("DTextEntry", right)
    idEntry:SetPos(10, 10)
    idEntry:SetSize(180, 26)
    idEntry:SetPlaceholderText("profile_id")

    local nameEntry = vgui.Create("DTextEntry", right)
    nameEntry:SetPos(196, 10)
    nameEntry:SetSize(220, 26)
    nameEntry:SetPlaceholderText("Имя")

    local modelEntry = vgui.Create("DTextEntry", right)
    modelEntry:SetPos(10, 40)
    modelEntry:SetSize(406, 26)
    modelEntry:SetPlaceholderText("Модель")

    local minEntry = vgui.Create("DTextEntry", right)
    minEntry:SetPos(10, 70)
    minEntry:SetSize(70, 26)
    minEntry:SetValue("2")

    local maxEntry = vgui.Create("DTextEntry", right)
    maxEntry:SetPos(86, 70)
    maxEntry:SetSize(70, 26)
    maxEntry:SetValue("5")

    local saveProfile = vgui.Create("DButton", right)
    saveProfile:SetPos(162, 70)
    saveProfile:SetSize(128, 26)
    saveProfile:SetText("Сохранить")
    saveProfile.DoClick = function()
        local pid = string.Trim(idEntry:GetValue() or "")
        if pid == "" then return end
        sendAdminAction("profile_upsert", {
            profileId = pid,
            name = string.Trim(nameEntry:GetValue() or ""),
            model = string.Trim(modelEntry:GetValue() or ""),
            rollsMin = tonumber(minEntry:GetValue()) or 2,
            rollsMax = tonumber(maxEntry:GetValue()) or 5
        })
    end

    local removeProfile = vgui.Create("DButton", right)
    removeProfile:SetPos(296, 70)
    removeProfile:SetSize(120, 26)
    removeProfile:SetText("Удалить")
    removeProfile.DoClick = function()
        local pid = selected or string.Trim(idEntry:GetValue() or "")
        if pid == "" then return end
        sendAdminAction("profile_remove", { profileId = pid })
    end

    local spawnBtn = vgui.Create("DButton", right)
    spawnBtn:SetPos(422, 10)
    spawnBtn:SetSize(180, 26)
    spawnBtn:SetText("Спавн мусорки")
    spawnBtn.DoClick = function()
        local pid = selected or string.Trim(idEntry:GetValue() or "")
        if pid == "" then return end
        sendAdminAction("spawn_bin", { profileId = pid })
    end

    local itemBox = vgui.Create("DComboBox", right)
    itemBox:SetPos(10, 106)
    itemBox:SetSize(180, 26)
    itemBox:SetValue("Item ID")
    for _, id in ipairs(payload.itemIds or {}) do itemBox:AddChoice(id) end

    local minLoot = vgui.Create("DTextEntry", right)
    minLoot:SetPos(196, 106)
    minLoot:SetSize(60, 26)
    minLoot:SetValue("1")

    local maxLoot = vgui.Create("DTextEntry", right)
    maxLoot:SetPos(262, 106)
    maxLoot:SetSize(60, 26)
    maxLoot:SetValue("1")

    local weight = vgui.Create("DTextEntry", right)
    weight:SetPos(328, 106)
    weight:SetSize(60, 26)
    weight:SetValue("10")

    local chance = vgui.Create("DTextEntry", right)
    chance:SetPos(394, 106)
    chance:SetSize(60, 26)
    chance:SetValue("100")

    local addPool = vgui.Create("DButton", right)
    addPool:SetPos(460, 106)
    addPool:SetSize(142, 26)
    addPool:SetText("В пул")
    addPool.DoClick = function()
        local pid = selected or string.Trim(idEntry:GetValue() or "")
        local itemId = itemBox:GetValue()
        if pid == "" or itemId == "" or itemId == "Item ID" then return end
        sendAdminAction("pool_upsert", {
            profileId = pid,
            itemId = itemId,
            min = tonumber(minLoot:GetValue()) or 1,
            max = tonumber(maxLoot:GetValue()) or 1,
            weight = tonumber(weight:GetValue()) or 1,
            chance = tonumber(chance:GetValue()) or 100
        })
    end

    local poolList = vgui.Create("DListView", right)
    poolList:SetPos(10, 140)
    poolList:SetSize(right:GetWide() - 20, right:GetTall() - 150)
    poolList:AddColumn("Item ID")
    poolList:AddColumn("Min")
    poolList:AddColumn("Max")
    poolList:AddColumn("Weight")
    poolList:AddColumn("Chance %")

    local rows = {}
    for id, prof in pairs(payload.profiles or {}) do
        rows[#rows + 1] = { id = id, name = prof.name or "Мусорка" }
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    for _, row in ipairs(rows) do profiles:AddLine(row.id, row.name) end

    local function fillPool(pid)
        poolList:Clear()
        local prof = payload.profiles and payload.profiles[pid] or nil
        if not prof then return end
        for _, row in ipairs(prof.pool or {}) do
            poolList:AddLine(
                row.id or "",
                tostring(row.min or 1),
                tostring(row.max or 1),
                tostring(row.weight or 1),
                tostring(row.chance == nil and 100 or row.chance)
            )
        end
    end

    profiles.OnRowSelected = function(_, _, line)
        selected = line:GetColumnText(1)
        local prof = payload.profiles and payload.profiles[selected]
        if not prof then return end
        idEntry:SetValue(selected)
        nameEntry:SetValue(prof.name or "")
        modelEntry:SetValue(prof.model or "")
        minEntry:SetValue(tostring(prof.rollsMin or 2))
        maxEntry:SetValue(tostring(prof.rollsMax or 5))
        fillPool(selected)
    end

    poolList.OnRowRightClick = function(_, _, line)
        if not selected then return end
        local itemId = line:GetColumnText(1)
        local menu = DermaMenu()
        menu:AddOption("Удалить", function()
            sendAdminAction("pool_remove", {
                profileId = selected,
                itemId = itemId
            })
        end)
        menu:Open()
    end
end

net.Receive("nexus_lootbin_open", function()
    local ent = net.ReadEntity()
    local binName = net.ReadString()
    local rows = util.JSONToTable(net.ReadString() or "[]") or {}
    local refreshLeft = net.ReadUInt(16)
    openLootUI(ent, binName, rows, refreshLeft)
end)

net.Receive("nexus_lootbin_admin_open", function()
    openAdminUI()
end)

net.Receive("nexus_lootbin_admin_sync", function()
    payload = util.JSONToTable(net.ReadString() or "{}") or payload
    payload.profiles = payload.profiles or {}
    payload.profileIds = payload.profileIds or {}
    payload.itemIds = payload.itemIds or {}

    if IsValid(adminFrame) then
        openAdminUI()
    end
end)