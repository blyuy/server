if SERVER then return end

local craftFrame
local adminFrame

local craftPayload = {
    recipes = {},
    active = nil
}

local adminPayload = {
    recipes = {},
    recipeIds = {},
    itemIds = {}
}

local selectedCategory = "Все"
local selectedRecipeId = nil
local pendingOpen = false

surface.CreateFont("NexusCraftHero", {
    font = "Roboto",
    size = 32,
    weight = 900,
    antialias = true
})

surface.CreateFont("NexusCraftBody", {
    font = "Roboto",
    size = 15,
    weight = 500,
    antialias = true
})

surface.CreateFont("NexusCraftSmall", {
    font = "Roboto",
    size = 13,
    weight = 500,
    antialias = true
})

local function safeSend(msgName, writer)
    local ok = pcall(function()
        net.Start(msgName)
        if writer then writer() end
        net.SendToServer()
    end)
    return ok
end

local function requestSync()
    local ok = safeSend("nexus_craft_request_sync")
    if not ok then
        -- Fallback path when net channels are not yet pooled serverside.
        RunConsoleCommand("nexus_craft")
    end
end

local function startCraft(recipeId)
    local ok = safeSend("nexus_craft_start", function()
        net.WriteString(recipeId or "")
    end)

    if not ok then
        chat.AddText(Color(230, 120, 120), "[CRAFT] ", color_white, "Сервер крафта еще не инициализирован. Попробуйте через 1-2 секунды.")
        RunConsoleCommand("nexus_craft")
    end
end

local function formatTime(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d", m, s)
end

local function activeLeft()
    if not craftPayload.active then return 0 end
    return math.max(0, math.ceil((tonumber(craftPayload.active.finishAt) or CurTime()) - CurTime()))
end

local function buildCategories()
    local cats = { "Все" }
    local seen = { ["Все"] = true }

    for _, r in ipairs(craftPayload.recipes or {}) do
        local c = tostring(r.category or "Общее")
        if not seen[c] then
            seen[c] = true
            cats[#cats + 1] = c
        end
    end

    table.sort(cats, function(a, b)
        if a == "Все" then return true end
        if b == "Все" then return false end
        return a < b
    end)

    return cats
end

local function filteredRecipes()
    local out = {}
    for _, r in ipairs(craftPayload.recipes or {}) do
        local c = tostring(r.category or "Общее")
        if selectedCategory == "Все" or c == selectedCategory then
            out[#out + 1] = r
        end
    end
    table.sort(out, function(a, b) return tostring(a.name or a.id) < tostring(b.name or b.id) end)
    return out
end

local function findRecipeById(id)
    for _, r in ipairs(craftPayload.recipes or {}) do
        if tostring(r.id) == tostring(id) then return r end
    end
    return nil
end

local function chooseDefaultRecipe()
    local list = filteredRecipes()
    if #list == 0 then
        selectedRecipeId = nil
        return
    end
    if findRecipeById(selectedRecipeId) then return end
    selectedRecipeId = list[1].id
end

local function makeSoftButton(parent, text, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn.label = text or ""
    btn.hover = 0
    btn.Paint = function(self, w, h)
        self.hover = Lerp(FrameTime() * 10, self.hover, self:IsHovered() and 1 or 0)
        local r = Lerp(self.hover, 44, 70)
        local g = Lerp(self.hover, 52, 92)
        local b = Lerp(self.hover, 78, 138)
        draw.RoundedBox(8, 0, 0, w, h, Color(r, g, b, 230))
        draw.SimpleText(self.label, "NexusCraftBody", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = onClick
    return btn
end

local function openCraftUI()
    if IsValid(craftFrame) then craftFrame:Remove() end
    chooseDefaultRecipe()

    local categories = buildCategories()
    local recipes = filteredRecipes()

    craftFrame = vgui.Create("DFrame")
    craftFrame:SetSize(1180, 730)
    craftFrame:Center()
    craftFrame:SetTitle("")
    craftFrame:ShowCloseButton(false)
    craftFrame:SetDraggable(false)
    craftFrame:MakePopup()

    craftFrame.Paint = function(_, w, h)
        draw.RoundedBox(18, 0, 0, w, h, Color(10, 12, 20, 250))
        draw.RoundedBox(0, 0, 90, w, 1, Color(255, 255, 255, 14))

        draw.SimpleText("NEXUS CRAFT STATION", "NexusCraftHero", 20, 34, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Создавайте предметы прямо из ресурсов инвентаря", "NexusCraftBody", 20, 64, Color(164, 176, 206), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local statusText = "Свободно"
        local statusColor = Color(150, 216, 170)
        if craftPayload.active then
            statusText = "Активный крафт: " .. tostring(craftPayload.active.recipeId) .. " | " .. formatTime(activeLeft())
            statusColor = Color(240, 196, 114)
        end
        draw.SimpleText(statusText, "NexusCraftBody", w - 20, 64, statusColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", craftFrame)
    closeBtn:SetPos(craftFrame:GetWide() - 48, 12)
    closeBtn:SetSize(30, 24)
    closeBtn:SetText("X")
    closeBtn:SetFont("NexusCraftBody")
    closeBtn:SetTextColor(color_white)
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(62, 72, 104, self:IsHovered() and 245 or 220))
    end
    closeBtn.DoClick = function() craftFrame:Remove() end

    local left = vgui.Create("DPanel", craftFrame)
    left:SetPos(14, 104)
    left:SetSize(250, craftFrame:GetTall() - 118)
    left.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(22, 26, 38, 235))
    end

    local catScroll = vgui.Create("DScrollPanel", left)
    catScroll:SetPos(10, 10)
    catScroll:SetSize(left:GetWide() - 20, left:GetTall() - 20)

    for _, cat in ipairs(categories) do
        local btn = vgui.Create("DButton", catScroll)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 8)
        btn:SetTall(34)
        btn:SetText("")
        btn.cat = cat
        btn.hover = 0
        btn.Paint = function(self, w, h)
            local active = selectedCategory == self.cat
            self.hover = Lerp(FrameTime() * 10, self.hover, self:IsHovered() and 1 or 0)

            local base = active and Color(74, 126, 220, 240) or Color(40, 46, 66, 214)
            local over = active and Color(90, 146, 248, 248) or Color(58, 68, 98, 228)

            local r = Lerp(self.hover, base.r, over.r)
            local g = Lerp(self.hover, base.g, over.g)
            local b = Lerp(self.hover, base.b, over.b)
            local a = Lerp(self.hover, base.a, over.a)

            draw.RoundedBox(8, 0, 0, w, h, Color(r, g, b, a))
            draw.SimpleText(self.cat, "NexusCraftBody", 12, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            selectedCategory = cat
            selectedRecipeId = nil
            openCraftUI()
        end
    end

    local middle = vgui.Create("DPanel", craftFrame)
    middle:SetPos(272, 104)
    middle:SetSize(430, craftFrame:GetTall() - 118)
    middle.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(22, 26, 38, 235))
    end

    local recipeScroll = vgui.Create("DScrollPanel", middle)
    recipeScroll:SetPos(10, 10)
    recipeScroll:SetSize(middle:GetWide() - 20, middle:GetTall() - 20)

    if #recipes == 0 then
        local empty = vgui.Create("DLabel", recipeScroll)
        empty:Dock(TOP)
        empty:SetTall(40)
        empty:SetFont("NexusCraftBody")
        empty:SetText("В этой категории нет рецептов.")
        empty:SetTextColor(Color(194, 204, 228))
        empty:SetContentAlignment(5)
    else
        for _, recipe in ipairs(recipes) do
            local card = vgui.Create("DButton", recipeScroll)
            card:Dock(TOP)
            card:DockMargin(0, 0, 0, 10)
            card:SetTall(98)
            card:SetText("")
            card.hover = 0
            card.Paint = function(self, w, h)
                local active = tostring(selectedRecipeId or "") == tostring(recipe.id or "")
                self.hover = Lerp(FrameTime() * 10, self.hover, self:IsHovered() and 1 or 0)

                local base = active and Color(66, 112, 198, 236) or Color(34, 40, 58, 230)
                local over = active and Color(82, 132, 228, 244) or Color(48, 58, 84, 236)
                local r = Lerp(self.hover, base.r, over.r)
                local g = Lerp(self.hover, base.g, over.g)
                local b = Lerp(self.hover, base.b, over.b)
                local a = Lerp(self.hover, base.a, over.a)

                draw.RoundedBox(10, 0, 0, w, h, Color(r, g, b, a))
                draw.SimpleText(tostring(recipe.name or recipe.id), "NexusCraftBody", 12, 20, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("Результат: " .. tostring(recipe.result and recipe.result.name or recipe.result and recipe.result.id or "?") .. " x" .. tostring(recipe.result and recipe.result.amount or 1), "NexusCraftSmall", 12, 42, Color(180, 194, 224), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("Время: " .. formatTime(tonumber(recipe.timeSec) or 0), "NexusCraftSmall", 12, 60, Color(180, 194, 224), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                local status = recipe.canCraft and "Готово к крафту" or "Недостаточно ресурсов"
                local statusColor = recipe.canCraft and Color(146, 228, 170) or Color(236, 126, 126)
                draw.SimpleText(status, "NexusCraftSmall", 12, 80, statusColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            card.DoClick = function()
                selectedRecipeId = recipe.id
                openCraftUI()
            end
        end
    end

    local right = vgui.Create("DPanel", craftFrame)
    right:SetPos(710, 104)
    right:SetSize(craftFrame:GetWide() - 724, craftFrame:GetTall() - 118)
    right.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(22, 26, 38, 235))
    end

    local selected = findRecipeById(selectedRecipeId)

    local title = vgui.Create("DLabel", right)
    title:SetPos(12, 14)
    title:SetSize(right:GetWide() - 24, 24)
    title:SetFont("NexusCraftHero")
    title:SetTextColor(color_white)
    title:SetText(selected and tostring(selected.name or selected.id) or "Выберите рецепт")

    local desc = vgui.Create("DLabel", right)
    desc:SetPos(12, 44)
    desc:SetSize(right:GetWide() - 24, 42)
    desc:SetFont("NexusCraftBody")
    desc:SetTextColor(Color(180, 192, 220))
    desc:SetWrap(true)
    desc:SetText(selected and tostring(selected.description or "") or "Справа отображаются ингредиенты и кнопка крафта.")

    local resLine = vgui.Create("DLabel", right)
    resLine:SetPos(12, 92)
    resLine:SetSize(right:GetWide() - 24, 20)
    resLine:SetFont("NexusCraftBody")
    resLine:SetTextColor(Color(202, 214, 240))
    if selected then
        resLine:SetText("Результат: " .. tostring(selected.result and selected.result.name or selected.result and selected.result.id or "?") .. " x" .. tostring(selected.result and selected.result.amount or 1))
    else
        resLine:SetText("Результат: -")
    end

    local ingHeader = vgui.Create("DLabel", right)
    ingHeader:SetPos(12, 118)
    ingHeader:SetSize(right:GetWide() - 24, 20)
    ingHeader:SetFont("NexusCraftBody")
    ingHeader:SetTextColor(Color(212, 224, 246))
    ingHeader:SetText("Ингредиенты")

    local ingWrap = vgui.Create("DScrollPanel", right)
    ingWrap:SetPos(12, 142)
    ingWrap:SetSize(right:GetWide() - 24, right:GetTall() - 226)

    if selected and istable(selected.ingredients) and #selected.ingredients > 0 then
        for _, ing in ipairs(selected.ingredients or {}) do
            local row = vgui.Create("DPanel", ingWrap)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 8)
            row:SetTall(32)
            row.Paint = function(_, w, h)
                local ok = (tonumber(ing.have) or 0) >= (tonumber(ing.amount) or 1)
                draw.RoundedBox(8, 0, 0, w, h, Color(34, 40, 58, 220))
                draw.SimpleText(tostring(ing.name or ing.id), "NexusCraftBody", 10, h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(
                    tostring(ing.have or 0) .. "/" .. tostring(ing.amount or 1),
                    "NexusCraftBody",
                    w - 10,
                    h * 0.5,
                    ok and Color(150, 230, 174) or Color(234, 128, 128),
                    TEXT_ALIGN_RIGHT,
                    TEXT_ALIGN_CENTER
                )
            end
        end
    else
        local emptyIng = vgui.Create("DLabel", ingWrap)
        emptyIng:Dock(TOP)
        emptyIng:SetTall(28)
        emptyIng:SetFont("NexusCraftSmall")
        emptyIng:SetTextColor(Color(180, 190, 214))
        emptyIng:SetText("Ингредиенты не заданы")
        emptyIng:SetContentAlignment(5)
    end

    local craftBtn = makeSoftButton(right, "Скрафтить", function()
        if not selected then return end
        if craftPayload.active then return end
        if not selected.canCraft then return end
        startCraft(selected.id)
    end)
    craftBtn:SetPos(12, right:GetTall() - 74)
    craftBtn:SetSize(right:GetWide() - 24, 30)

    local refreshBtn = makeSoftButton(right, "Обновить", function()
        requestSync()
    end)
    refreshBtn:SetPos(12, right:GetTall() - 40)
    refreshBtn:SetSize(right:GetWide() - 24, 26)

    craftBtn.Paint = function(self, w, h)
        local enabled = selected and selected.canCraft and (not craftPayload.active)
        self.hover = Lerp(FrameTime() * 10, self.hover, self:IsHovered() and 1 or 0)

        local base = enabled and Color(66, 138, 104, 234) or Color(70, 76, 98, 210)
        local over = enabled and Color(82, 164, 120, 244) or Color(86, 94, 118, 220)
        local r = Lerp(self.hover, base.r, over.r)
        local g = Lerp(self.hover, base.g, over.g)
        local b = Lerp(self.hover, base.b, over.b)
        local a = Lerp(self.hover, base.a, over.a)

        draw.RoundedBox(8, 0, 0, w, h, Color(r, g, b, a))

        local label = "Скрафтить"
        if not selected then
            label = "Выберите рецепт"
        elseif craftPayload.active then
            label = "Крафт уже выполняется"
        elseif not selected.canCraft then
            label = "Недостаточно ресурсов"
        end

        draw.SimpleText(label, "NexusCraftBody", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function sendAdminAction(action, data)
    local ok = safeSend("nexus_craft_admin_action", function()
        net.WriteString(action)
        net.WriteString(util.TableToJSON(data or {}, false) or "{}")
    end)

    if not ok then
        chat.AddText(Color(230, 120, 120), "[CRAFT ADMIN] ", color_white, "Сервер крафта не инициализирован.")
    end
end

local function openAdminUI()
    if IsValid(adminFrame) then adminFrame:Remove() end

    adminFrame = vgui.Create("DFrame")
    adminFrame:SetSize(1180, 720)
    adminFrame:Center()
    adminFrame:SetTitle("")
    adminFrame:ShowCloseButton(false)
    adminFrame:SetDraggable(false)
    adminFrame:MakePopup()

    adminFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(16, 18, 26, 238))
        draw.SimpleText("NEXUS CRAFT ADMIN", "DermaLarge", 16, 22, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeBtn = vgui.Create("DButton", adminFrame)
    closeBtn:SetPos(adminFrame:GetWide() - 42, 10)
    closeBtn:SetSize(30, 24)
    closeBtn:SetText("X")
    closeBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(62, 72, 98, self:IsHovered() and 240 or 214))
    end
    closeBtn.DoClick = function() adminFrame:Remove() end

    local recipesList = vgui.Create("DListView", adminFrame)
    recipesList:SetPos(12, 52)
    recipesList:SetSize(340, adminFrame:GetTall() - 64)
    recipesList:AddColumn("Recipe ID")
    recipesList:AddColumn("Name")

    local right = vgui.Create("DPanel", adminFrame)
    right:SetPos(360, 52)
    right:SetSize(adminFrame:GetWide() - 372, adminFrame:GetTall() - 64)
    right.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(23, 27, 39, 235))
    end

    local selectedId

    local idEntry = vgui.Create("DTextEntry", right)
    idEntry:SetPos(10, 10)
    idEntry:SetSize(170, 26)
    idEntry:SetPlaceholderText("recipe_id")

    local nameEntry = vgui.Create("DTextEntry", right)
    nameEntry:SetPos(186, 10)
    nameEntry:SetSize(220, 26)
    nameEntry:SetPlaceholderText("Название")

    local categoryEntry = vgui.Create("DTextEntry", right)
    categoryEntry:SetPos(412, 10)
    categoryEntry:SetSize(140, 26)
    categoryEntry:SetPlaceholderText("Категория")

    local timeEntry = vgui.Create("DTextEntry", right)
    timeEntry:SetPos(558, 10)
    timeEntry:SetSize(70, 26)
    timeEntry:SetValue("0")

    local resultItem = vgui.Create("DComboBox", right)
    resultItem:SetPos(10, 40)
    resultItem:SetSize(220, 26)
    resultItem:SetValue("Result Item")
    for _, id in ipairs(adminPayload.itemIds or {}) do resultItem:AddChoice(id) end

    local resultAmount = vgui.Create("DTextEntry", right)
    resultAmount:SetPos(236, 40)
    resultAmount:SetSize(70, 26)
    resultAmount:SetValue("1")

    local descEntry = vgui.Create("DTextEntry", right)
    descEntry:SetPos(312, 40)
    descEntry:SetSize(316, 26)
    descEntry:SetPlaceholderText("Описание рецепта")

    local ingItem = vgui.Create("DComboBox", right)
    ingItem:SetPos(10, 74)
    ingItem:SetSize(220, 26)
    ingItem:SetValue("Ingredient Item")
    for _, id in ipairs(adminPayload.itemIds or {}) do ingItem:AddChoice(id) end

    local ingAmount = vgui.Create("DTextEntry", right)
    ingAmount:SetPos(236, 74)
    ingAmount:SetSize(70, 26)
    ingAmount:SetValue("1")

    local addIngBtn = vgui.Create("DButton", right)
    addIngBtn:SetPos(312, 74)
    addIngBtn:SetSize(150, 26)
    addIngBtn:SetText("Добавить ингредиент")

    local clearIngBtn = vgui.Create("DButton", right)
    clearIngBtn:SetPos(468, 74)
    clearIngBtn:SetSize(160, 26)
    clearIngBtn:SetText("Очистить ингредиенты")

    local ingList = vgui.Create("DListView", right)
    ingList:SetPos(10, 106)
    ingList:SetSize(618, 460)
    ingList:AddColumn("Item ID")
    ingList:AddColumn("Amount")

    local ingredientDraft = {}

    local function redrawIngredientDraft()
        ingList:Clear()
        for _, row in ipairs(ingredientDraft) do
            ingList:AddLine(row.id, tostring(row.amount))
        end
    end

    addIngBtn.DoClick = function()
        local id = ingItem:GetValue()
        if not id or id == "" or id == "Ingredient Item" then return end
        local amt = math.max(1, math.floor(tonumber(ingAmount:GetValue()) or 1))

        local found = false
        for _, row in ipairs(ingredientDraft) do
            if row.id == id then
                row.amount = amt
                found = true
                break
            end
        end
        if not found then
            ingredientDraft[#ingredientDraft + 1] = { id = id, amount = amt }
        end
        redrawIngredientDraft()
    end

    clearIngBtn.DoClick = function()
        ingredientDraft = {}
        redrawIngredientDraft()
    end

    ingList.OnRowRightClick = function(_, _, line)
        local rid = line:GetColumnText(1)
        for i = #ingredientDraft, 1, -1 do
            if ingredientDraft[i].id == rid then
                table.remove(ingredientDraft, i)
            end
        end
        redrawIngredientDraft()
    end

    local saveBtn = vgui.Create("DButton", right)
    saveBtn:SetPos(10, 574)
    saveBtn:SetSize(200, 30)
    saveBtn:SetText("Сохранить рецепт")
    saveBtn.DoClick = function()
        local recipeId = string.Trim(idEntry:GetValue() or "")
        if recipeId == "" then return end

        local outResultId = resultItem:GetValue()
        if not outResultId or outResultId == "" or outResultId == "Result Item" then return end

        sendAdminAction("recipe_upsert", {
            recipeId = recipeId,
            recipe = {
                name = string.Trim(nameEntry:GetValue() or ""),
                description = string.Trim(descEntry:GetValue() or ""),
                category = string.Trim(categoryEntry:GetValue() or ""),
                timeSec = tonumber(timeEntry:GetValue()) or 0,
                result = {
                    id = outResultId,
                    amount = tonumber(resultAmount:GetValue()) or 1
                },
                ingredients = ingredientDraft
            }
        })
    end

    local removeBtn = vgui.Create("DButton", right)
    removeBtn:SetPos(216, 574)
    removeBtn:SetSize(180, 30)
    removeBtn:SetText("Удалить рецепт")
    removeBtn.DoClick = function()
        local rid = selectedId or string.Trim(idEntry:GetValue() or "")
        if rid == "" then return end
        sendAdminAction("recipe_remove", { recipeId = rid })
    end

    local openCraftBtn = vgui.Create("DButton", right)
    openCraftBtn:SetPos(402, 574)
    openCraftBtn:SetSize(226, 30)
    openCraftBtn:SetText("Открыть крафт-меню")
    openCraftBtn.DoClick = function()
        RunConsoleCommand("nexus_craft")
    end

    local rows = {}
    for id, recipe in pairs(adminPayload.recipes or {}) do
        rows[#rows + 1] = { id = id, name = tostring(recipe.name or id), recipe = recipe }
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    for _, row in ipairs(rows) do
        recipesList:AddLine(row.id, row.name)
    end

    recipesList.OnRowSelected = function(_, _, line)
        local rid = line:GetColumnText(1)
        local recipe = adminPayload.recipes and adminPayload.recipes[rid]
        if not recipe then return end

        selectedId = rid
        idEntry:SetValue(rid)
        nameEntry:SetValue(recipe.name or "")
        categoryEntry:SetValue(recipe.category or "")
        timeEntry:SetValue(tostring(recipe.timeSec or 0))
        descEntry:SetValue(recipe.description or "")
        resultItem:SetValue(recipe.result and recipe.result.id or "Result Item")
        resultAmount:SetValue(tostring(recipe.result and recipe.result.amount or 1))

        ingredientDraft = {}
        for _, row in ipairs(recipe.ingredients or {}) do
            ingredientDraft[#ingredientDraft + 1] = {
                id = tostring(row.id or ""),
                amount = math.max(1, math.floor(tonumber(row.amount) or 1))
            }
        end
        redrawIngredientDraft()
    end
end

net.Receive("nexus_craft_open", function()
    craftPayload = util.JSONToTable(net.ReadString() or "{}") or craftPayload
    craftPayload.recipes = craftPayload.recipes or {}
    openCraftUI()
end)

net.Receive("nexus_craft_sync", function()
    craftPayload = util.JSONToTable(net.ReadString() or "{}") or craftPayload
    craftPayload.recipes = craftPayload.recipes or {}

    if IsValid(craftFrame) then
        openCraftUI()
    elseif pendingOpen then
        pendingOpen = false
        openCraftUI()
    end
end)

net.Receive("nexus_craft_result", function()
    local ok = net.ReadBool()
    local msg = net.ReadString()
    chat.AddText(ok and Color(120, 230, 150) or Color(230, 120, 120), "[CRAFT] ", color_white, msg)
    requestSync()
end)

net.Receive("nexus_craft_admin_open", function()
    openAdminUI()
end)

net.Receive("nexus_craft_admin_sync", function()
    adminPayload = util.JSONToTable(net.ReadString() or "{}") or adminPayload
    adminPayload.recipes = adminPayload.recipes or {}
    adminPayload.itemIds = adminPayload.itemIds or {}

    if IsValid(adminFrame) then
        openAdminUI()
    end
end)

concommand.Add("nexus_craft_open", function()
    pendingOpen = true
    requestSync()
    RunConsoleCommand("nexus_craft")
end)