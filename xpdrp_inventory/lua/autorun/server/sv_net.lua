XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

local Inv = XPDRP.Inv

util.AddNetworkString("XPDRP.Inv.Sync")
util.AddNetworkString("XPDRP.Inv.RequestSync")
util.AddNetworkString("XPDRP.Inv.Action")

local function syncPlayer(ply)
    if not IsValid(ply) then return end
    local data = Inv.GetPlayerData(ply)

    net.Start("XPDRP.Inv.Sync")
    net.WriteTable({
        balance = Inv.GetPlayerBalance(ply, data),
        maxSlots = data.maxSlots,
        slots = data.slots,
        customItems = data.customItems,
        items = Inv.GetItemMapFor(data),
        recipes = Inv.Recipes,
        traders = Inv.Traders,
        skillPoints = tonumber(data.skillPoints) or 0,
        playtimeSeconds = tonumber(data.playtimeSeconds) or 0,
        skills = data.skills or {},
        skillsConfig = (XPDRP.Skills and XPDRP.Skills.Config) or {}
    })
    net.Send(ply)
end

function Inv.SyncPlayer(ply)
    syncPlayer(ply)
end

hook.Add("PlayerInitialSpawn", "XPDRP.Inv.InitialSync", function(ply)
    Inv.GetPlayerData(ply)
    timer.Simple(2, function()
        if IsValid(ply) then
            syncPlayer(ply)
        end
    end)
end)

hook.Add("PlayerDisconnected", "XPDRP.Inv.SaveOnDisconnect", function(ply)
    Inv.SavePlayerData(ply)
end)

hook.Add("KeyPress", "XPDRP.Inv.ShiftUsePickup", function(ply, key)
    if key ~= IN_USE then return end
    if not ply:KeyDown(IN_SPEED) then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsValid(ent) then return end
    if tr.HitPos:DistToSqr(ply:GetShootPos()) > (Inv.Config.PickupDistance * Inv.Config.PickupDistance) then
        return
    end

    local data = Inv.GetPlayerData(ply)
    local ok, err = Inv.PickupEntity(ply, data, ent)
    if not ok then
        if err then ply:ChatPrint("[Inventory] " .. err) end
        return
    end

    Inv.SavePlayerData(ply)
    syncPlayer(ply)
end)

net.Receive("XPDRP.Inv.RequestSync", function(_, ply)
    syncPlayer(ply)
end)

net.Receive("XPDRP.Inv.Action", function(_, ply)
    local payload = net.ReadTable() or {}
    local action = tostring(payload.action or "")
    local txid = tostring(payload.txid or "")
    if txid == "" then return end

    local data = Inv.GetPlayerData(ply)
    if not Inv.PushTx(data, txid) then
        syncPlayer(ply)
        return
    end

    local ok, err = false, "Неизвестная операция"

    if action == "craft" then
        ok, err = Inv.ActionCraft(data, tostring(payload.recipeId or ""))
    elseif action == "trader_buy" then
        ok, err = Inv.ActionTraderBuy(
            ply,
            data,
            tostring(payload.traderId or ""),
            tonumber(payload.offerIndex or 0) or 0,
            tonumber(payload.traderEnt or 0) or 0
        )
    elseif action == "trader_sell" then
        ok, err = Inv.ActionTraderSell(
            ply,
            data,
            tostring(payload.traderId or ""),
            tonumber(payload.offerIndex or 0) or 0,
            tonumber(payload.traderEnt or 0) or 0
        )
    elseif action == "custom_create" then
        ok, err = Inv.ActionCreateCustom(data, payload)
    elseif action == "admin" then
        ok, err = Inv.ActionAdmin(ply, payload)
    elseif action == "use_item" then
        ok, err = Inv.ActionUseItem(ply, data, tostring(payload.itemId or ""))
    elseif action == "drop_item" then
        ok, err = Inv.ActionDropItem(ply, data, tostring(payload.itemId or ""), tonumber(payload.qty or 1) or 1)
    elseif action == "skill_upgrade" then
        ok, err = Inv.ActionSkillUpgrade(ply, data, tostring(payload.skillId or ""))
    end

    if ok then
        Inv.SavePlayerData(ply)
    else
        ply:ChatPrint("[Inventory] " .. tostring(err or "Ошибка"))
    end

    syncPlayer(ply)
end)