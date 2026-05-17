XPDRP = XPDRP or {}
XPDRP.Inventory = XPDRP.Inventory or {}

util.AddNetworkString("xpdrp_inv_sync")
util.AddNetworkString("xpdrp_inv_req_use")
util.AddNetworkString("xpdrp_inv_req_drop")
util.AddNetworkString("xpdrp_inv_req_craft")
util.AddNetworkString("xpdrp_inv_req_buy")
util.AddNetworkString("xpdrp_inv_req_sell")
util.AddNetworkString("xpdrp_inv_req_open_merchant")
util.AddNetworkString("xpdrp_inv_open_merchant")

local DB_TABLE = "xpdrp_inventory"
local lock = {}
local inv = {}

local function steamKey(ply)
    return IsValid(ply) and ply:SteamID64() or nil
end

local function ensureDb()
    sql.Query("CREATE TABLE IF NOT EXISTS " .. DB_TABLE .. " (steamid64 TEXT PRIMARY KEY, data TEXT NOT NULL, updated INTEGER NOT NULL)")
end

local function makeEmpty()
    local slots = {}
    for i = 1, XPDRP.Inventory.Config.MaxSlots do
        slots[i] = false
    end
    return slots
end

local function normalizeSlot(slot)
    if not istable(slot) or not isstring(slot.id) then return false end

    local item = XPDRP.Inventory.GetItem(slot.id)
    if not item then return false end

    slot.amount = math.max(1, math.floor(tonumber(slot.amount) or 1))
    slot.amount = math.min(slot.amount, item.stack or XPDRP.Inventory.Config.MaxStack)
    return slot
end

local function sanitizeInventory(raw)
    local slots = makeEmpty()
    if not istable(raw) then return slots end

    for i = 1, XPDRP.Inventory.Config.MaxSlots do
        local slot = normalizeSlot(raw[i])
        slots[i] = slot or false
    end

    return slots
end

local function savePlayerInventory(ply)
    local key = steamKey(ply)
    if not key or not inv[key] then return end

    local data = util.TableToJSON(inv[key])
    if not data then return end

    sql.Query("REPLACE INTO " .. DB_TABLE .. " (steamid64, data, updated) VALUES (" ..
        sql.SQLStr(key) .. ", " ..
        sql.SQLStr(data) .. ", " ..
        sql.SQLStr(tostring(os.time())) .. ")")
end

local function loadPlayerInventory(ply)
    local key = steamKey(ply)
    if not key then return end

    local row = sql.QueryRow("SELECT data FROM " .. DB_TABLE .. " WHERE steamid64 = " .. sql.SQLStr(key))
    if not row or not row.data then
        inv[key] = makeEmpty()
        return
    end

    local data = util.JSONToTable(row.data)
    inv[key] = sanitizeInventory(data)
end

local function getInv(ply)
    local key = steamKey(ply)
    if not key then return makeEmpty() end
    inv[key] = inv[key] or makeEmpty()
    return inv[key]
end

local function sync(ply)
    if not IsValid(ply) then return end
    net.Start("xpdrp_inv_sync")
    net.WriteUInt(XPDRP.Inventory.Config.MaxSlots, 8)
    net.WriteTable(getInv(ply))
    net.Send(ply)
end

local function canStack(id, amountInSlot, addAmount)
    local item = XPDRP.Inventory.GetItem(id)
    if not item then return false end
    return (amountInSlot + addAmount) <= (item.stack or XPDRP.Inventory.Config.MaxStack)
end

function XPDRP.Inventory.AddItem(ply, id, amount)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    local item = XPDRP.Inventory.GetItem(id)
    if not item then return false end

    local slots = getInv(ply)
    local left = amount

    for i = 1, XPDRP.Inventory.Config.MaxSlots do
        local s = slots[i]
        if s and s.id == id and s.amount < (item.stack or XPDRP.Inventory.Config.MaxStack) then
            local free = (item.stack or XPDRP.Inventory.Config.MaxStack) - s.amount
            local take = math.min(free, left)
            s.amount = s.amount + take
            left = left - take
            if left <= 0 then break end
        end
    end

    for i = 1, XPDRP.Inventory.Config.MaxSlots do
        if left <= 0 then break end
        if not slots[i] then
            local take = math.min(left, item.stack or XPDRP.Inventory.Config.MaxStack)
            slots[i] = { id = id, amount = take }
            left = left - take
        end
    end

    return left <= 0
end

local function removeFromSlot(ply, slotIndex, amount)
    local slots = getInv(ply)
    local slot = slots[slotIndex]
    if not slot then return false end

    amount = math.max(1, math.floor(tonumber(amount) or 1))
    if amount > slot.amount then return false end

    slot.amount = slot.amount - amount
    if slot.amount <= 0 then
        slots[slotIndex] = false
    end

    return true, slot.id
end

local function countItem(ply, id)
    local slots = getInv(ply)
    local c = 0
    for i = 1, XPDRP.Inventory.Config.MaxSlots do
        local s = slots[i]
        if s and s.id == id then
            c = c + s.amount
        end
    end
    return c
end

local function removeById(ply, id, amount)
    local slots = getInv(ply)
    local left = amount

    for i = 1, XPDRP.Inventory.Config.MaxSlots do
        if left <= 0 then break end
        local s = slots[i]
        if s and s.id == id then
            local take = math.min(left, s.amount)
            s.amount = s.amount - take
            left = left - take
            if s.amount <= 0 then
                slots[i] = false
            end
        end
    end

    return left <= 0
end

local function money(ply)
    if not IsValid(ply) then return 0 end
    if ply.getDarkRPVar then
        return tonumber(ply:getDarkRPVar("money") or 0) or 0
    end
    return 0
end

local function addMoney(ply, amount)
    if not IsValid(ply) then return end
    if ply.addMoney then
        ply:addMoney(amount)
        return
    end

    if ply.setDarkRPVar and ply.getDarkRPVar then
        ply:setDarkRPVar("money", money(ply) + amount)
    end
end

local function withLock(ply, fn)
    local key = steamKey(ply)
    if not key then return end
    if lock[key] then return end

    lock[key] = true
    local ok, err = pcall(fn)
    lock[key] = nil

    if not ok then
        ErrorNoHalt("[XPDRP Inventory] " .. tostring(err) .. "\n")
    end

    savePlayerInventory(ply)
    sync(ply)
end

local function getMerchantFromEnt(ent)
    if not IsValid(ent) then return nil end
    local id = ent:GetNWString("XPDRP_MerchantID", "")
    if id == "" then return nil end
    return XPDRP.Inventory.GetMerchant(id), id
end

net.Receive("xpdrp_inv_req_use", function(_, ply)
    local slot = math.Clamp(net.ReadUInt(8), 1, XPDRP.Inventory.Config.MaxSlots)

    withLock(ply, function()
        local slots = getInv(ply)
        local s = slots[slot]
        if not s then return end

        local item = XPDRP.Inventory.GetItem(s.id)
        if not item or not isfunction(item.use) then return end

        if item.use(ply, s) then
            removeFromSlot(ply, slot, 1)
        end
    end)
end)

net.Receive("xpdrp_inv_req_drop", function(_, ply)
    local slot = math.Clamp(net.ReadUInt(8), 1, XPDRP.Inventory.Config.MaxSlots)
    local amount = math.Clamp(net.ReadUInt(8), 1, XPDRP.Inventory.Config.MaxStack)

    withLock(ply, function()
        local ok = removeFromSlot(ply, slot, amount)
        if not ok then return end

        if XPDRP.Inventory.Config.DropDeleteOnly then
            if DarkRP and DarkRP.notify then
                DarkRP.notify(ply, 0, 3, "Предмет выброшен.")
            end
        end
    end)
end)

net.Receive("xpdrp_inv_req_craft", function(_, ply)
    local id = net.ReadString()
    local amount = math.Clamp(net.ReadUInt(8), 1, 20)

    withLock(ply, function()
        local recipe = XPDRP.Inventory.GetRecipe(id)
        if not recipe then return end

        for itemId, reqAmount in pairs(recipe.require) do
            if countItem(ply, itemId) < (reqAmount * amount) then
                return
            end
        end

        for itemId, reqAmount in pairs(recipe.require) do
            removeById(ply, itemId, reqAmount * amount)
        end

        XPDRP.Inventory.AddItem(ply, recipe.result, recipe.amount * amount)
    end)
end)

net.Receive("xpdrp_inv_req_open_merchant", function(_, ply)
    local tr = ply:GetEyeTrace()
    local ent = tr and tr.Entity
    local merchant, id = getMerchantFromEnt(ent)
    if not merchant then return end

    if ply:GetPos():DistToSqr(ent:GetPos()) > (XPDRP.Inventory.Config.MerchantUseDistance ^ 2) then
        return
    end

    net.Start("xpdrp_inv_open_merchant")
    net.WriteString(id)
    net.WriteTable(merchant)
    net.Send(ply)
end)

net.Receive("xpdrp_inv_req_buy", function(_, ply)
    local merchantId = net.ReadString()
    local itemId = net.ReadString()
    local amount = math.Clamp(net.ReadUInt(8), 1, 30)

    withLock(ply, function()
        local m = XPDRP.Inventory.GetMerchant(merchantId)
        if not m then return end

        local price = tonumber(m.buy[itemId])
        if not price or price <= 0 then return end

        local total = price * amount
        if money(ply) < total then return end

        if not XPDRP.Inventory.AddItem(ply, itemId, amount) then return end
        addMoney(ply, -total)
    end)
end)

net.Receive("xpdrp_inv_req_sell", function(_, ply)
    local merchantId = net.ReadString()
    local slot = math.Clamp(net.ReadUInt(8), 1, XPDRP.Inventory.Config.MaxSlots)
    local amount = math.Clamp(net.ReadUInt(8), 1, XPDRP.Inventory.Config.MaxStack)

    withLock(ply, function()
        local m = XPDRP.Inventory.GetMerchant(merchantId)
        if not m then return end

        local slots = getInv(ply)
        local s = slots[slot]
        if not s then return end

        local sellPrice = tonumber(m.sell[s.id])
        if not sellPrice or sellPrice <= 0 then return end

        if amount > s.amount then amount = s.amount end
        local ok = removeFromSlot(ply, slot, amount)
        if not ok then return end

        addMoney(ply, sellPrice * amount)
    end)
end)

local spawnedMerchants = {}

local function spawnMerchants()
    for _, ent in ipairs(spawnedMerchants) do
        if IsValid(ent) then ent:Remove() end
    end
    spawnedMerchants = {}

    local map = game.GetMap()
    for id, data in pairs(XPDRP.Inventory.Merchants) do
        local list = data.spawns and data.spawns[map]
        if not istable(list) then continue end

        for _, spawnData in ipairs(list) do
            local npc = ents.Create("npc_citizen")
            if not IsValid(npc) then continue end

            npc:SetModel(data.model)
            npc:SetPos(spawnData.pos)
            npc:SetAngles(spawnData.ang)
            npc:SetKeyValue("citizentype", "4")
            npc:Spawn()
            npc:Activate()
            npc:SetNPCState(NPC_STATE_SCRIPT)
            npc:SetMoveType(MOVETYPE_NONE)
            npc:SetSolid(SOLID_BBOX)
            npc:SetUseType(SIMPLE_USE)
            npc:SetNWString("XPDRP_MerchantID", id)
            npc:SetNWString("XPDRP_MerchantName", data.name)

            spawnedMerchants[#spawnedMerchants + 1] = npc
        end
    end
end

hook.Add("InitPostEntity", "XPDRP.Inventory.SpawnMerchants", spawnMerchants)

hook.Add("PlayerInitialSpawn", "XPDRP.Inventory.Load", function(ply)
    timer.Simple(0.4, function()
        if not IsValid(ply) then return end
        loadPlayerInventory(ply)
        sync(ply)
    end)
end)

hook.Add("PlayerDisconnected", "XPDRP.Inventory.SaveDisconnect", function(ply)
    savePlayerInventory(ply)
end)

timer.Create("XPDRP.Inventory.AutoSave", XPDRP.Inventory.Config.SaveInterval or 45, 0, function()
    for _, ply in ipairs(player.GetHumans()) do
        savePlayerInventory(ply)
    end
end)

ensureDb()
