if CLIENT then return end

local invApi = {
    addItem = nil,
    sendSync = nil
}

local function bindFromReceiver(rx)
    if not isfunction(rx) then return end
    for i = 1, 128 do
        local name, val = debug.getupvalue(rx, i)
        if not name then break end
        if name == "addItem" and isfunction(val) then invApi.addItem = val end
        if name == "sendSync" and isfunction(val) then invApi.sendSync = val end
    end
end

local function ensureBound()
    if NEXUS_INV then
        if isfunction(NEXUS_INV.AddItem) then invApi.addItem = NEXUS_INV.AddItem end
        if isfunction(NEXUS_INV.SendSync) then invApi.sendSync = NEXUS_INV.SendSync end
    end

    if isfunction(invApi.addItem) and isfunction(invApi.sendSync) then
        return true
    end

    if not istable(net.Receivers) then return false end
    bindFromReceiver(net.Receivers["nexus_inv_vendor_action"])
    bindFromReceiver(net.Receivers["nexus_inv_action"])
    bindFromReceiver(net.Receivers["nexus_inv_request_sync"])

    for _, rx in pairs(net.Receivers) do
        if isfunction(rx) then
            bindFromReceiver(rx)
            if isfunction(invApi.addItem) and isfunction(invApi.sendSync) then
                break
            end
        end
    end

    return isfunction(invApi.addItem) and isfunction(invApi.sendSync)
end

timer.Create("NexusInvGiveBind", 1, 0, function()
    if ensureBound() then
        timer.Remove("NexusInvGiveBind")
    end
end)

local function findPlayerBySteamID64(sid64)
    sid64 = tostring(sid64 or "")
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:SteamID64() == sid64 then
            return p
        end
    end
    return nil
end

concommand.Add("nexus_inv_admin_give", function(ply, _, args)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    if not ensureBound() then
        ply:ChatPrint("[NEXUS] Inventory API not ready.")
        return
    end

    local targetSid64 = tostring(args[1] or "")
    local itemId = tostring(args[2] or "")
    local amount = math.max(1, math.floor(tonumber(args[3]) or 1))

    if itemId == "" then
        ply:ChatPrint("[NEXUS] Empty item id.")
        return
    end

    local target = findPlayerBySteamID64(targetSid64)
    if not IsValid(target) then target = ply end

    local ok = invApi.addItem(target, itemId, amount)
    if not ok then
        ply:ChatPrint("[NEXUS] Failed to give item (unknown item or stack full).")
        return
    end

    invApi.sendSync(target)

    if target == ply then
        ply:ChatPrint("[NEXUS] Given: " .. itemId .. " x" .. amount)
    else
        ply:ChatPrint("[NEXUS] Given to " .. target:Nick() .. ": " .. itemId .. " x" .. amount)
        target:ChatPrint("[NEXUS] You received: " .. itemId .. " x" .. amount)
    end
end)