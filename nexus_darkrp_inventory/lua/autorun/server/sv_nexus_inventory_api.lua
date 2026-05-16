if CLIENT then return end

-- Универсальный мост API инвентаря для других модулей (майнинг, фермерство и т.д.)
timer.Create("NexusInvApiBridgeInit", 1, 0, function()
    if not istable(net.Receivers) then return end
    if not istable(NEXUS_INV) then return end

    if isfunction(NEXUS_INV.AddItem)
        and isfunction(NEXUS_INV.RemoveItem)
        and isfunction(NEXUS_INV.GetInventory)
        and isfunction(NEXUS_INV.SendSync) then
        timer.Remove("NexusInvApiBridgeInit")
        return
    end

    local found = {
        addItem = nil,
        removeItem = nil,
        getInventory = nil,
        sendSync = nil
    }

    local function scanReceiver(rx)
        if not isfunction(rx) then return end
        for i = 1, 256 do
            local name, val = debug.getupvalue(rx, i)
            if not name then break end

            if name == "addItem" and isfunction(val) then found.addItem = val end
            if name == "removeItem" and isfunction(val) then found.removeItem = val end
            if name == "getInventory" and isfunction(val) then found.getInventory = val end
            if name == "sendSync" and isfunction(val) then found.sendSync = val end
        end
    end

    scanReceiver(net.Receivers["nexus_inv_action"])
    scanReceiver(net.Receivers["nexus_inv_vendor_action"])
    scanReceiver(net.Receivers["nexus_inv_request_sync"])

    if not (found.addItem and found.removeItem and found.getInventory and found.sendSync) then
        for _, rx in pairs(net.Receivers) do
            scanReceiver(rx)
            if found.addItem and found.removeItem and found.getInventory and found.sendSync then
                break
            end
        end
    end

    if found.addItem then NEXUS_INV.AddItem = found.addItem end
    if found.removeItem then NEXUS_INV.RemoveItem = found.removeItem end
    if found.getInventory then NEXUS_INV.GetInventory = found.getInventory end
    if found.sendSync then NEXUS_INV.SendSync = found.sendSync end

    if isfunction(NEXUS_INV.AddItem)
        and isfunction(NEXUS_INV.RemoveItem)
        and isfunction(NEXUS_INV.GetInventory)
        and isfunction(NEXUS_INV.SendSync) then
        print("[nexus_darkrp_inventory] Inventory API bridge attached (AddItem/RemoveItem/GetInventory/SendSync).")
        timer.Remove("NexusInvApiBridgeInit")
    end
end)