if CLIENT then return end

AddCSLuaFile("autorun/sh_nexus_inv_config.lua")
AddCSLuaFile("autorun/client/cl_nexus_lootbins.lua")

util.AddNetworkString("nexus_lootbin_open")
util.AddNetworkString("nexus_lootbin_take")
util.AddNetworkString("nexus_lootbin_admin_open")
util.AddNetworkString("nexus_lootbin_admin_sync")
util.AddNetworkString("nexus_lootbin_admin_action")

NEXUS_LOOTBIN = NEXUS_LOOTBIN or {}

local runtimePath = "nexus_inv/lootbins_runtime.json"
local spawnsPath = "nexus_inv/lootbins_spawns.json"
local invRuntimePath = "nexus_inv/runtime.json"

local runtime = { profiles = nil }
local persistedSpawns = {}
local binsState = {}

local invCustomCache = {}
local invCustomStamp = -1

local function ensureDataDir()
    if not file.Exists("nexus_inv", "DATA") then
        file.CreateDir("nexus_inv")
    end
end

local function lootCfg(key, fallback)
    local cfg = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.LootBins
    if not cfg then return fallback end
    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

local function getInventoryRuntimeCustomItems()
    ensureDataDir()

    if not file.Exists(invRuntimePath, "DATA") then
        invCustomCache = {}
        invCustomStamp = -1
        return invCustomCache
    end

    local stamp = file.Time(invRuntimePath, "DATA") or 0
    if stamp == invCustomStamp then
        return invCustomCache
    end

    invCustomStamp = stamp
    invCustomCache = {}

    local raw = file.Read(invRuntimePath, "DATA")
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then
        return invCustomCache
    end

    local custom = istable(parsed.customItems) and parsed.customItems or {}
    for k, v in pairs(custom) do
        if isstring(k) and istable(v) then
            invCustomCache[k] = v
        elseif istable(v) and isstring(v.id) and v.id ~= "" then
            invCustomCache[v.id] = v
        end
    end

    return invCustomCache
end

local function itemDisplayName(itemId)
    local runtimeCustom = getInventoryRuntimeCustomItems()
    if istable(runtimeCustom[itemId]) and isstring(runtimeCustom[itemId].name) and runtimeCustom[itemId].name ~= "" then
        return runtimeCustom[itemId].name
    end

    local items = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.Items or {}
    local cfgCustom = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.CustomItems or {}

    if istable(items[itemId]) and isstring(items[itemId].name) and items[itemId].name ~= "" then
        return items[itemId].name
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
        return class ~= "" and class or itemId
    end

    if string.sub(itemId or "", 1, 10) == "shipment::" then
        local class = string.sub(itemId, 11)
        for _, shipment in ipairs(CustomShipments or {}) do
            if shipment.entity == class or shipment.name == class then
                return "Ящик: " .. (shipment.name or class)
            end
        end
        return "Ящик: " .. class
    end

    if string.sub(itemId or "", 1, 8) == "entity::" then
        return "Энтити: " .. string.sub(itemId, 9)
    end

    return itemId
end

local function vecToTable(v)
    return { x = v.x, y = v.y, z = v.z }
end

local function angToTable(a)
    return { p = a.p, y = a.y, r = a.r }
end

local function tableToVec(t)
    if not istable(t) then return Vector(0, 0, 0) end
    return Vector(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0)
end

local function tableToAng(t)
    if not istable(t) then return Angle(0, 0, 0) end
    return Angle(tonumber(t.p) or 0, tonumber(t.y) or 0, tonumber(t.r) or 0)
end

local function loadRuntime()
    ensureDataDir()
    if not file.Exists(runtimePath, "DATA") then return end

    local raw = file.Read(runtimePath, "DATA")
    local data = util.JSONToTable(raw or "")
    if not istable(data) then return end
    runtime.profiles = istable(data.profiles) and data.profiles or nil
end

local function saveRuntime()
    ensureDataDir()
    file.Write(runtimePath, util.TableToJSON(runtime, true))
end

local function loadSpawns()
    ensureDataDir()
    if not file.Exists(spawnsPath, "DATA") then
        persistedSpawns = {}
        return
    end

    local raw = file.Read(spawnsPath, "DATA")
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then
        persistedSpawns = {}
        return
    end

    persistedSpawns = parsed
end

local function saveSpawns()
    ensureDataDir()
    file.Write(spawnsPath, util.TableToJSON(persistedSpawns, true))
end

local function mergedProfiles()
    local base = table.Copy((NEXUS_INV_CONFIG.LootBins and NEXUS_INV_CONFIG.LootBins.profiles) or {})
    if istable(runtime.profiles) then
        for id, profile in pairs(runtime.profiles) do
            base[id] = profile
        end
    end
    return base
end

local function getProfile(profileId)
    local all = mergedProfiles()

    if isstring(profileId) and profileId ~= "" and istable(all[profileId]) then
        return all[profileId], profileId
    end

    if istable(all.trash_default) then
        return all.trash_default, "trash_default"
    end

    for id, prof in pairs(all) do
        if istable(prof) then return prof, id end
    end

    return nil, nil
end

local function pickWeighted(pool)
    local total = 0
    for _, row in ipairs(pool or {}) do
        total = total + math.max(1, tonumber(row.weight) or 1)
    end
    if total <= 0 then return nil end

    local roll = math.Rand(0, total)
    local accum = 0
    for _, row in ipairs(pool or {}) do
        accum = accum + math.max(1, tonumber(row.weight) or 1)
        if roll <= accum then return row end
    end

    return pool[#pool]
end

local function chancePass(row)
    local chance = tonumber(row and row.chance) or 100
    chance = math.Clamp(chance, 0, 100)
    if chance >= 100 then return true end
    if chance <= 0 then return false end
    return math.Rand(0, 100) <= chance
end

local function regenerateBin(ent, profile)
    if not IsValid(ent) or not istable(profile) then return end

    local rollsMin = math.max(1, math.floor(tonumber(profile.rollsMin) or 1))
    local rollsMax = math.max(rollsMin, math.floor(tonumber(profile.rollsMax) or rollsMin))
    local rolls = math.random(rollsMin, rollsMax)

    local items = {}
    for _ = 1, rolls do
        local row = pickWeighted(profile.pool or {})
        if row and isstring(row.id) and row.id ~= "" and chancePass(row) then
            local minA = math.max(1, math.floor(tonumber(row.min) or 1))
            local maxA = math.max(minA, math.floor(tonumber(row.max) or minA))
            local amount = math.random(minA, maxA)
            items[row.id] = (items[row.id] or 0) + amount
        end
    end

    binsState[ent] = binsState[ent] or {}
    binsState[ent].items = items
    binsState[ent].nextRefresh = CurTime() + math.max(10, tonumber(lootCfg("refreshSeconds", 600)) or 600)
end

local function ensureBinState(ent)
    if not IsValid(ent) then return nil, nil end
    local profile = select(1, getProfile(ent:GetProfileId()))
    if not profile then return nil, nil end

    binsState[ent] = binsState[ent] or {}
    if not istable(binsState[ent].items) then
        regenerateBin(ent, profile)
    end

    return binsState[ent], profile
end

local function canUseBin(ply, ent)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not IsValid(ent) or ent:GetClass() ~= "nexus_inv_lootbin" then return false end
    local maxDist = tonumber(lootCfg("openDistance", 120)) or 120
    return ply:GetPos():Distance(ent:GetPos()) <= maxDist
end

local function giveToInventory(ply, itemId, amount)
    if not (NEXUS_INV and isfunction(NEXUS_INV.AddItem) and isfunction(NEXUS_INV.SendSync)) then
        return false, "api_unavailable"
    end

    local ok = NEXUS_INV.AddItem(ply, itemId, amount)
    if not ok then
        return false, "add_failed"
    end

    NEXUS_INV.SendSync(ply)
    return true
end

local function buildClientItems(itemsMap)
    local arr = {}
    for itemId, amount in pairs(itemsMap or {}) do
        arr[#arr + 1] = {
            id = itemId,
            name = itemDisplayName(itemId),
            amount = tonumber(amount) or 0
        }
    end
    table.sort(arr, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return arr
end

local function spawnBinEntity(profileId, pos, ang, customName, customModel, persist)
    local profile, resolvedId = getProfile(profileId)
    if not profile then return nil end

    local ent = ents.Create("nexus_inv_lootbin")
    if not IsValid(ent) then return nil end

    ent:SetProfileId(resolvedId)
    ent:SetBinName((customName and customName ~= "") and customName or (profile.name or "Мусорка"))

    local model = tostring(customModel or profile.model or lootCfg("defaultModel", "models/props_junk/trashdumpster02.mdl"))
    if util.IsValidModel(model) then
        ent:SetModel(model)
    end

    ent:SetPos(pos or Vector(0, 0, 0))
    ent:SetAngles(ang or Angle(0, 0, 0))
    ent:Spawn()

    regenerateBin(ent, profile)

    if persist then
        persistedSpawns[#persistedSpawns + 1] = {
            map = game.GetMap(),
            profileId = resolvedId,
            name = ent:GetBinName(),
            model = model,
            pos = vecToTable(ent:GetPos()),
            ang = angToTable(ent:GetAngles())
        }
        saveSpawns()
    end

    return ent
end

function NEXUS_LOOTBIN.OpenForPlayer(ply, ent)
    if not canUseBin(ply, ent) then return end

    local state, profile = ensureBinState(ent)
    if not state or not profile then return end

    local itemsPayload = buildClientItems(state.items)

    net.Start("nexus_lootbin_open")
    net.WriteEntity(ent)
    net.WriteString(profile.name or "Мусорка")
    net.WriteString(util.TableToJSON(itemsPayload, false) or "[]")
    net.WriteUInt(math.max(0, math.floor((state.nextRefresh or CurTime()) - CurTime())), 16)
    net.Send(ply)
end

net.Receive("nexus_lootbin_take", function(_, ply)
    local ent = net.ReadEntity()
    local itemId = net.ReadString()

    if not canUseBin(ply, ent) then return end
    if not isstring(itemId) or itemId == "" then return end

    local state = binsState[ent]
    if not state or not istable(state.items) then return end

    local current = tonumber(state.items[itemId] or 0) or 0
    if current <= 0 then return end

    local ok, reason = giveToInventory(ply, itemId, 1)
    if not ok then
        if reason == "api_unavailable" then
            ply:ChatPrint("[NEXUS] Инвентарь недоступен. Проверьте API bridge.")
        else
            ply:ChatPrint("[NEXUS] Не удалось добавить предмет (лимит/стак).")
        end
        NEXUS_LOOTBIN.OpenForPlayer(ply, ent)
        return
    end

    state.items[itemId] = current - 1
    if state.items[itemId] <= 0 then state.items[itemId] = nil end

    NEXUS_LOOTBIN.OpenForPlayer(ply, ent)
end)

hook.Add("Think", "NexusLootBinRefreshThink", function()
    for ent, state in pairs(binsState) do
        if not IsValid(ent) then
            binsState[ent] = nil
        elseif (state.nextRefresh or 0) <= CurTime() then
            local profile = select(1, getProfile(ent:GetProfileId()))
            if profile then regenerateBin(ent, profile) end
        end
    end
end)

hook.Add("EntityRemoved", "NexusLootBinCleanup", function(ent)
    if binsState[ent] then binsState[ent] = nil end
end)

local function lootAdminPayload()
    local profiles = mergedProfiles()
    local profileIds = {}
    for id, _ in pairs(profiles) do profileIds[#profileIds + 1] = tostring(id) end
    table.sort(profileIds, function(a, b) return a < b end)

    local itemIds = {}
    local seen = {}

    for id, _ in pairs((NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.Items) or {}) do
        local sid = tostring(id)
        if not seen[sid] then
            seen[sid] = true
            itemIds[#itemIds + 1] = sid
        end
    end

    local runtimeCustom = getInventoryRuntimeCustomItems()
    for id, _ in pairs(runtimeCustom or {}) do
        local sid = tostring(id)
        if not seen[sid] then
            seen[sid] = true
            itemIds[#itemIds + 1] = sid
        end
    end

    table.sort(itemIds, function(a, b) return a < b end)

    return {
        refreshSeconds = tonumber(lootCfg("refreshSeconds", 600)) or 600,
        openDistance = tonumber(lootCfg("openDistance", 120)) or 120,
        defaultModel = tostring(lootCfg("defaultModel", "models/props_junk/trashdumpster02.mdl")),
        profiles = profiles,
        profileIds = profileIds,
        itemIds = itemIds
    }
end

local function sendLootAdminSync(ply)
    if not IsValid(ply) then return end
    net.Start("nexus_lootbin_admin_sync")
    net.WriteString(util.TableToJSON(lootAdminPayload(), false) or "{}")
    net.Send(ply)
end

concommand.Add("nexus_lootbins_admin", function(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    net.Start("nexus_lootbin_admin_open")
    net.Send(ply)
    sendLootAdminSync(ply)
end)

local function validProfileId(id)
    if not isstring(id) then return false end
    if id == "" then return false end
    if string.find(id, "[^a-zA-Z0-9_]", 1) then return false end
    return true
end

net.Receive("nexus_lootbin_admin_action", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local action = net.ReadString()
    local data = util.JSONToTable(net.ReadString() or "") or {}
    runtime.profiles = runtime.profiles or {}

    if action == "profile_upsert" then
        local id = tostring(data.profileId or "")
        if validProfileId(id) then
            runtime.profiles[id] = runtime.profiles[id] or {
                name = "Мусорка",
                model = tostring(lootCfg("defaultModel", "models/props_junk/trashdumpster02.mdl")),
                rollsMin = 2,
                rollsMax = 5,
                pool = {}
            }

            local p = runtime.profiles[id]
            p.name = tostring(data.name or p.name or "Мусорка")
            p.model = tostring(data.model or p.model or lootCfg("defaultModel", "models/props_junk/trashdumpster02.mdl"))
            p.rollsMin = math.max(1, math.floor(tonumber(data.rollsMin) or p.rollsMin or 2))
            p.rollsMax = math.max(p.rollsMin, math.floor(tonumber(data.rollsMax) or p.rollsMax or p.rollsMin))
            p.pool = p.pool or {}
        end

    elseif action == "profile_remove" then
        local id = tostring(data.profileId or "")
        runtime.profiles[id] = nil

    elseif action == "pool_upsert" then
        local id = tostring(data.profileId or "")
        local profile = runtime.profiles[id]
        if profile then
            local itemId = tostring(data.itemId or "")
            if itemId ~= "" then
                local minA = math.max(1, math.floor(tonumber(data.min) or 1))
                local maxA = math.max(minA, math.floor(tonumber(data.max) or minA))
                local weight = math.max(1, math.floor(tonumber(data.weight) or 1))
                local chance = math.Clamp(math.floor(tonumber(data.chance) or 100), 0, 100)

                profile.pool = profile.pool or {}
                local found = false
                for _, row in ipairs(profile.pool) do
                    if row.id == itemId then
                        row.min = minA
                        row.max = maxA
                        row.weight = weight
                        row.chance = chance
                        found = true
                        break
                    end
                end
                if not found then
                    profile.pool[#profile.pool + 1] = {
                        id = itemId,
                        min = minA,
                        max = maxA,
                        weight = weight,
                        chance = chance
                    }
                end
            end
        end

    elseif action == "pool_remove" then
        local id = tostring(data.profileId or "")
        local itemId = tostring(data.itemId or "")
        local profile = runtime.profiles[id]
        if profile and istable(profile.pool) then
            for i = #profile.pool, 1, -1 do
                if profile.pool[i].id == itemId then
                    table.remove(profile.pool, i)
                end
            end
        end

    elseif action == "spawn_bin" then
        local reqId = tostring(data.profileId or "")
        local yaw = IsValid(ply) and ply:EyeAngles().y or 0
        local tr = IsValid(ply) and ply:GetEyeTrace() or nil
        local pos = (tr and tr.HitPos or (IsValid(ply) and ply:GetPos() or Vector(0, 0, 0))) + Vector(0, 0, 8)
        local ang = Angle(0, yaw, 0)

        spawnBinEntity(reqId, pos, ang, nil, nil, true)
    end

    saveRuntime()
    sendLootAdminSync(ply)
end)

concommand.Add("nexus_lootbin_spawn", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local profileId = tostring((args and args[1]) or "trash_default")
    local yaw = IsValid(ply) and ply:EyeAngles().y or 0
    local tr = IsValid(ply) and ply:GetEyeTrace() or nil
    local pos = (tr and tr.HitPos or (IsValid(ply) and ply:GetPos() or Vector(0, 0, 0))) + Vector(0, 0, 8)
    local ang = Angle(0, yaw, 0)

    spawnBinEntity(profileId, pos, ang, nil, nil, true)
end)

hook.Add("InitPostEntity", "NexusLootBinRestoreSpawns", function()
    loadSpawns()
    local map = game.GetMap()

    for _, row in ipairs(persistedSpawns or {}) do
        if row.map == map then
            local pos = tableToVec(row.pos)
            local ang = tableToAng(row.ang)
            spawnBinEntity(row.profileId, pos, ang, row.name, row.model, false)
        end
    end
end)

loadRuntime()