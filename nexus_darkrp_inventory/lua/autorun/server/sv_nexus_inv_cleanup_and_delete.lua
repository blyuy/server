if CLIENT then return end

util.AddNetworkString("nexus_inv_delete")

local invApi = {
    removeItem = nil,
    getInventory = nil,
    sendSync = nil
}

local function isProtectedBaseLocal(itemId)
    for _, row in ipairs((NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.LocalItems) or {}) do
        if tostring(row.id or "") == tostring(itemId or "") then
            return true
        end
    end
    return false
end

local function bindFromReceiver(rx)
    if not isfunction(rx) then return end
    for i = 1, 128 do
        local name, val = debug.getupvalue(rx, i)
        if not name then break end
        if name == "removeItem" and isfunction(val) then invApi.removeItem = val end
        if name == "getInventory" and isfunction(val) then invApi.getInventory = val end
        if name == "sendSync" and isfunction(val) then invApi.sendSync = val end
    end
end

local function ensureInvApiBound()
    if isfunction(invApi.removeItem) and isfunction(invApi.getInventory) and isfunction(invApi.sendSync) then
        return true
    end

    if not istable(net.Receivers) then return false end

    bindFromReceiver(net.Receivers["nexus_inv_action"])
    bindFromReceiver(net.Receivers["nexus_inv_vendor_action"])
    bindFromReceiver(net.Receivers["nexus_inv_request_sync"])

    for _, rx in pairs(net.Receivers) do
        if isfunction(rx) then
            bindFromReceiver(rx)
            if isfunction(invApi.removeItem) and isfunction(invApi.getInventory) and isfunction(invApi.sendSync) then
                break
            end
        end
    end

    return isfunction(invApi.removeItem) and isfunction(invApi.getInventory) and isfunction(invApi.sendSync)
end

local function cleanupRuntimeLocalItems()
    local path = "nexus_inv/runtime.json"
    if not file.Exists(path, "DATA") then return end

    local raw = file.Read(path, "DATA")
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then return end

    local localItems = istable(parsed.localItems) and parsed.localItems or {}
    local filtered = {}
    local changed = false

    for _, row in ipairs(localItems) do
        local id = tostring(row.id or "")
        local amt = math.max(1, math.floor(tonumber(row.amount) or 1))
        if isProtectedBaseLocal(id) then
            filtered[#filtered + 1] = { id = id, amount = amt }
        else
            changed = true
        end
    end

    if changed then
        parsed.localItems = filtered
        file.Write(path, util.TableToJSON(parsed, true))
        print("[nexus_darkrp_inventory] Runtime localItems cleaned: non-base local entries removed.")
    end
end

timer.Simple(0, cleanupRuntimeLocalItems)
timer.Create("NexusInvDeleteApiBind", 1, 0, function()
    if ensureInvApiBound() then
        timer.Remove("NexusInvDeleteApiBind")
    end
end)

net.Receive("nexus_inv_delete", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ensureInvApiBound() then return end

    local itemId = tostring(net.ReadString() or "")
    local amount = math.max(1, net.ReadUInt(16))

    if itemId == "" then return end
    if isProtectedBaseLocal(itemId) then
        ply:ChatPrint("[NEXUS] Этот локальный предмет нельзя удалить.")
        return
    end

    local inv = invApi.getInventory(ply)
    if not istable(inv) or not istable(inv.items) then return end

    local have = tonumber(inv.items[itemId] or 0) or 0
    if have <= 0 then return end

    amount = math.min(amount, have)
    local ok = invApi.removeItem(ply, itemId, amount)
    if not ok then return end

    invApi.sendSync(ply)
end)