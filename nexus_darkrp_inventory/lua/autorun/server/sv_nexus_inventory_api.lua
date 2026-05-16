if CLIENT then return end

-- Bridge for loot bins: binds internal inventory add/sync functions to public API.
timer.Create("NexusInvApiBridgeInit", 1, 0, function()
    if not istable(net.Receivers) then return end
    if not istable(NEXUS_INV) then return end
    if isfunction(NEXUS_INV.AddItem) and isfunction(NEXUS_INV.SendSync) then
        timer.Remove("NexusInvApiBridgeInit")
        return
    end

    local receiver = net.Receivers["nexus_inv_vendor_action"]
        or net.Receivers["NEXUS_INV_VENDOR_ACTION"]

    if not isfunction(receiver) then return end

    local foundAdd, foundSync = nil, nil
    for i = 1, 64 do
        local name, val = debug.getupvalue(receiver, i)
        if not name then break end
        if name == "addItem" and isfunction(val) then foundAdd = val end
        if name == "sendSync" and isfunction(val) then foundSync = val end
    end

    if foundAdd then NEXUS_INV.AddItem = foundAdd end
    if foundSync then NEXUS_INV.SendSync = foundSync end

    if isfunction(NEXUS_INV.AddItem) and isfunction(NEXUS_INV.SendSync) then
        print("[nexus_darkrp_inventory] Inventory API bridge attached (AddItem/SendSync).")
        timer.Remove("NexusInvApiBridgeInit")
    end
end)