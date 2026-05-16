if SERVER then return end

local function cfgValue(group, key, fallback)
    local cfg = NEXUS_PLUS_CONFIG and NEXUS_PLUS_CONFIG[group]
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

surface.CreateFont("NexusPlusDoorBrand", {
    font = "Roboto",
    size = 30,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusPlusDoorText", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true
})

local doorFrame

local function sendDoorAction(actionId, payload)
    net.Start("nexus_plus_door_action")
    net.WriteString(actionId)
    net.WriteString(payload or "")
    net.SendToServer()
end

local function calcDoorMenuHeight(data)
    local y = 118

    if data.ownable and not data.owned then
        y = y + 42
    end

    if data.owned and data.isOwner then
        y = y + 42
        y = y + 40
        y = y + 40
    end

    if data.isSuperAdmin then
        y = y + 22

        for _, action in ipairs(cfgValue("Door", "superadminActions", {})) do
            if action.id ~= "set_group" then
                y = y + 34
            end
        end

        y = y + 36
        y = y + 32
    end

    return y + 16
end

local function openDoorMenu(data)
    if IsValid(doorFrame) then
        doorFrame:Remove()
    end

    local minHeight = cfgValue("Door", "height", 430)
    local dynamicHeight = calcDoorMenuHeight(data)

    doorFrame = vgui.Create("DFrame")
    doorFrame:SetSize(cfgValue("Door", "width", 460), math.max(minHeight, dynamicHeight))
    doorFrame:Center()
    doorFrame:SetTitle("")
    doorFrame:ShowCloseButton(false)
    doorFrame:SetDraggable(false)
    doorFrame:MakePopup()
    doorFrame.anim = 0

    doorFrame.Paint = function(self, w, h)
        self.anim = Lerp(FrameTime() * cfgValue("Door", "openAnimSpeed", 12), self.anim, 1)
        local alpha = math.floor(Lerp(self.anim, 0, 238))
        draw.RoundedBox(12, 0, 0, w, h, Color(16, 18, 26, alpha))
        draw.SimpleText("Управление дверью", "NexusPlusDoorBrand", 16, 28, Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Владельцы: " .. (data.owners ~= "" and data.owners or "нет"), "NexusPlusDoorText", 16, 64, Color(175, 185, 210, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Название: " .. (data.title ~= "" and data.title or "без названия"), "NexusPlusDoorText", 16, 88, Color(175, 185, 210, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", doorFrame)
    closeBtn:SetText("X")
    closeBtn:SetFont("NexusPlusDoorText")
    closeBtn:SetTextColor(color_white)
    closeBtn:SetPos(doorFrame:GetWide() - 42, 10)
    closeBtn:SetSize(30, 24)
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(62, 72, 98, self:IsHovered() and 240 or 214))
    end
    closeBtn.DoClick = function()
        doorFrame:Remove()
    end

    local function addButton(text, y, actionId, payload)
        local btn = vgui.Create("DButton", doorFrame)
        btn:SetText("")
        btn:SetPos(16, y)
        btn:SetSize(doorFrame:GetWide() - 32, 34)
        btn.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(37, 42, 60, self:IsHovered() and 240 or 214))
            draw.SimpleText(text, "NexusPlusDoorText", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            sendDoorAction(actionId, payload)
        end
    end

    local function addAdminButton(text, y, actionId)
        local btn = vgui.Create("DButton", doorFrame)
        btn:SetText("")
        btn:SetPos(16, y)
        btn:SetSize(doorFrame:GetWide() - 32, 30)
        btn.Paint = function(self, w, h)
            draw.RoundedBox(7, 0, 0, w, h, Color(53, 86, 154, self:IsHovered() and 248 or 224))
            draw.SimpleText(text, "NexusPlusDoorText", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            net.Start("nexus_plus_door_admin")
            net.WriteString(actionId)
            net.SendToServer()
        end
    end

    local y = 118
    if data.ownable and not data.owned then
        addButton("Купить дверь", y, "buy")
        y = y + 42
    end

    if data.owned and data.isOwner then
        addButton("Продать дверь", y, "sell")
        y = y + 42

        local entry = vgui.Create("DTextEntry", doorFrame)
        entry:SetPos(16, y)
        entry:SetSize(doorFrame:GetWide() - 32, 34)
        entry:SetText(data.title or "")
        entry:SetPlaceholderText("Название двери")
        y = y + 40

        local titleBtn = vgui.Create("DButton", doorFrame)
        titleBtn:SetText("")
        titleBtn:SetPos(16, y)
        titleBtn:SetSize(doorFrame:GetWide() - 32, 34)
        titleBtn.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(74, 123, 214, self:IsHovered() and 245 or 224))
            draw.SimpleText("Установить название", "NexusPlusDoorText", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        titleBtn.DoClick = function()
            local text = string.Trim(entry:GetText() or "")
            if text == "" then return end
            text = string.sub(text, 1, cfgValue("Door", "maxTitleLength", 48))
            sendDoorAction("title", text)
        end
        y = y + 40
    end

    if data.isSuperAdmin then
        local adminLabel = vgui.Create("DLabel", doorFrame)
        adminLabel:SetPos(16, y)
        adminLabel:SetSize(doorFrame:GetWide() - 32, 18)
        adminLabel:SetText("Admin функции")
        adminLabel:SetFont("NexusPlusDoorText")
        adminLabel:SetTextColor(Color(175, 185, 210))
        y = y + 22

        for _, action in ipairs(cfgValue("Door", "superadminActions", {})) do
            if action.id ~= "set_group" then
                addAdminButton(action.label or action.id, y, action.id)
                y = y + 34
            end
        end

        local groupEntry = vgui.Create("DTextEntry", doorFrame)
        groupEntry:SetPos(16, y)
        groupEntry:SetSize(doorFrame:GetWide() - 32, 30)
        groupEntry:SetPlaceholderText("Группа двери (например: police, mayor)")
        y = y + 36

        local groupBtn = vgui.Create("DButton", doorFrame)
        groupBtn:SetText("")
        groupBtn:SetPos(16, y)
        groupBtn:SetSize(doorFrame:GetWide() - 32, 32)
        groupBtn.Paint = function(self, w, h)
            draw.RoundedBox(7, 0, 0, w, h, Color(53, 86, 154, self:IsHovered() and 248 or 224))
            draw.SimpleText("Установить группу двери", "NexusPlusDoorText", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        groupBtn.DoClick = function()
            local groupName = string.Trim(groupEntry:GetText() or "")
            if groupName == "" then return end

            net.Start("nexus_plus_door_admin")
            net.WriteString("set_group")
            net.WriteString(groupName)
            net.SendToServer()
        end
    end
end

net.Receive("nexus_plus_door_state", function()
    local valid = net.ReadBool()
    local ownable = net.ReadBool()
    local owned = net.ReadBool()
    local isOwner = net.ReadBool()
    local isSuperAdmin = net.ReadBool()
    local title = net.ReadString()
    local owners = net.ReadString()

    if not valid then
        chat.AddText(Color(220, 85, 85), "[NEXUS] ", color_white, "Смотрите на дверь и подойдите ближе")
        return
    end

    openDoorMenu({
        ownable = ownable,
        owned = owned,
        isOwner = isOwner,
        isSuperAdmin = isSuperAdmin,
        title = title,
        owners = owners
    })
end)

concommand.Add("nexus_plus_door_menu", function()
    net.Start("nexus_plus_door_request")
    net.SendToServer()
end)