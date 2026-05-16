if CLIENT then return end

AddCSLuaFile("autorun/sh_nexus_inv_config.lua")
AddCSLuaFile("autorun/client/cl_nexus_crafting.lua")

util.AddNetworkString("nexus_craft_open")
util.AddNetworkString("nexus_craft_sync")
util.AddNetworkString("nexus_craft_request_sync")
util.AddNetworkString("nexus_craft_start")
util.AddNetworkString("nexus_craft_result")

util.AddNetworkString("nexus_craft_admin_open")
util.AddNetworkString("nexus_craft_admin_sync")
util.AddNetworkString("nexus_craft_admin_action")

NEXUS_CRAFT = NEXUS_CRAFT or {}

local runtimePath = "nexus_inv/crafting_runtime.json"
local invRuntimePath = "nexus_inv/runtime.json"

local runtime = {
    recipes = nil
}

local activeCraft = {}

local invApi = {
    addItem = nil,
    removeItem = nil,
    getInventory = nil,
    sendSync = nil
}

local function ensureDataDir()
    if not file.Exists("nexus_inv", "DATA") then
        file.CreateDir("nexus_inv")
    end
end

local function loadRuntime()
    ensureDataDir()
    if not file.Exists(runtimePath, "DATA") then return end

    local raw = file.Read(runtimePath, "DATA")
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then return end

    runtime.recipes = istable(parsed.recipes) and parsed.recipes or nil
end

local function saveRuntime()
    ensureDataDir()
    file.Write(runtimePath, util.TableToJSON(runtime, true))
end

local function readInventoryRuntimeCustomItems()
    ensureDataDir()
    if not file.Exists(invRuntimePath, "DATA") then return {} end

    local raw = file.Read(invRuntimePath, "DATA")
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then return {} end

    local out = {}
    local custom = istable(parsed.customItems) and parsed.customItems or {}

    for k, v in pairs(custom) do
        if isstring(k) and istable(v) then
            out[k] = v
        elseif istable(v) and isstring(v.id) and v.id ~= "" then
            out[v.id] = v
        end
    end

    return out
end

local function getConfigRecipes()
    local cfg = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.Crafting
    if not cfg then return {} end
    if not istable(cfg.recipes) then return {} end
    return cfg.recipes
end

local function sanitizeRecipeId(id)
    id = string.Trim(string.lower(tostring(id or "")))
    if id == "" then return nil end
    if string.find(id, "[^a-z0-9_]", 1) then return nil end
    return id
end

local function normalizeIngredients(src)
    local out = {}

    if not istable(src) then return out end

    for _, row in pairs(src) do
        if istable(row) then
            local rid = tostring(row.id or "")
            local amt = math.max(1, math.floor(tonumber(row.amount) or 1))
            if rid ~= "" then
                out[#out + 1] = { id = rid, amount = amt }
            end
        end
    end

    table.sort(out, function(a, b)
        if a.id == b.id then return a.amount < b.amount end
        return a.id < b.id
    end)

    return out
end

local function normalizeRecipe(id, recipe)
    if not istable(recipe) then return nil end
    if not istable(recipe.result) then return nil end

    local resultId = tostring(recipe.result.id or "")
    if resultId == "" then return nil end

    return {
        name = tostring(recipe.name or id),
        description = tostring(recipe.description or ""),
        category = tostring(recipe.category or "Общее"),
        timeSec = math.max(0, tonumber(recipe.timeSec) or 0),
        result = {
            id = resultId,
            amount = math.max(1, math.floor(tonumber(recipe.result.amount) or 1))
        },
        ingredients = normalizeIngredients(recipe.ingredients)
    }
end

local function mergedRecipes()
    local out = {}

    for id, recipe in pairs(getConfigRecipes()) do
        local rid = sanitizeRecipeId(id)
        if rid then
            local norm = normalizeRecipe(rid, recipe)
            if norm then out[rid] = norm end
        end
    end

    if istable(runtime.recipes) then
        for id, recipe in pairs(runtime.recipes) do
            local rid = sanitizeRecipeId(id)
            if rid then
                local norm = normalizeRecipe(rid, recipe)
                if norm then out[rid] = norm end
            end
        end
    end

    return out
end

local function bindFromReceiver(rx)
    if not isfunction(rx) then return end
    for i = 1, 128 do
        local name, val = debug.getupvalue(rx, i)
        if not name then break end
        if name == "addItem" and isfunction(val) then invApi.addItem = val end
        if name == "removeItem" and isfunction(val) then invApi.removeItem = val end
        if name == "getInventory" and isfunction(val) then invApi.getInventory = val end
        if name == "sendSync" and isfunction(val) then invApi.sendSync = val end
    end
end

local function ensureInvApiBound()
    -- Prefer explicit exported API if present.
    if NEXUS_INV then
        if isfunction(NEXUS_INV.AddItem) then invApi.addItem = NEXUS_INV.AddItem end
        if isfunction(NEXUS_INV.RemoveItem) then invApi.removeItem = NEXUS_INV.RemoveItem end
        if isfunction(NEXUS_INV.GetInventory) then invApi.getInventory = NEXUS_INV.GetInventory end
        if isfunction(NEXUS_INV.SendSync) then invApi.sendSync = NEXUS_INV.SendSync end
    end

    if isfunction(invApi.addItem) and isfunction(invApi.removeItem) and isfunction(invApi.getInventory) and isfunction(invApi.sendSync) then
        return true
    end

    if not istable(net.Receivers) then return false end

    bindFromReceiver(net.Receivers["nexus_inv_vendor_action"])
    bindFromReceiver(net.Receivers["nexus_inv_action"])
    bindFromReceiver(net.Receivers["nexus_inv_request_sync"])

    for _, rx in pairs(net.Receivers) do
        if isfunction(rx) then
            bindFromReceiver(rx)
            if isfunction(invApi.addItem) and isfunction(invApi.removeItem) and isfunction(invApi.getInventory) and isfunction(invApi.sendSync) then
                break
            end
        end
    end

    return isfunction(invApi.addItem) and isfunction(invApi.removeItem) and isfunction(invApi.getInventory) and isfunction(invApi.sendSync)
end

timer.Create("NexusCraftApiBind", 1, 0, function()
    if ensureInvApiBound() then
        timer.Remove("NexusCraftApiBind")
    end
end)

local function isLocalProtected(itemId)
    for _, row in ipairs((NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.LocalItems) or {}) do
        if tostring(row.id or "") == tostring(itemId or "") then
            return true
        end
    end
    return false
end

local function itemName(itemId)
    local cfgItems = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.Items or {}
    local cfgCustom = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.CustomItems or {}
    local runtimeCustom = readInventoryRuntimeCustomItems()

    if istable(cfgItems[itemId]) and isstring(cfgItems[itemId].name) and cfgItems[itemId].name ~= "" then
        return cfgItems[itemId].name
    end
    if istable(runtimeCustom[itemId]) and isstring(runtimeCustom[itemId].name) and runtimeCustom[itemId].name ~= "" then
        return runtimeCustom[itemId].name
    end
    if istable(cfgCustom[itemId]) and isstring(cfgCustom[itemId].name) and cfgCustom[itemId].name ~= "" then
        return cfgCustom[itemId].name
    end

    if string.sub(itemId or "", 1, 8) == "weapon::" then
        local class = string.sub(itemId, 9)
        local stored = weapons.GetStored(class)
        if stored and isstring(stored.PrintName) and stored.PrintName ~= "" then
            return stored.PrintName
        end
        return class
    end

    if string.sub(itemId or "", 1, 10) == "shipment::" then
        return "Ящик: " .. string.sub(itemId, 11)
    end

    if string.sub(itemId or "", 1, 8) == "entity::" then
        return "Энтити: " .. string.sub(itemId, 9)
    end

    return itemId
end

local function allItemIds()
    local out, seen = {}, {}

    local function push(id)
        id = tostring(id or "")
        if id == "" or seen[id] then return end
        seen[id] = true
        out[#out + 1] = id
    end

    for id, _ in pairs((NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.Items) or {}) do push(id) end
    for id, _ in pairs(readInventoryRuntimeCustomItems()) do push(id) end
    for id, _ in pairs((NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.CustomItems) or {}) do push(id) end

    table.sort(out, function(a, b) return a < b end)
    return out
end

local function getInventoryItems(ply)
    if not ensureInvApiBound() then return {} end
    local inv = invApi.getInventory(ply)
    if not istable(inv) then return {} end
    if not istable(inv.items) then return {} end
    return inv.items
end

local function hasMaterials(ply, recipe)
    local items = getInventoryItems(ply)
    for _, row in ipairs(recipe.ingredients or {}) do
        local need = math.max(1, math.floor(tonumber(row.amount) or 1))
        local have = tonumber(items[row.id] or 0) or 0
        if have < need then return false end
    end
    return true
end

local function consumeMaterials(ply, recipe)
    if not ensureInvApiBound() then return false end

    -- First try official remove API.
    local consumed = {}
    for _, row in ipairs(recipe.ingredients or {}) do
        local need = math.max(1, math.floor(tonumber(row.amount) or 1))
        local ok = invApi.removeItem(ply, row.id, need)
        if not ok then
            for _, c in ipairs(consumed) do
                invApi.addItem(ply, c.id, c.amount)
            end
            invApi.sendSync(ply)
            return false
        end
        consumed[#consumed + 1] = { id = row.id, amount = need }
    end

    invApi.sendSync(ply)
    return true
end

local function rewardResult(ply, recipe)
    if not ensureInvApiBound() then return false end

    local res = recipe.result or {}
    local itemId = tostring(res.id or "")
    local amount = math.max(1, math.floor(tonumber(res.amount) or 1))
    if itemId == "" then return false end

    local added = 0
    for _ = 1, amount do
        local ok = invApi.addItem(ply, itemId, 1)
        if not ok then break end
        added = added + 1
    end

    if added <= 0 then return false end

    invApi.sendSync(ply)
    return true
end

local function recipeToClient(recipeId, recipe, ply)
    local out = {
        id = recipeId,
        name = tostring(recipe.name or recipeId),
        description = tostring(recipe.description or ""),
        category = tostring(recipe.category or "Общее"),
        timeSec = math.max(0, tonumber(recipe.timeSec) or 0),
        result = {
            id = tostring(recipe.result and recipe.result.id or ""),
            name = itemName(tostring(recipe.result and recipe.result.id or "")),
            amount = math.max(1, math.floor(tonumber(recipe.result and recipe.result.amount or 1)))
        },
        ingredients = {},
        canCraft = false
    }

    local inv = getInventoryItems(ply)
    local craftable = true

    for _, row in ipairs(recipe.ingredients or {}) do
        local need = math.max(1, math.floor(tonumber(row.amount) or 1))
        local have = tonumber(inv[row.id] or 0) or 0
        if have < need then craftable = false end

        out.ingredients[#out.ingredients + 1] = {
            id = tostring(row.id or ""),
            name = itemName(tostring(row.id or "")),
            amount = need,
            have = have
        }
    end

    out.canCraft = craftable
    return out
end

local function buildPlayerPayload(ply)
    local payload = {
        recipes = {},
        active = nil
    }

    local all = mergedRecipes()
    local rows = {}
    for id, recipe in pairs(all) do
        if istable(recipe) then rows[#rows + 1] = { id = id, recipe = recipe } end
    end
    table.sort(rows, function(a, b) return tostring(a.id) < tostring(b.id) end)

    for _, row in ipairs(rows) do
        payload.recipes[#payload.recipes + 1] = recipeToClient(row.id, row.recipe, ply)
    end

    local current = activeCraft[ply]
    if current then
        payload.active = {
            recipeId = current.recipeId,
            finishAt = current.finishAt
        }
    end

    return payload
end

local function sendCraftSync(ply, openWindow)
    if not IsValid(ply) then return end
    local payload = buildPlayerPayload(ply)

    net.Start(openWindow and "nexus_craft_open" or "nexus_craft_sync")
    net.WriteString(util.TableToJSON(payload, false) or "{}")
    net.Send(ply)
end

local function sendCraftResult(ply, ok, text)
    net.Start("nexus_craft_result")
    net.WriteBool(ok)
    net.WriteString(text or "")
    net.Send(ply)
end

concommand.Add("nexus_craft", function(ply)
    if not IsValid(ply) then return end
    sendCraftSync(ply, true)
end)

net.Receive("nexus_craft_request_sync", function(_, ply)
    if not IsValid(ply) then return end
    sendCraftSync(ply, false)
end)

net.Receive("nexus_craft_start", function(_, ply)
    if not IsValid(ply) then return end
    if activeCraft[ply] then
        sendCraftResult(ply, false, "Крафт уже выполняется.")
        return
    end

    local recipeId = tostring(net.ReadString() or "")
    local recipes = mergedRecipes()
    local recipe = recipes[recipeId]

    if not istable(recipe) then
        sendCraftResult(ply, false, "Рецепт не найден.")
        return
    end

    -- Prevent crafting of local-protected items (they are non-droppable by design in inventory).
    if isLocalProtected(recipe.result and recipe.result.id) then
        sendCraftResult(ply, false, "Результат рецепта — локальный предмет, его нельзя крафтить.")
        return
    end

    for _, row in ipairs(recipe.ingredients or {}) do
        if isLocalProtected(row.id) then
            sendCraftResult(ply, false, "Локальные предметы нельзя использовать как ингредиенты.")
            return
        end
    end

    if not hasMaterials(ply, recipe) then
        sendCraftResult(ply, false, "Недостаточно ресурсов.")
        sendCraftSync(ply, false)
        return
    end

    if not consumeMaterials(ply, recipe) then
        sendCraftResult(ply, false, "Не удалось списать ресурсы.")
        sendCraftSync(ply, false)
        return
    end

    local timeSec = math.max(0, tonumber(recipe.timeSec) or 0)
    if timeSec <= 0 then
        local ok = rewardResult(ply, recipe)
        sendCraftResult(ply, ok, ok and "Предмет создан." or "Не удалось выдать результат.")
        sendCraftSync(ply, false)
        return
    end

    local finishAt = CurTime() + timeSec
    activeCraft[ply] = {
        recipeId = recipeId,
        finishAt = finishAt
    }

    sendCraftResult(ply, true, "Крафт запущен.")
    sendCraftSync(ply, false)

    local timerId = "NexusCraftTimer_" .. ply:SteamID64()
    timer.Create(timerId, timeSec, 1, function()
        if not IsValid(ply) then return end

        local ctx = activeCraft[ply]
        activeCraft[ply] = nil

        local all = mergedRecipes()
        local rec = ctx and all[ctx.recipeId] or nil
        if not rec then
            sendCraftResult(ply, false, "Рецепт удален до завершения.")
            sendCraftSync(ply, false)
            return
        end

        local ok = rewardResult(ply, rec)
        sendCraftResult(ply, ok, ok and "Крафт завершен." or "Не удалось выдать результат.")
        sendCraftSync(ply, false)
    end)
end)

hook.Add("PlayerDisconnected", "NexusCraftCleanup", function(ply)
    activeCraft[ply] = nil
    if IsValid(ply) then
        timer.Remove("NexusCraftTimer_" .. ply:SteamID64())
    end
end)

local function adminPayload()
    local payload = {
        recipes = mergedRecipes(),
        recipeIds = {},
        itemIds = allItemIds()
    }

    for id, _ in pairs(payload.recipes) do
        payload.recipeIds[#payload.recipeIds + 1] = tostring(id)
    end
    table.sort(payload.recipeIds, function(a, b) return a < b end)

    return payload
end

local function sendAdminSync(ply)
    if not IsValid(ply) then return end
    net.Start("nexus_craft_admin_sync")
    net.WriteString(util.TableToJSON(adminPayload(), false) or "{}")
    net.Send(ply)
end

concommand.Add("nexus_craft_admin", function(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    net.Start("nexus_craft_admin_open")
    net.Send(ply)
    sendAdminSync(ply)
end)

net.Receive("nexus_craft_admin_action", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local action = tostring(net.ReadString() or "")
    local data = util.JSONToTable(net.ReadString() or "") or {}

    runtime.recipes = runtime.recipes or {}

    if action == "recipe_upsert" then
        local id = sanitizeRecipeId(data.recipeId)
        if id then
            local normalized = normalizeRecipe(id, data.recipe)
            if normalized then
                runtime.recipes[id] = normalized
            end
        end

    elseif action == "recipe_remove" then
        local id = sanitizeRecipeId(data.recipeId)
        if id then runtime.recipes[id] = nil end
    end

    saveRuntime()
    sendAdminSync(ply)
    sendCraftSync(ply, false)
end)

loadRuntime()