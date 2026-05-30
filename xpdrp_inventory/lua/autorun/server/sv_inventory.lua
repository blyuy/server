XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

local Inv = XPDRP.Inv
local Cfg = Inv.Config

function Inv.ResolveTraderId(ply, rawId, rawEntIndex)
    local id = string.Trim(tostring(rawId or ""))

    local entIndex = tonumber(rawEntIndex or 0) or 0
    if entIndex > 0 then
        local ent = Entity(entIndex)
        if IsValid(ent) and ent:GetClass() == "xpdrp_inv_trader" then
            local entId = string.Trim(tostring(ent.GetTraderId and ent:GetTraderId() or ""))
            if entId ~= "" and Inv.Traders[entId] then
                if (not IsValid(ply)) or ent:GetPos():DistToSqr(ply:GetPos()) <= (360 * 360) then
                    return entId
                end
            end
        end
    end
    if id ~= "" and Inv.Traders[id] then
        return id
    end

    local low = string.lower(id)
    if low ~= "" then
        for key in pairs(Inv.Traders or {}) do
            if string.lower(tostring(key)) == low then
                return key
            end
        end

        -- Allow resolving by configured display name as fallback.
        for key, trader in pairs(Inv.Traders or {}) do
            if string.lower(tostring(trader and trader.name or "")) == low then
                return key
            end
        end
    end

    if IsValid(ply) then
        local sid64 = tostring(ply:SteamID64() or "")
        if Inv.ActiveTraderByPlayer and Inv.ActiveTraderByPlayer[sid64] and Inv.Traders[Inv.ActiveTraderByPlayer[sid64]] then
            return Inv.ActiveTraderByPlayer[sid64]
        end

        if Inv.ActiveTraderEntByPlayer and tonumber(Inv.ActiveTraderEntByPlayer[sid64] or 0) > 0 then
            local ent = Entity(tonumber(Inv.ActiveTraderEntByPlayer[sid64]))
            if IsValid(ent) and ent:GetClass() == "xpdrp_inv_trader" then
                local entId = string.Trim(tostring(ent.GetTraderId and ent:GetTraderId() or ""))
                if entId ~= "" and Inv.Traders[entId] then
                    return entId
                end
            end
        end
    end

    if IsValid(ply) then
        local best, bestDist
        for _, ent in ipairs(ents.FindByClass("xpdrp_inv_trader")) do
            local entId = string.Trim(tostring(ent:GetTraderId() or ""))
            if entId ~= "" and Inv.Traders[entId] then
                local d = ent:GetPos():DistToSqr(ply:GetPos())
                if d <= (220 * 220) and (not bestDist or d < bestDist) then
                    best = entId
                    bestDist = d
                end
            end
        end
        if best then return best end
    end

    -- Final fallback: if only one trader is configured, use it.
    local single
    for key in pairs(Inv.Traders or {}) do
        if single then
            single = nil
            break
        end
        single = key
    end
    if single then return single end

    return nil
end

local function getDarkRPMoney(ply)
    if not IsValid(ply) then return nil end
    if isfunction(ply.getDarkRPVar) then
        return tonumber(ply:getDarkRPVar("money"))
    end
    return nil
end

local function canAfford(ply, amount)
    if not IsValid(ply) then return false end
    amount = math.max(0, tonumber(amount) or 0)

    if isfunction(ply.canAfford) then
        return ply:canAfford(amount)
    end

    local wallet = getDarkRPMoney(ply)
    if wallet ~= nil then
        return wallet >= amount
    end

    return false
end

local function addDarkRPMoney(ply, amount)
    if not IsValid(ply) then return false end
    amount = tonumber(amount) or 0
    if amount == 0 then return true end

    if isfunction(ply.addMoney) then
        ply:addMoney(amount)
        return true
    end

    return false
end

function Inv.GetPlayerBalance(ply, data)
    local wallet = getDarkRPMoney(ply)
    if wallet ~= nil then
        return wallet
    end
    return tonumber(data and data.balance) or 0
end

local function weaponItemId(wepClass)
    return "wep_" .. string.lower(tostring(wepClass or "")):gsub("[^%w_]", "_")
end

local function getWeaponClassFromEntity(ent)
    if not IsValid(ent) then return nil end

    if ent:IsWeapon() then
        return ent:GetClass()
    end

    local class = ent:GetClass()
    if string.StartWith(class, "weapon_") then
        return class
    end

    local fromTable = {
        ent.weaponclass,
        ent.weaponClass,
        ent.wepclass,
        ent.WeaponClass
    }
    for _, v in ipairs(fromTable) do
        if isstring(v) and v ~= "" then return v end
    end

    local fromMethods = {
        "GetWeaponClass",
        "GetweaponClass",
        "GetClassName",
        "GetContents"
    }
    for _, name in ipairs(fromMethods) do
        local fn = ent[name]
        if isfunction(fn) then
            local ok, v = pcall(fn, ent)
            if ok and isstring(v) and v ~= "" then
                return v
            end
        end
    end

    if ent.GetNWString then
        local nw = ent:GetNWString("weaponclass", "")
        if nw ~= "" then return nw end
        nw = ent:GetNWString("WeaponClass", "")
        if nw ~= "" then return nw end
    end

    return nil
end

function Inv.EnsureWeaponItem(data, wepClass)
    local id = weaponItemId(wepClass)
    if data.customItems[id] then
        return id
    end

    local stored = weapons.GetStored(wepClass)
    local model = (stored and stored.WorldModel) or "models/weapons/w_pistol.mdl"
    local name = (stored and stored.PrintName) or wepClass

    data.customItems[id] = {
        id = id,
        name = "Оружие: " .. tostring(name),
        category = "Оружие",
        model = model,
        value = 1000,
        maxStack = 20,
        rarity = "rare",
        description = "Можно использовать прямо из инвентаря.",
        isWeapon = true,
        weaponClass = wepClass
    }

    return id
end

local function hasAdminAccess(ply)
    if not IsValid(ply) then return false end
    return Cfg.AdminGroups[ply:GetUserGroup()] == true
end

function Inv.GetItemMapFor(data)
    local items = table.Copy(Inv.Items)
    for id, item in pairs(data.customItems or {}) do
        items[id] = item
    end
    return items
end

function Inv.PushTx(data, txid)
    txid = tostring(txid or "")
    if txid == "" then return false end
    if data.txSet[txid] then return false end

    data.txSet[txid] = true
    data.txOrder[#data.txOrder + 1] = txid

    while #data.txOrder > Cfg.TxCacheSize do
        local old = table.remove(data.txOrder, 1)
        data.txSet[old] = nil
    end

    return true
end

function Inv.CountItem(data, itemId)
    local n = 0
    for _, slot in ipairs(data.slots or {}) do
        if slot.id == itemId then
            n = n + (tonumber(slot.qty) or 0)
        end
    end
    return n
end

function Inv.TryAddItem(data, itemId, qty)
    qty = math.floor(tonumber(qty) or 0)
    if qty <= 0 then return false end

    local items = Inv.GetItemMapFor(data)
    local item = items[itemId]
    if not item then return false end

    local remain = qty
    for _, slot in ipairs(data.slots) do
        if slot.id == itemId then
            local free = math.max(0, (item.maxStack or 1) - slot.qty)
            if free > 0 then
                local add = math.min(free, remain)
                slot.qty = slot.qty + add
                remain = remain - add
                if remain <= 0 then return true end
            end
        end
    end

    while remain > 0 do
        if #data.slots >= data.maxSlots then return false end
        local stackQty = math.min(item.maxStack or 1, remain)
        data.slots[#data.slots + 1] = { id = itemId, qty = stackQty }
        remain = remain - stackQty
    end

    return true
end

function Inv.TryRemoveItem(data, itemId, qty)
    qty = math.floor(tonumber(qty) or 0)
    if qty <= 0 then return false end
    if Inv.CountItem(data, itemId) < qty then return false end

    local remain = qty
    for i = #data.slots, 1, -1 do
        local slot = data.slots[i]
        if slot.id == itemId then
            local take = math.min(slot.qty, remain)
            slot.qty = slot.qty - take
            remain = remain - take
            if slot.qty <= 0 then
                table.remove(data.slots, i)
            end
            if remain <= 0 then return true end
        end
    end

    return false
end

function Inv.ActionCraft(data, recipeId)
    local recipe = Inv.Recipes[recipeId]
    if not recipe then return false, "Рецепт не найден" end

    for _, ingredient in ipairs(recipe.ingredients or {}) do
        if Inv.CountItem(data, ingredient.id) < (ingredient.qty or 0) then
            return false, "Недостаточно ресурсов"
        end
    end

    for _, ingredient in ipairs(recipe.ingredients or {}) do
        if not Inv.TryRemoveItem(data, ingredient.id, ingredient.qty or 0) then
            return false, "Ошибка списания"
        end
    end

    if not Inv.TryAddItem(data, recipe.result.id, recipe.result.qty or 1) then
        return false, "Нет места"
    end

    return true
end

function Inv.ActionTraderBuy(ply, data, traderId, offerIndex, traderEntIndex)
    traderId = Inv.ResolveTraderId(ply, traderId, traderEntIndex)
    local trader = traderId and Inv.Traders[traderId]
    if not trader then return false, "Торговец не найден" end
    local offer = trader.sells and trader.sells[offerIndex]
    if not offer then return false, "Оффер не найден" end

    local price = tonumber(offer.price) or 0
    local wallet = Inv.GetPlayerBalance(ply, data)
    if wallet < price then return false, "Недостаточно денег" end
    if not Inv.TryAddItem(data, offer.id, offer.qty) then return false, "Нет места" end

    if not addDarkRPMoney(ply, -price) then
        data.balance = math.max(0, (data.balance or 0) - price)
    end
    return true
end

function Inv.ActionTraderSell(ply, data, traderId, offerIndex, traderEntIndex)
    traderId = Inv.ResolveTraderId(ply, traderId, traderEntIndex)
    local trader = traderId and Inv.Traders[traderId]
    if not trader then return false, "Торговец не найден" end
    local offer = trader.buys and trader.buys[offerIndex]
    if not offer then return false, "Оффер не найден" end

    if not Inv.TryRemoveItem(data, offer.id, offer.qty) then
        return false, "Не хватает предметов"
    end

    local price = tonumber(offer.price) or 0
    if not addDarkRPMoney(ply, price) then
        data.balance = (data.balance or 0) + price
    end
    return true
end

function Inv.ActionCreateCustom(data, payload)
    local name = string.Trim(tostring(payload.name or ""))
    if #name < 3 then
        return false, "Слишком короткое имя"
    end

    local id = string.lower(name):gsub("%s+", "_") .. "_" .. tostring(os.time())
    local item = {
        id = id,
        name = name,
        category = string.Trim(tostring(payload.category or "Кастом")),
        model = string.Trim(tostring(payload.model or "models/props_junk/PopCan01a.mdl")),
        value = math.max(1, math.floor(tonumber(payload.value) or 100)),
        maxStack = math.Clamp(math.floor(tonumber(payload.maxStack) or 1), 1, 100),
        rarity = string.Trim(tostring(payload.rarity or "uncommon")) ~= "" and string.Trim(tostring(payload.rarity or "uncommon")) or "uncommon",
        description = string.Trim(tostring(payload.description or "Пользовательский предмет"))
    }

    data.customItems[id] = item
    return true
end

function Inv.ActionUseItem(ply, data, itemId)
    local map = Inv.GetItemMapFor(data)
    local item = map[itemId]
    if not item then
        return false, "Предмет не найден"
    end

    if Inv.CountItem(data, itemId) < 1 then
        return false, "Предмет закончился"
    end

    if item.isWeapon and item.weaponClass then
        if not IsValid(ply) then return false, "Игрок не найден" end
        if not ply:HasWeapon(item.weaponClass) then
            ply:Give(item.weaponClass)
        end
        ply:SelectWeapon(item.weaponClass)
        if not Inv.TryRemoveItem(data, itemId, 1) then
            return false, "Ошибка списания"
        end
        return true
    end

    if itemId == "med_stim" then
        if not IsValid(ply) then return false, "Игрок не найден" end
        ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + 35))
        if not Inv.TryRemoveItem(data, itemId, 1) then
            return false, "Ошибка списания"
        end
        return true
    end

    return false, "Этот предмет нельзя использовать"
end

function Inv.SpawnDropEntity(ply, data, itemId, qty)
    local map = Inv.GetItemMapFor(data)
    local item = map[itemId]
    if not item then return false, "Предмет не найден" end

    local startPos = ply:GetShootPos()
    local desiredPos = ply:GetPos() + Vector(0, 0, 42) + ply:GetAimVector() * 64

    -- Hard distance limit: item must appear close to player (<= 1 meter).
    if desiredPos:DistToSqr(ply:GetPos()) > (100 * 100) then
        desiredPos = ply:GetPos() + Vector(0, 0, 42)
    end

    local hull = util.TraceHull({
        start = startPos,
        endpos = desiredPos,
        mins = Vector(-8, -8, -8),
        maxs = Vector(8, 8, 8),
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY
    })

    local pos = hull.Hit and (hull.HitPos + hull.HitNormal * 14) or desiredPos

    -- Anti-under-map: clamp to valid in-world point and snap above ground.
    if not util.IsInWorld(pos) then
        local safe = ply:GetPos() + Vector(0, 0, 48)
        if not util.IsInWorld(safe) then
            return false, "Нет безопасной точки для выброса"
        end
        pos = safe
    end

    local down = util.TraceLine({
        start = pos + Vector(0, 0, 24),
        endpos = pos - Vector(0, 0, 300),
        filter = ply,
        mask = MASK_SOLID
    })
    if down.Hit then
        pos = down.HitPos + down.HitNormal * 10
    end

    local ent = ents.Create("xpdrp_inv_drop")
    if not IsValid(ent) then return false, "Не удалось создать коробку" end

    ent:SetPos(pos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ent:Spawn()
    ent:SetItemId(itemId)
    ent:SetAmount(qty)
    ent:SetModel(item.model or "models/Items/item_item_crate.mdl")

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:ApplyForceCenter(ply:GetAimVector() * 250)
    end

    return true
end

function Inv.ActionDropItem(ply, data, itemId, qty)
    qty = math.max(1, math.floor(tonumber(qty) or 1))
    if Inv.CountItem(data, itemId) < qty then
        return false, "Недостаточно предметов"
    end

    if not Inv.TryRemoveItem(data, itemId, qty) then
        return false, "Ошибка списания"
    end

    local ok, err = Inv.SpawnDropEntity(ply, data, itemId, qty)
    if not ok then
        Inv.TryAddItem(data, itemId, qty)
        return false, err
    end

    return true
end

function Inv.PickupEntity(ply, data, ent)
    if not IsValid(ent) then return false, "Объект не найден" end

    local class = ent:GetClass()
    local itemId, qty

    if class == "xpdrp_inv_drop" then
        itemId = ent:GetItemId()
        qty = math.max(1, ent:GetAmount())
    else
        local wl = Cfg.PickupWhitelist and Cfg.PickupWhitelist[class]
        if istable(wl) and wl.itemId then
            itemId = wl.itemId
            qty = math.max(1, tonumber(wl.qty) or 1)
        elseif isstring(wl) then
            itemId = wl
            qty = 1
        end

        if not itemId and (class == "spawned_weapon" or class == "spawned_shipment" or ent:IsWeapon() or string.StartWith(class, "weapon_")) then
            local wepClass = getWeaponClassFromEntity(ent)
            if wepClass and wepClass ~= "" then
                itemId = Inv.EnsureWeaponItem(data, wepClass)
                qty = 1

                if class == "spawned_shipment" then
                    if isfunction(ent.Getcount) then
                        qty = math.max(1, tonumber(ent:Getcount()) or 1)
                    elseif isfunction(ent.GetCount) then
                        qty = math.max(1, tonumber(ent:GetCount()) or 1)
                    elseif ent.GetNWInt then
                        qty = math.max(1, ent:GetNWInt("count", 1))
                    end
                end
            end
        end
    end

    if not itemId then
        return false, "Этот объект нельзя подобрать"
    end

    qty = math.max(1, tonumber(qty) or 1)
    if not Inv.TryAddItem(data, itemId, qty) then
        return false, "Недостаточно места"
    end

    if IsValid(ent) then
        ent:Remove()
    end

    return true
end

function Inv.ActionAdmin(ply, payload)
    if not hasAdminAccess(ply) then
        return false, "Нет доступа"
    end

    local targetSid = tostring(payload.targetSid64 or "")
    local target
    for _, p in ipairs(player.GetAll()) do
        if p:SteamID64() == targetSid then
            target = p
            break
        end
    end
    if not IsValid(target) then
        return false, "Игрок не найден"
    end

    local targetData = Inv.GetPlayerData(target)
    local itemId = tostring(payload.itemId or "")
    local qty = math.max(1, math.floor(tonumber(payload.qty) or 1))

    if payload.mode == "give" then
        if not Inv.TryAddItem(targetData, itemId, qty) then
            return false, "Не удалось выдать"
        end
    elseif payload.mode == "take" then
        if not Inv.TryRemoveItem(targetData, itemId, qty) then
            return false, "Не удалось забрать"
        end
    else
        return false, "Неизвестный режим"
    end

    Inv.SavePlayerData(target)
    return true
end