if SERVER then return end

local function cfgValue(group, key, fallback)
    local cfg = NEXUS_PLUS_CONFIG and NEXUS_PLUS_CONFIG[group]
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

surface.CreateFont("NexusPlusBrand", {
    font = "Roboto",
    size = 34,
    weight = 800,
    antialias = true
})

surface.CreateFont("NexusPlusText", {
    font = "Roboto",
    size = 18,
    weight = 500,
    antialias = true
})

surface.CreateFont("NexusPlusSmall", {
    font = "Roboto",
    size = 15,
    weight = 600,
    antialias = true
})

local frame
local detailsFrame
local nextToggleAt = 0
local wasF4Down = false

local function runCommandText(cmd)
    local text = tostring(cmd or "")
    if text == "" then return end

    local parts = string.Explode(" ", text)
    local root = table.remove(parts, 1)
    if not root then return end

    RunConsoleCommand(root, unpack(parts))
end

local function getMoney(ply)
    if DarkRP and ply.getDarkRPVar then
        local value = ply:getDarkRPVar("money") or 0
        if DarkRP.formatMoney then return DarkRP.formatMoney(value) end
        return tostring(value)
    end

    return "0"
end

local function canUseItem(item)
    if not item then return false end
    if item.customCheck and isfunction(item.customCheck) then
        return item.customCheck(LocalPlayer()) == true
    end

    return true
end

local function pickModel(modelField, fallback)
    local model = fallback

    if isstring(modelField) and util.IsValidModel(modelField) then
        model = modelField
    elseif istable(modelField) then
        for _, value in ipairs(modelField) do
            if isstring(value) and util.IsValidModel(value) then
                model = value
                break
            end
        end
    end

    return model
end

local function createModelPreview(parent, modelPath, dockMarginRight)
    local modelPanel = vgui.Create("DModelPanel", parent)
    modelPanel:Dock(LEFT)
    modelPanel:DockMargin(0, 0, dockMarginRight or 10, 0)
    modelPanel:SetWide(cfgValue("F4", "modelPanelWidth", 84))
    modelPanel:SetModel(modelPath)
    modelPanel:SetFOV(cfgValue("F4", "modelFOV", 34))
    modelPanel.LayoutEntity = function() end
    local basePaint = modelPanel.Paint
    modelPanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(15, 18, 30, 140))
        basePaint(self, w, h)
    end

    local ent = modelPanel.Entity
    if IsValid(ent) then
        local min, max = ent:GetRenderBounds()
        local size = math.max(math.abs(min.x) + math.abs(max.x), math.abs(min.y) + math.abs(max.y), math.abs(min.z) + math.abs(max.z))
        modelPanel:SetCamPos(Vector(size, size * 0.8, size * 0.65))
        modelPanel:SetLookAt((min + max) * 0.5)
    end

    return modelPanel
end

local function openJobDetails(job)
    if IsValid(detailsFrame) then
        detailsFrame:Remove()
    end

    detailsFrame = vgui.Create("DFrame")
    detailsFrame:SetSize(640, 380)
    detailsFrame:Center()
    detailsFrame:SetTitle("")
    detailsFrame:SetDraggable(false)
    detailsFrame:ShowCloseButton(false)
    detailsFrame:MakePopup()
    detailsFrame.anim = 0

    local modelPath = pickModel(job.model, cfgValue("F4", "defaultModel", "models/props_c17/oildrum001.mdl"))
    local salary = DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(job.salary or 0) or tostring(job.salary or 0)
    local desc = tostring(job.description or "Описание отсутствует")

    detailsFrame.Paint = function(self, w, h)
        self.anim = Lerp(FrameTime() * 12, self.anim, 1)
        local alpha = math.floor(Lerp(self.anim, 0, 238))
        draw.RoundedBox(12, 0, 0, w, h, Color(16, 18, 26, alpha))
        draw.SimpleText(job.name or "Профессия", "NexusPlusBrand", 20, 24, Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT)
        draw.SimpleText("Зарплата: " .. salary, "NexusPlusText", 20, 64, Color(180, 190, 214, alpha), TEXT_ALIGN_LEFT)
    end

    local closeBtn = vgui.Create("DButton", detailsFrame)
    closeBtn:SetPos(detailsFrame:GetWide() - 44, 10)
    closeBtn:SetSize(30, 24)
    closeBtn:SetText("X")
    closeBtn:SetFont("NexusPlusText")
    closeBtn:SetTextColor(color_white)
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(58, 66, 92, self:IsHovered() and 240 or 210))
    end
    closeBtn.DoClick = function()
        detailsFrame:Remove()
    end

    local preview = vgui.Create("DPanel", detailsFrame)
    preview:SetPos(20, 92)
    preview:SetSize(200, 270)
    preview.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(23, 26, 38, 220))
    end
    local model = createModelPreview(preview, modelPath, 0)
    model:Dock(FILL)
    model:DockMargin(10, 10, 10, 10)

    local info = vgui.Create("DPanel", detailsFrame)
    info:SetPos(232, 92)
    info:SetSize(388, 230)
    info.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(23, 26, 38, 220))
    end

    local descLabel = vgui.Create("DLabel", info)
    descLabel:Dock(FILL)
    descLabel:DockMargin(12, 12, 12, 12)
    descLabel:SetFont("NexusPlusText")
    descLabel:SetTextColor(Color(235, 240, 252))
    descLabel:SetWrap(true)
    descLabel:SetAutoStretchVertical(true)
    descLabel:SetContentAlignment(7)
    descLabel:SetText(desc)

    local takeBtn = vgui.Create("DButton", detailsFrame)
    takeBtn:SetPos(232, 332)
    takeBtn:SetSize(388, 30)
    takeBtn:SetText("")
    takeBtn.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(74, 123, 214, self:IsHovered() and 245 or 224))
        draw.SimpleText("Взять профессию", "NexusPlusText", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    takeBtn.DoClick = function()
        if job.command then
            RunConsoleCommand("say", "/" .. job.command)
        end
    end
end

local function createCard(parent, item)
    local card = vgui.Create("DButton", parent)
    card:Dock(TOP)
    card:DockMargin(0, 0, 0, 8)
    card:SetTall(cfgValue("F4", "cardHeight", 78))
    card:SetText("")
    card.hover = 0

    card.Paint = function(self, w, h)
        self.hover = Lerp(FrameTime() * 12, self.hover, self:IsHovered() and 1 or 0)

        local base = cfgValue("Theme", "panel", Color(28, 31, 44, 245))
        local over = cfgValue("Theme", "panelHover", Color(39, 50, 68, 245))
        local color = Color(
            Lerp(self.hover, base.r, over.r),
            Lerp(self.hover, base.g, over.g),
            Lerp(self.hover, base.b, over.b),
            245
        )

        draw.RoundedBox(10, 0, 0, w, h, color)
        draw.SimpleText(item.title or "", "NexusPlusText", 98, 24, cfgValue("Theme", "text", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(item.subtitle or "", "NexusPlusSmall", 98, 50, cfgValue("Theme", "mutedText", Color(165, 172, 196, 230)), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(item.priceText or "", "NexusPlusText", w - 12, h * 0.5, cfgValue("Theme", "text", color_white), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    createModelPreview(card, item.model or cfgValue("F4", "defaultModel", "models/props_c17/oildrum001.mdl"), 8)

    card.DoClick = function()
        if item.onClick then item.onClick() end
    end
end

local function buildCommandsList()
    local list = {}
    for _, item in ipairs(cfgValue("F4", "quickCommands", {})) do
        list[#list + 1] = {
            title = item.label or "Команда",
            subtitle = "Быстрое действие",
            priceText = "",
            model = cfgValue("F4", "defaultModel", "models/props_c17/oildrum001.mdl"),
            onClick = function() runCommandText(item.cmd) end
        }
    end
    return list
end

local function buildInventoryList()
    return {
        {
            title = "Инвентарь",
            subtitle = "Открыть отдельным окном, если встраивание недоступно",
            priceText = "",
            model = "models/props_lab/box01a.mdl",
            onClick = function()
                RunConsoleCommand("nexus_inv_open")
            end
        }
    }
end

local function buildJobsList()
    local list = {}

    for _, teamData in ipairs(RPExtraTeams or {}) do
        if canUseItem(teamData) then
            local salary = teamData.salary and (DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(teamData.salary) or tostring(teamData.salary)) or "0"
            local description = tostring(teamData.description or "")
            description = string.gsub(description, "\n", " ")
            if #description > 70 then
                description = string.sub(description, 1, 70) .. "..."
            end
            if description == "" then
                description = "Зарплата: " .. salary
            end

            list[#list + 1] = {
                title = teamData.name or "Работа",
                subtitle = description,
                priceText = "",
                model = pickModel(teamData.model, cfgValue("F4", "defaultModel", "models/props_c17/oildrum001.mdl")),
                onClick = function() openJobDetails(teamData) end
            }
        end
    end

    return list
end

local function buildEntitiesList()
    local list = {}

    for _, entData in ipairs(DarkRPEntities or {}) do
        if canUseItem(entData) then
            local price = entData.price or 0
            local priceText = DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(price) or tostring(price)
            list[#list + 1] = {
                title = entData.name or "Энтити",
                subtitle = "Покупка энтити",
                priceText = priceText,
                model = pickModel(entData.model, cfgValue("F4", "defaultModel", "models/props_c17/oildrum001.mdl")),
                onClick = function()
                    if entData.cmd then
                        RunConsoleCommand("darkrp", "buy", entData.cmd)
                    end
                end
            }
        end
    end

    return list
end

local function buildShipmentsList()
    local list = {}

    for _, item in ipairs(CustomShipments or {}) do
        if canUseItem(item) then
            local price = item.price or 0
            local priceText = DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(price) or tostring(price)
            list[#list + 1] = {
                title = item.name or "Поставка",
                subtitle = "Оружие",
                priceText = priceText,
                model = pickModel(item.model, cfgValue("F4", "defaultModel", "models/props_c17/oildrum001.mdl")),
                onClick = function()
                    RunConsoleCommand("darkrp", "buyshipment", item.name or "")
                end
            }
        end
    end

    return list
end

local function buildAmmoList()
    local list = {}

    for _, item in ipairs(DarkRPAmmoTypes or {}) do
        if canUseItem(item) then
            local price = item.price or 0
            local priceText = DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(price) or tostring(price)
            list[#list + 1] = {
                title = item.name or "Патроны",
                subtitle = "Боеприпасы",
                priceText = priceText,
                model = pickModel(item.model, cfgValue("F4", "defaultAmmoModel", "models/items/boxsrounds.mdl")),
                onClick = function()
                    RunConsoleCommand("darkrp", "buyammo", item.ammoType or item.name or "")
                end
            }
        end
    end

    return list
end

local BUILDERS = {
    inventory = buildInventoryList,
    jobs = buildJobsList,
    entities = buildEntitiesList,
    shipments = buildShipmentsList,
    ammo = buildAmmoList,
    commands = buildCommandsList
}

local function rebuildContent(parent, categoryId)
    parent:Clear()

    if categoryId == "inventory" and _G.NEXUS_INV_F4_BUILD then
        _G.NEXUS_INV_F4_BUILD(parent)
        return
    end

    local builder = BUILDERS[categoryId]
    if not builder then return end

    for _, item in ipairs(builder()) do
        createCard(parent, item)
    end
end

local function closeF4Menu()
    if IsValid(detailsFrame) then
        detailsFrame:Remove()
    end

    if IsValid(frame) then
        frame:Remove()
    end

    frame = nil
end

local function toggleF4Menu()
    if nextToggleAt > CurTime() then return end
    nextToggleAt = CurTime() + cfgValue("F4", "toggleCooldown", 0.2)

    if IsValid(frame) then
        closeF4Menu()
        return
    end

    local width = math.floor(ScrW() * cfgValue("F4", "widthFactor", 0.8))
    local height = math.floor(ScrH() * cfgValue("F4", "heightFactor", 0.82))

    frame = vgui.Create("DFrame")
    frame:SetSize(width, height)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame.anim = 0

    frame.Paint = function(self, w, h)
        local speed = cfgValue("F4", "openAnimSpeed", 10)
        self.anim = Lerp(FrameTime() * speed, self.anim, 1)
        local alpha = math.floor(Lerp(self.anim, 0, 238))
        local slide = math.floor(Lerp(self.anim, 16, 0))

        draw.RoundedBox(14, 0, slide, w, h - slide, cfgValue("Theme", "background", Color(16, 18, 26, 238)))
        draw.SimpleText(cfgValue("General", "brand", "NEXUS DARKRP"), "NexusPlusBrand", 20, 26 + slide, Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT)
        draw.SimpleText("Баланс: " .. getMoney(LocalPlayer()), "NexusPlusText", w - 20, 38 + slide, Color(180, 190, 210, alpha), TEXT_ALIGN_RIGHT)
    end

    local tabsPanel = vgui.Create("DPanel", frame)
    tabsPanel:SetPos(16, 112)
    tabsPanel:SetSize(220, height - 128)
    tabsPanel.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, cfgValue("Theme", "panelSoft", Color(23, 26, 38, 220)))
    end

    local contentWrap = vgui.Create("DPanel", frame)
    contentWrap:SetPos(248, 112)
    contentWrap:SetSize(width - 264, height - 128)
    contentWrap.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, cfgValue("Theme", "panelSoft", Color(23, 26, 38, 220)))
    end

    local content = vgui.Create("DScrollPanel", contentWrap)
    content:Dock(FILL)
    content:DockMargin(10, 10, 10, 10)

    local categories = {}
    for _, tab in ipairs(cfgValue("F4", "categories", {})) do
        if tab.id ~= "commands" or cfgValue("F4", "showCommandsCategory", true) then
            categories[#categories + 1] = tab
        end
    end

    local current = categories[1] and categories[1].id or "jobs"
    local function setCategory(id)
        current = id
        rebuildContent(content, id)
    end

    for _, tab in ipairs(categories) do
        local button = vgui.Create("DButton", tabsPanel)
        button:Dock(TOP)
        button:DockMargin(8, 8, 8, 0)
        button:SetTall(40)
        button:SetText("")
        button.Paint = function(self, w, h)
            local active = current == tab.id
            local color = active and cfgValue("Theme", "accent", Color(74, 123, 214, 240)) or Color(37, 42, 60, self:IsHovered() and 235 or 210)
            draw.RoundedBox(7, 0, 0, w, h, color)
            draw.SimpleText(tab.label or tab.id, "NexusPlusText", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        button.DoClick = function()
            setCategory(tab.id)
        end
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetText("Закрыть")
    closeBtn:SetFont("NexusPlusSmall")
    closeBtn:SetTextColor(color_white)
    closeBtn:SetSize(90, 30)
    closeBtn:SetPos(width - 108, 74)
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(58, 66, 92, self:IsHovered() and 240 or 210))
    end
    closeBtn.DoClick = function()
        closeF4Menu()
    end

    setCategory(current)
end

concommand.Add("nexus_plus_f4", function()
    toggleF4Menu()
end)

hook.Add("PlayerBindPress", "NexusPlusF4Bind", function(_, bind, pressed)
    if not pressed then return end

    local key = string.lower(bind or "")
    if not string.find(key, "gm_showspare2", 1, true) then return end

    toggleF4Menu()
    return true
end)

hook.Add("Think", "NexusPlusF4KeyboardToggle", function()
    local isDown = input.IsKeyDown(KEY_F4)

    if isDown and not wasF4Down then
        toggleF4Menu()
    end

    wasF4Down = isDown
end)