if CLIENT then return end

AddCSLuaFile("autorun/sh_nexus_inv_config.lua")
AddCSLuaFile("autorun/client/cl_nexus_inventory.lua")
AddCSLuaFile("autorun/client/cl_nexus_inv_admin.lua")

util.AddNetworkString("nexus_inv_open")
util.AddNetworkString("nexus_inv_sync")
util.AddNetworkString("nexus_inv_request_sync")
util.AddNetworkString("nexus_inv_action")
util.AddNetworkString("nexus_inv_pickup")
util.AddNetworkString("nexus_inv_vendor_open")
util.AddNetworkString("nexus_inv_vendor_action")
util.AddNetworkString("nexus_inv_admin_open")
util.AddNetworkString("nexus_inv_admin_sync")
util.AddNetworkString("nexus_inv_admin_action")

NEXUS_INV = NEXUS_INV or {}

local inventories = {}
local addItem
local sendSync
local runtimePath = "nexus_inv/runtime.json"
local runtime = {
    localItems = nil,
    vendorProfiles = nil
}

local function cfg(group, key, fallback)
    local section = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG[group]
    if not section then return fallback end
    local value = section[key]
    if value == nil then return fallback end
    return value
end

local function loadRuntime()
    if not file.Exists("nexus_inv", "DATA") then
        file.CreateDir("nexus_inv")
    end

    if not file.Exists(runtimePath, "DATA") then return end

    local raw = file.Read(runtimePath, "DATA")
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then return end

    runtime.localItems = istable(parsed.localItems) and parsed.localItems or nil
    runtime.vendorProfiles = istable(parsed.vendorProfiles) and parsed.vendorProfiles or nil
end

local function saveRuntime()
    if not file.Exists("nexus_inv", "DATA") then
        file.CreateDir("nexus_inv")
    end

    file.Write(runtimePath, util.TableToJSON(runtime, true))
end

local function localItemsTable()
    if istable(runtime.localItems) then return runtime.localItems end
    return NEXUS_INV_CONFIG.LocalItems or {}
end

local function vendorProfilesTable()
    if istable(runtime.vendorProfiles) then return runtime.vendorProfiles end
    return NEXUS_INV_CONFIG.VendorProfiles or {}
end

loadRuntime()

local function itemDef(itemId)
    local static = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.Items and NEXUS_INV_CONFIG.Items[itemId] or nil
    if static then return static end

    if string.sub(itemId or "", 1, 8) ~= "weapon::" then
        -- Dynamic shipment item
        if string.sub(itemId or "", 1, 10) == "shipment::" then
            local class = string.sub(itemId, 11)
            local title = class
            local model = "models/items/ammocrate_smg1.mdl"

            for _, shipment in ipairs(CustomShipments or {}) do
                if shipment.entity == class or shipment.name == class then
                    title = shipment.name or class
                    model = shipment.model or model
                    break
                end
            end

            return {
                name = "Ящик: " .. title,
                model = model,
                description = "Купленный ящик оружия.",
                maxStack = 20,
                canDrop = true,
                canSell = false
            }
        end

        -- Dynamic spawned DarkRP entity item
        if string.sub(itemId or "", 1, 8) == "entity::" then
            local class = string.sub(itemId, 9)
            return {
                name = "Энтити: " .. class,
                model = "models/props_lab/box01a.mdl",
                description = "Сохраненная покупная энтити.",
                maxStack = 20,
                canDrop = true,
                canSell = false
            }
        end

        return nil
    end

    local class = string.sub(itemId, 9)
    if class == "" then return nil end

    local stored = weapons.GetStored(class)
    local name = (stored and stored.PrintName and stored.PrintName ~= "") and stored.PrintName or class
    local model = (stored and stored.WorldModel and stored.WorldModel ~= "") and stored.WorldModel or "models/weapons/w_pistol.mdl"

    return {
        name = name,
        model = model,
        description = "Оружие. Используйте, чтобы выдать себе.",
        maxStack = 1,
        canDrop = true,
        canSell = false,
        useType = "equip_weapon",
        weaponClass = class
    }
end

local function weaponItemId(class)
    return "weapon::" .. tostring(class or "")
end

local function shipmentItemId(class)
    return "shipment::" .. tostring(class or "")
end

local function entityItemId(class)
    return "entity::" .. tostring(class or "")
end

local function normalizedWeaponClass(ent)
    if not IsValid(ent) then return nil end

    local class = ent:GetClass()
    if class == "spawned_weapon" or class == "dropped_weapon" then
        local nestedWeaponClass = nil
        if ent.GetWeapon and IsValid(ent:GetWeapon()) then
            nestedWeaponClass = ent:GetWeapon():GetClass()
        elseif IsValid(ent.weapon) and ent.weapon.GetClass then
            nestedWeaponClass = ent.weapon:GetClass()
        end

        local candidates = {
            nestedWeaponClass,
            ent.GetweaponClass and ent:GetweaponClass() or nil,
            ent.GetWeaponClass and ent:GetWeaponClass() or nil,
            ent.getWeaponClass and ent:getWeaponClass() or nil,
            ent.GetNWString and ent:GetNWString("WeaponClass", "") or nil,
            ent.GetNW2String and ent:GetNW2String("WeaponClass", "") or nil,
            ent.GetNWString and ent:GetNWString("weaponclass", "") or nil,
            ent.GetNW2String and ent:GetNW2String("weaponclass", "") or nil,
            ent.GetDTString and ent:GetDTString(0) or nil,
            ent.weaponclass,
            ent.weaponClass,
            ent.dt and ent.dt.WeaponClass or nil,
            ent.GetTable and ent:GetTable().WeaponClass or nil,
            ent.GetTable and ent:GetTable().weaponclass or nil,
            ent:GetInternalVariable("WeaponClass")
        }

        for _, cand in ipairs(candidates) do
            if isstring(cand) and cand ~= "" then
                class = cand
                break
            end
        end

        if (not isstring(class) or class == "" or class == "spawned_weapon" or class == "dropped_weapon") and ent.GetModel then
            local mdl = string.lower(ent:GetModel() or "")
            if mdl ~= "" then
                for _, wep in ipairs(weapons.GetList() or {}) do
                    local wm = string.lower(tostring(wep.WorldModel or ""))
                    if wm ~= "" and wm == mdl and isstring(wep.ClassName) and wep.ClassName ~= "" then
                        class = wep.ClassName
                        break
                    end
                end
            end
        end
    end

    if not isstring(class) or class == "" then return nil end
    class = string.lower(class)
    if class == "spawned_weapon" or class == "dropped_weapon" then return nil end
    if string.StartWith(class, "weapon_") then return class end
    if weapons.GetStored(class) then return class end
    return class
end

local function normalizedShipmentClass(ent)
    if not IsValid(ent) or ent:GetClass() ~= "spawned_shipment" then return nil end

    local candidates = {
        ent.Getcontents and ent:Getcontents() or nil,
        ent.GetContents and ent:GetContents() or nil,
        ent.GetNWString and ent:GetNWString("contents", "") or nil,
        ent.GetNW2String and ent:GetNW2String("contents", "") or nil,
        ent.GetNWString and ent:GetNWString("shipmentClass", "") or nil,
        ent.GetNW2String and ent:GetNW2String("shipmentClass", "") or nil,
        ent:GetInternalVariable("contents")
    }

    for _, cand in ipairs(candidates) do
        if istable(cand) then
            if isstring(cand.entity) and cand.entity ~= "" then
                return cand.entity
            end

            if isstring(cand.name) and cand.name ~= "" then
                return cand.name
            end
        end

        if isstring(cand) and cand ~= "" then
            return cand
        end
    end

    return nil
end

local function normalizedShipmentCount(ent)
    local candidates = {
        ent.Getcount and ent:Getcount() or nil,
        ent.GetCount and ent:GetCount() or nil,
        ent.GetNWInt and ent:GetNWInt("count", 0) or nil,
        ent:GetInternalVariable("count")
    }

    for _, cand in ipairs(candidates) do
        local n = tonumber(cand)
        if n and n > 0 then return math.floor(n) end
    end

    return 1
end

local function normalizedSpawnedEntityClass(ent)
    if not IsValid(ent) or ent:GetClass() ~= "spawned_entity" then return nil end

    local candidates = {
        ent.GetentClass and ent:GetentClass() or nil,
        ent.GetEntityClass and ent:GetEntityClass() or nil,
        ent.GetNWString and ent:GetNWString("entClass", "") or nil,
        ent:GetInternalVariable("entClass")
    }

    for _, cand in ipairs(candidates) do
        if isstring(cand) and cand ~= "" then
            return cand
        end
    end

    return "spawned_entity"
end

local function isWeaponEntity(ent)
    if not IsValid(ent) then return false end
    if ent:IsWeapon() then return true end

    local class = ent:GetClass() or ""
    if class == "dropped_weapon" then return true end
    if class == "spawned_weapon" then return true end
    return string.StartWith(class, "weapon_")
end

local function isPickupShipment(ent)
    return IsValid(ent) and ent:GetClass() == "spawned_shipment"
end

local function isPickupSpawnedEntity(ent)
    return IsValid(ent) and ent:GetClass() == "spawned_entity"
end

local function isPlayerOwnedEntity(ent)
    if not IsValid(ent) then return false end

    local class = ent:GetClass() or ""
    if class == "spawned_weapon" or class == "dropped_weapon" or class == "spawned_shipment" then
        return false
    end

    local owner = ent.GetOwner and ent:GetOwner() or NULL
    if IsValid(owner) and owner:IsPlayer() and ent:IsWeapon() then
        if owner:GetActiveWeapon() == ent then
            return true
        end
    end

    local parent = ent.GetParent and ent:GetParent() or NULL
    if IsValid(parent) and parent:IsPlayer() then return true end

    return false
end

local function tryPickupEntity(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return false end

    if ply:GetPos():Distance(ent:GetPos()) > cfg("Settings", "pickupDistance", 120) then
        return false
    end

    local rule = NEXUS_INV_CONFIG.PickupEntities and NEXUS_INV_CONFIG.PickupEntities[ent:GetClass()]

    if not rule and isWeaponEntity(ent) then
        if isPlayerOwnedEntity(ent) then return false end

        local class = normalizedWeaponClass(ent)
        if not class then return false end

        local ok = addItem(ply, weaponItemId(class), 1)
        if not ok then return false end

        ent:Remove()
        sendSync(ply)
        return true
    end

    if not rule and isPickupShipment(ent) then
        local class = normalizedShipmentClass(ent)
        if not class then return false end

        local count = math.max(1, normalizedShipmentCount(ent))
        local ok = addItem(ply, shipmentItemId(class), count)
        if not ok then return false end

        ent:Remove()
        sendSync(ply)
        return true
    end

    -- Intentionally ignore spawned_entity auto-pickup by default.

    if not rule then return false end

    local itemId = rule.id
    local amount = rule.amount or 1

    if rule.worldItem then
        if not ent.GetItemData then return false end
        local wid, wqty = ent:GetItemData()
        itemId = wid
        amount = wqty
    end

    local ok = addItem(ply, itemId, amount)
    if not ok then return false end

    if rule.removeOnPickup ~= false then
        ent:Remove()
    end

    sendSync(ply)
    return true
end

local function tryPickupFromTrace(ply)
    if not IsValid(ply) then return false end

    local tr = ply:GetEyeTrace()
    if not tr then return false end

    if IsValid(tr.Entity) and tryPickupEntity(ply, tr.Entity) then
        return true
    end

    local hitPos = tr.HitPos
    if not hitPos then return false end

    for _, near in ipairs(ents.FindInSphere(hitPos, 42)) do
        if tryPickupEntity(ply, near) then
            return true
        end
    end

    -- Extra fallback: find closest pickup candidate in front of the player.
    local origin = ply:GetShootPos()
    local aim = ply:GetAimVector()
    local probe = origin + aim * 80
    local bestEnt = nil
    local bestDist = math.huge

    for _, near in ipairs(ents.FindInSphere(probe, 90)) do
        if not IsValid(near) then continue end

        local dir = (near:GetPos() - origin):GetNormalized()
        local dot = dir:Dot(aim)
        if dot < 0.72 then continue end

        local dist = origin:Distance(near:GetPos())
        if dist < bestDist then
            bestDist = dist
            bestEnt = near
        end
    end

    if IsValid(bestEnt) and tryPickupEntity(ply, bestEnt) then
        return true
    end

    return false
end

local function getVendorProfile(profileId)
    local all = vendorProfilesTable()
    if all[profileId] then return all[profileId], profileId end

    for id, _ in pairs(all) do
        return all[id], id
    end

    return nil, nil
end

NEXUS_INV.GetVendorProfile = getVendorProfile

local function ensureDir()
    local dir = cfg("Settings", "saveFolder", "nexus_inv")
    if not file.Exists(dir, "DATA") then
        file.CreateDir(dir)
    end
end

local function filePath(ply)
    return cfg("Settings", "saveFolder", "nexus_inv") .. "/" .. ply:SteamID64() .. ".json"
end

local function normalize(inv)
    inv = inv or {}
    inv.items = inv.items or {}

    for itemId, amount in pairs(inv.items) do
        local def = itemDef(itemId)
        if not def then
            inv.items[itemId] = nil
        else
            local maxStack = math.max(1, tonumber(def.maxStack) or 1)
            inv.items[itemId] = math.Clamp(math.floor(tonumber(amount) or 0), 0, maxStack)
            if inv.items[itemId] <= 0 then
                inv.items[itemId] = nil
            end
        end
    end

    for _, localItem in ipairs(localItemsTable()) do
        local def = itemDef(localItem.id)
        if def then
            local amount = math.max(1, tonumber(localItem.amount) or 1)
            inv.items[localItem.id] = math.max(amount, inv.items[localItem.id] or 0)
        end
    end

    return inv
end

local function loadInventory(ply)
    ensureDir()
    local path = filePath(ply)

    if not file.Exists(path, "DATA") then
        inventories[ply] = normalize({})
        return inventories[ply]
    end

    local raw = file.Read(path, "DATA")
    local parsed = util.JSONToTable(raw or "") or {}
    inventories[ply] = normalize(parsed)
    return inventories[ply]
end

local function saveInventory(ply)
    local inv = inventories[ply]
    if not inv then return end

    ensureDir()
    file.Write(filePath(ply), util.TableToJSON(normalize(inv), true))
end

local function getInventory(ply)
    return inventories[ply] or loadInventory(ply)
end

addItem = function(ply, itemId, amount)
    local def = itemDef(itemId)
    if not def then return false, "unknown_item" end

    local inv = getInventory(ply)
    local current = inv.items[itemId] or 0
    local maxStack = math.max(1, tonumber(def.maxStack) or 1)
    local add = math.max(1, math.floor(tonumber(amount) or 1))

    if current >= maxStack then
        return false, "stack_full"
    end

    inv.items[itemId] = math.Clamp(current + add, 0, maxStack)
    return true
end

local function removeItem(ply, itemId, amount)
    local inv = getInventory(ply)
    local current = inv.items[itemId] or 0
    local rem = math.max(1, math.floor(tonumber(amount) or 1))
    if current < rem then return false end

    inv.items[itemId] = current - rem
    if inv.items[itemId] <= 0 then
        inv.items[itemId] = nil
    end

    normalize(inv)
    return true
end

sendSync = function(ply)
    local inv = normalize(getInventory(ply))

    net.Start("nexus_inv_sync")
    net.WriteUInt(table.Count(inv.items), 12)
    for itemId, amount in pairs(inv.items) do
        net.WriteString(itemId)
        net.WriteUInt(amount, 16)
    end
    net.Send(ply)
end

local function money(ply)
    if ply.getDarkRPVar then
        return tonumber(ply:getDarkRPVar("money") or 0) or 0
    end
    return 0
end

local function addMoney(ply, amount)
    if ply.addMoney then
        ply:addMoney(amount)
        return
    end
    if ply.setDarkRPVar then
        ply:setDarkRPVar("money", money(ply) + amount)
    end
end

local function canAfford(ply, amount)
    if ply.canAfford then
        return ply:canAfford(amount)
    end
    return money(ply) >= amount
end

local function takeMoney(ply, amount)
    if ply.addMoney then
        ply:addMoney(-amount)
        return true
    end

    if money(ply) < amount then return false end
    if ply.setDarkRPVar then
        ply:setDarkRPVar("money", money(ply) - amount)
    end
    return true
end

local function isLocalItem(itemId)
    for _, localItem in ipairs(localItemsTable()) do
        if localItem.id == itemId then
            return true, math.max(1, tonumber(localItem.amount) or 1)
        end
    end
    return false, 0
end

local function openInventory(ply)
    sendSync(ply)
    net.Start("nexus_inv_open")
    net.WriteBool(false)
    net.WriteEntity(NULL)
    net.Send(ply)
end

concommand.Add(cfg("Settings", "inventoryCommand", "nexus_inv_open"), function(ply)
    if not IsValid(ply) then return end
    openInventory(ply)
end)

net.Receive("nexus_inv_action", function(_, ply)
    local action = net.ReadString()
    local itemId = net.ReadString()
    local amount = net.ReadUInt(16)
    amount = math.max(1, amount)

    local def = itemDef(itemId)
    if not def then return end

    local inv = getInventory(ply)
    local has = inv.items[itemId] or 0
    if has < amount then return end

    local isLocal, minAmount = isLocalItem(itemId)

    if action == "drop" then
        if not cfg("Settings", "allowDropToWorld", true) then return end
        if def.canDrop == false then return end
        if isLocal and (has - amount) < minAmount then return end

        if not removeItem(ply, itemId, amount) then return end

        local ent = ents.Create("nexus_inv_worlditem")
        if not IsValid(ent) then
            addItem(ply, itemId, amount)
            return
        end

        ent:SetPos(ply:GetShootPos() + ply:GetAimVector() * 40)
        ent:Spawn()
        ent:SetItemData(itemId, amount)

        sendSync(ply)
        return
    end

    if action == "use" then
        if def.useType == "heal" then
            local hp = ply:Health()
            local maxHp = ply:GetMaxHealth()
            if hp >= maxHp then return end

            removeItem(ply, itemId, 1)
            ply:SetHealth(math.min(maxHp, hp + (def.healAmount or 25)))
            sendSync(ply)
            return
        end

        if def.useType == "equip_weapon" and def.weaponClass then
            if ply:HasWeapon(def.weaponClass) then return end
            if not removeItem(ply, itemId, 1) then return end
            ply:Give(def.weaponClass)
            sendSync(ply)
            return
        end

        return
    end
end)

net.Receive("nexus_inv_request_sync", function(_, ply)
    sendSync(ply)
end)

net.Receive("nexus_inv_pickup", function(_, ply)
    if not cfg("Settings", "shiftPickupEnabled", true) then return end
    tryPickupFromTrace(ply)
end)

hook.Add("KeyPress", "NexusInvShiftUsePickup", function(ply, key)
    if key ~= IN_USE then return end
    if not cfg("Settings", "shiftPickupEnabled", true) then return end
    if not ply:KeyDown(IN_SPEED) then return end

    -- Run on next tick so eye trace reflects current use press reliably.
    timer.Simple(0, function()
        if not IsValid(ply) then return end

        tryPickupFromTrace(ply)
    end)
end)

hook.Add("PlayerUse", "NexusInvPickupUseFallback", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if ent:GetClass() == "nexus_inv_vendor" then return end

    if tryPickupEntity(ply, ent) then
        return false
    end
end)

local function vendorStockById(profile, itemId)
    for _, entry in ipairs((profile and profile.stock) or {}) do
        if entry.id == itemId then return entry end
    end
    return nil
end

local function openVendor(ply, vendorEnt)
    if not IsValid(vendorEnt) then return end

    sendSync(ply)
    net.Start("nexus_inv_open")
    net.WriteBool(true)
    net.WriteEntity(vendorEnt)
    net.Send(ply)
end

NEXUS_INV.OpenVendor = openVendor

local function adminPayload()
    return {
        localItems = localItemsTable(),
        vendorProfiles = vendorProfilesTable(),
        itemIds = table.GetKeys(NEXUS_INV_CONFIG.Items or {})
    }
end

local function sendAdminSync(ply)
    net.Start("nexus_inv_admin_sync")
    net.WriteString(util.TableToJSON(adminPayload(), false) or "{}")
    net.Send(ply)
end

local function resyncAllPlayers()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            normalize(getInventory(p))
            sendSync(p)
        end
    end
end

local function isValidProfileId(id)
    if not isstring(id) then return false end
    if id == "" then return false end
    if string.find(id, "[^a-zA-Z0-9_]", 1) then return false end
    return true
end

concommand.Add("nexus_inv_admin", function(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    net.Start("nexus_inv_admin_open")
    net.Send(ply)
    sendAdminSync(ply)
end)

net.Receive("nexus_inv_admin_action", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local action = net.ReadString()
    local data = util.JSONToTable(net.ReadString() or "") or {}

    runtime.localItems = runtime.localItems or table.Copy(NEXUS_INV_CONFIG.LocalItems or {})
    runtime.vendorProfiles = runtime.vendorProfiles or table.Copy(NEXUS_INV_CONFIG.VendorProfiles or {})

    if action == "local_add" then
        local itemId = tostring(data.itemId or "")
        local amount = math.max(1, math.floor(tonumber(data.amount) or 1))
        if itemDef(itemId) then
            local exists = false
            for _, entry in ipairs(runtime.localItems) do
                if entry.id == itemId then
                    entry.amount = amount
                    exists = true
                    break
                end
            end
            if not exists then
                runtime.localItems[#runtime.localItems + 1] = { id = itemId, amount = amount }
            end
        end
    elseif action == "local_remove" then
        local itemId = tostring(data.itemId or "")
        for i = #runtime.localItems, 1, -1 do
            if runtime.localItems[i].id == itemId then
                table.remove(runtime.localItems, i)
            end
        end
    elseif action == "vendor_upsert" then
        local id = tostring(data.profileId or "")
        if isValidProfileId(id) then
            runtime.vendorProfiles[id] = runtime.vendorProfiles[id] or {
                name = "Торговец",
                model = "models/Humans/Group01/Male_07.mdl",
                stock = {}
            }

            local profile = runtime.vendorProfiles[id]
            profile.name = tostring(data.name or profile.name or "Торговец")
            profile.model = tostring(data.model or profile.model or "models/Humans/Group01/Male_07.mdl")
            profile.useDistance = math.max(40, math.floor(tonumber(data.useDistance) or profile.useDistance or cfg("VendorDefaults", "useDistance", 140)))
            profile.stock = profile.stock or {}
        end
    elseif action == "vendor_remove" then
        local id = tostring(data.profileId or "")
        runtime.vendorProfiles[id] = nil
    elseif action == "vendor_stock_upsert" then
        local id = tostring(data.profileId or "")
        local profile = runtime.vendorProfiles[id]
        local itemId = tostring(data.itemId or "")
        if profile and itemDef(itemId) then
            local buy = math.max(0, math.floor(tonumber(data.buyPrice) or 0))
            local sell = math.max(0, math.floor(tonumber(data.sellPrice) or 0))
            profile.stock = profile.stock or {}

            local found = false
            for _, row in ipairs(profile.stock) do
                if row.id == itemId then
                    row.buyPrice = buy
                    row.sellPrice = sell
                    found = true
                    break
                end
            end
            if not found then
                profile.stock[#profile.stock + 1] = { id = itemId, buyPrice = buy, sellPrice = sell }
            end
        end
    elseif action == "vendor_stock_remove" then
        local id = tostring(data.profileId or "")
        local profile = runtime.vendorProfiles[id]
        local itemId = tostring(data.itemId or "")
        if profile and profile.stock then
            for i = #profile.stock, 1, -1 do
                if profile.stock[i].id == itemId then
                    table.remove(profile.stock, i)
                end
            end
        end
    elseif action == "vendor_spawn" then
        local id = tostring(data.profileId or "")
        local profile, resolvedId = getVendorProfile(id)
        if profile then
            local ent = ents.Create("nexus_inv_vendor")
            if IsValid(ent) then
                ent:SetProfileId(resolvedId)
                ent:SetVendorName(profile.name or "Торговец")
                local tr = ply:GetEyeTrace()
                ent:SetPos(tr.HitPos + Vector(0, 0, 8))
                ent:Spawn()
            end
        end
    end

    saveRuntime()
    resyncAllPlayers()
    sendAdminSync(ply)
end)

net.Receive("nexus_inv_vendor_action", function(_, ply)
    local action = net.ReadString()
    local itemId = net.ReadString()
    local amount = math.max(1, net.ReadUInt(16))
    local vendorEnt = net.ReadEntity()

    if not IsValid(vendorEnt) or vendorEnt:GetClass() ~= "nexus_inv_vendor" then return end
    local profile = getVendorProfile(vendorEnt:GetProfileId())
    if not profile then return end

    local useDistance = tonumber(profile.useDistance) or cfg("VendorDefaults", "useDistance", 140)
    if ply:GetPos():Distance(vendorEnt:GetPos()) > useDistance then return end

    local stock = vendorStockById(profile, itemId)
    local def = itemDef(itemId)
    if not stock or not def then return end

    if action == "buy" then
        local price = math.max(0, math.floor((stock.buyPrice or def.buyPrice or 0) * amount))
        if price <= 0 then return end
        if not canAfford(ply, price) then return end

        local ok = addItem(ply, itemId, amount)
        if not ok then return end

        takeMoney(ply, price)
        sendSync(ply)
        return
    end

    if action == "sell" then
        if def.canSell == false then return end
        local isLocal, minAmount = isLocalItem(itemId)
        local current = getInventory(ply).items[itemId] or 0
        if isLocal and (current - amount) < minAmount then return end

        if not removeItem(ply, itemId, amount) then return end

        local reward = math.max(0, math.floor((stock.sellPrice or def.sellPrice or 0) * amount))
        if reward > 0 then
            addMoney(ply, reward)
        end

        sendSync(ply)
    end
end)

hook.Add("PlayerInitialSpawn", "NexusInvLoad", function(ply)
    loadInventory(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            sendSync(ply)
        end
    end)
end)

hook.Add("PlayerDisconnected", "NexusInvSaveDisconnect", function(ply)
    saveInventory(ply)
    inventories[ply] = nil
end)

hook.Add("ShutDown", "NexusInvSaveShutdown", function()
    for ply in pairs(inventories) do
        if IsValid(ply) then
            saveInventory(ply)
        end
    end
end)

concommand.Add("nexus_inv_spawn_vendor", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local profileId = tostring((args and args[1]) or "")

    local profile, resolvedId = getVendorProfile(profileId)
    if not profile then return end

    local ent = ents.Create("nexus_inv_vendor")
    if not IsValid(ent) then return end

    ent:SetProfileId(resolvedId)
    ent:SetVendorName(profile.name or "Торговец")

    if IsValid(ply) then
        local tr = ply:GetEyeTrace()
        ent:SetPos(tr.HitPos + Vector(0, 0, 8))
    else
        ent:SetPos(Vector(0, 0, 0))
    end

    ent:Spawn()
end)