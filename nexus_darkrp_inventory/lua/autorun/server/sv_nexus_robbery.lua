if CLIENT then return end

AddCSLuaFile("autorun/sh_nexus_robbery_config.lua")
AddCSLuaFile("autorun/client/cl_nexus_robbery.lua")

util.AddNetworkString("nexus_robbery_sync")
util.AddNetworkString("nexus_robbery_open_loot")
util.AddNetworkString("nexus_robbery_take_loot")
util.AddNetworkString("nexus_robbery_police_alert")
util.AddNetworkString("nexus_robbery_admin_open")
util.AddNetworkString("nexus_robbery_admin_save")

NEXUS_ROBBERY = NEXUS_ROBBERY or {}

local activeByEnt = {}
local runtime = {
    settings = nil,
    targets = nil,
    spawns = nil
}

local managedById = {}
local managedByEnt = {}

local invApi = { addItem = nil, sendSync = nil }

local function ensureDataDir()
    if not file.Exists("nexus_inv", "DATA") then
        file.CreateDir("nexus_inv")
    end
end

local function deepCopy(tbl)
    if not istable(tbl) then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = deepCopy(v) end
    return out
end

local function normalizeVec(src, fallback)
    if isvector(src) then return src end
    if istable(src) then
        return Vector(tonumber(src.x) or 0, tonumber(src.y) or 0, tonumber(src.z) or 0)
    end
    return fallback or Vector(0, 0, 0)
end

local function normalizeAng(src, fallback)
    if isangle(src) then return src end
    if istable(src) then
        return Angle(tonumber(src.p) or 0, tonumber(src.y) or 0, tonumber(src.r) or 0)
    end
    return fallback or Angle(0, 0, 0)
end

local function sanitizeId(raw)
    raw = string.Trim(string.lower(tostring(raw or "")))
    if raw == "" then return nil end
    if string.find(raw, "[^a-z0-9_%-]") then return nil end
    return raw
end

local function sanitizeClassName(raw)
    raw = string.Trim(tostring(raw or ""))
    if raw == "" then return nil end
    if string.find(raw, "[^a-zA-Z0-9_]") then return nil end
    return raw
end

local function normalizeLootRows(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do
        local id = string.Trim(tostring(row.id or ""))
        if id ~= "" then
            local min = math.max(1, math.floor(tonumber(row.min) or 1))
            local max = math.max(min, math.floor(tonumber(row.max) or min))
            local chance = math.Clamp(math.floor(tonumber(row.chance) or 100), 0, 100)
            out[#out + 1] = { id = id, min = min, max = max, chance = chance }
        end
    end
    return out
end

local function normalizeSettings(raw)
    raw = istable(raw) and raw or {}
    return {
        dataFile = tostring(raw.dataFile or "nexus_inv/robbery_runtime.json"),
        policeNotifySound = tostring(raw.policeNotifySound or "buttons/blip1.wav"),
        leaveZoneGrace = math.max(1, tonumber(raw.leaveZoneGrace) or 5),
        chatCooldown = math.max(0.1, tonumber(raw.chatCooldown) or 1)
    }
end

local function normalizeTarget(raw)
    if not istable(raw) then return nil end

    local t = {}
    t.name = string.Trim(tostring(raw.name or "Цель ограбления"))
    if t.name == "" then t.name = "Цель ограбления" end

    t.displayName = string.Trim(tostring(raw.displayName or t.name))
    if t.displayName == "" then t.displayName = t.name end

    t.enabled = tobool(raw.enabled ~= false)
    t.modelOverride = string.Trim(tostring(raw.modelOverride or ""))

    t.startDistance = math.max(40, tonumber(raw.startDistance) or 120)
    t.duration = math.max(5, tonumber(raw.duration) or 45)
    t.cooldown = math.max(10, tonumber(raw.cooldown) or 300)

    t.useAbsoluteCenter = tobool(raw.useAbsoluteCenter)
    t.zoneCenter = normalizeVec(raw.zoneCenter, Vector(0, 0, 0))
    t.zoneOffset = normalizeVec(raw.zoneOffset, Vector(0, 0, 0))
    t.zoneMins = normalizeVec(raw.zoneMins, Vector(-120, -120, -10))
    t.zoneMaxs = normalizeVec(raw.zoneMaxs, Vector(120, 120, 140))

    t.policeTeams = {}
    for _, id in ipairs(raw.policeTeams or {}) do
        local n = tonumber(id)
        if n then t.policeTeams[#t.policeTeams + 1] = math.floor(n) end
    end

    t.loot = normalizeLootRows(raw.loot or {})
    return t
end

local function normalizeSpawn(raw)
    if not istable(raw) then return nil end

    local id = sanitizeId(raw.id)
    local className = sanitizeClassName(raw.class)
    local targetId = sanitizeId(raw.targetId)

    if not id or not className or not targetId then return nil end

    return {
        id = id,
        class = className,
        targetId = targetId,
        pos = normalizeVec(raw.pos, Vector(0, 0, 0)),
        ang = normalizeAng(raw.ang, Angle(0, 0, 0)),
        modelOverride = string.Trim(tostring(raw.modelOverride or "")),
        lootOverride = normalizeLootRows(raw.lootOverride or {})
    }
end

local function baseSettings()
    return (NEXUS_ROBBERY_CONFIG and NEXUS_ROBBERY_CONFIG.Settings) or {}
end

local function dataPath()
    local p = tostring((baseSettings().dataFile or "nexus_inv/robbery_runtime.json"))
    if p == "" then p = "nexus_inv/robbery_runtime.json" end
    return p
end

local function loadRuntime()
    ensureDataDir()

    runtime.settings = nil
    runtime.targets = {}
    runtime.spawns = {}

    local p = dataPath()
    if not file.Exists(p, "DATA") then return end

    local raw = file.Read(p, "DATA")
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then return end

    if istable(parsed.settings) then
        runtime.settings = normalizeSettings(parsed.settings)
    end

    if istable(parsed.targets) then
        for id, target in pairs(parsed.targets) do
            local tid = sanitizeId(id)
            if tid then runtime.targets[tid] = normalizeTarget(target) end
        end
    end

    if istable(parsed.spawns) then
        for i = 1, #parsed.spawns do
            local s = normalizeSpawn(parsed.spawns[i])
            if s then runtime.spawns[#runtime.spawns + 1] = s end
        end
    end
end

local function saveRuntime()
    ensureDataDir()
    local payload = {
        settings = runtime.settings or nil,
        targets = runtime.targets or {},
        spawns = runtime.spawns or {}
    }
    file.Write(dataPath(), util.TableToJSON(payload, true))
end

local function effectiveSettings()
    local out = normalizeSettings(baseSettings())
    if runtime.settings then
        for k, v in pairs(runtime.settings) do out[k] = v end
    end
    return out
end

local function effectiveTargets()
    local out = {}
    local base = (NEXUS_ROBBERY_CONFIG and NEXUS_ROBBERY_CONFIG.Targets) or {}
    for id, t in pairs(base) do
        local tid = sanitizeId(id)
        if tid then out[tid] = normalizeTarget(t) end
    end
    for id, t in pairs(runtime.targets or {}) do
        local tid = sanitizeId(id)
        if tid then out[tid] = normalizeTarget(t) end
    end
    return out
end

local function effectiveSpawns()
    local out = {}
    for i = 1, #(NEXUS_ROBBERY_CONFIG.Spawns or {}) do
        local s = normalizeSpawn(NEXUS_ROBBERY_CONFIG.Spawns[i])
        if s then out[#out + 1] = s end
    end
    for i = 1, #(runtime.spawns or {}) do
        local s = normalizeSpawn(runtime.spawns[i])
        if s then out[#out + 1] = s end
    end
    return out
end

local function bindInvApi()
    if NEXUS_INV then
        if isfunction(NEXUS_INV.AddItem) then invApi.addItem = NEXUS_INV.AddItem end
        if isfunction(NEXUS_INV.SendSync) then invApi.sendSync = NEXUS_INV.SendSync end
    end
    return isfunction(invApi.addItem) and isfunction(invApi.sendSync)
end

timer.Create("NexusRobberyBindInvApi", 1, 0, function()
    if bindInvApi() then timer.Remove("NexusRobberyBindInvApi") end
end)

local function msgCd(ply, key, text)
    local set = effectiveSettings()
    local cd = tonumber(set.chatCooldown) or 1
    ply.NexusRobberyMsgCD = ply.NexusRobberyMsgCD or {}
    local nextAt = ply.NexusRobberyMsgCD[key] or 0
    if nextAt > CurTime() then return end
    ply.NexusRobberyMsgCD[key] = CurTime() + cd
    ply:ChatPrint(text)
end

local function zoneCenter(ent, targetCfg)
    if targetCfg.useAbsoluteCenter then return targetCfg.zoneCenter end
    return ent:GetPos() + targetCfg.zoneOffset
end

local function inBox(pos, center, mins, maxs)
    local l = pos - center
    return l.x >= mins.x and l.x <= maxs.x
        and l.y >= mins.y and l.y <= maxs.y
        and l.z >= mins.z and l.z <= maxs.z
end

local function notifyPolice(robber, targetName, pos, teamIds)
    local set = effectiveSettings()
    local snd = tostring(set.policeNotifySound or "buttons/blip1.wav")

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        local police = false
        for _, id in ipairs(teamIds or {}) do
            if ply:Team() == id then police = true break end
        end
        if not police then continue end

        ply:EmitSound(snd, 70, 105, 1, CHAN_AUTO)
        net.Start("nexus_robbery_police_alert")
        net.WriteString(targetName or "Неизвестная цель")
        net.WriteString(IsValid(robber) and robber:Nick() or "Unknown")
        net.WriteVector(pos or vector_origin)
        net.Send(ply)
    end
end

local function rollLootRows(targetCfg, spawnRow)
    -- per-spawn override приоритетнее target loot
    local source = (spawnRow and istable(spawnRow.lootOverride) and #spawnRow.lootOverride > 0) and spawnRow.lootOverride or targetCfg.loot
    local out = {}

    for _, row in ipairs(source or {}) do
        if math.random(1, 100) <= row.chance then
            out[#out + 1] = { id = row.id, amount = math.random(row.min, row.max) }
        end
    end

    if #out == 0 then out[1] = { id = "scrap", amount = 1 } end
    return out
end

local function serializeActive()
    local rows = {}
    for ent, state in pairs(activeByEnt) do
        if not IsValid(ent) then continue end
        rows[#rows + 1] = {
            ent = ent,
            center = state.center,
            mins = state.mins,
            maxs = state.maxs,
            endAt = state.endAt,
            unlocked = state.unlocked,
            robber = IsValid(state.robber) and state.robber:Nick() or "Unknown",
            name = state.displayName or "Ограбление"
        }
    end
    return rows
end

local function broadcastSync()
    local rows = serializeActive()
    net.Start("nexus_robbery_sync")
    net.WriteUInt(#rows, 10)
    for i = 1, #rows do
        local r = rows[i]
        net.WriteEntity(r.ent)
        net.WriteVector(r.center)
        net.WriteVector(r.mins)
        net.WriteVector(r.maxs)
        net.WriteFloat(r.endAt)
        net.WriteBool(r.unlocked)
        net.WriteString(r.robber)
        net.WriteString(r.name)
    end
    net.Broadcast()
end

local function stopRobbery(ent, reason)
    local st = activeByEnt[ent]
    if not st then return end

    if IsValid(st.robber) then
        st.robber:ChatPrint("[ROBBERY] Ограбление прервано: " .. tostring(reason or "неизвестно"))
    end

    ent.NexusRobberyNextAt = CurTime() + math.max(10, tonumber(st.cooldown or 120))
    activeByEnt[ent] = nil
    broadcastSync()
end

local function unlockRobbery(ent)
    local st = activeByEnt[ent]
    if not st then return end

    st.unlocked = true
    st.lootRows = rollLootRows(st.targetCfg, st.spawnRow)

    if IsValid(st.robber) then
        st.robber:ChatPrint("[ROBBERY] Контейнер вскрыт. Заберите лут.")
    end
    broadcastSync()
end

local function startRobbery(ply, ent, spawnRow, targetCfg)
    if activeByEnt[ent] then return false, "Уже грабят" end
    if (ent.NexusRobberyNextAt or 0) > CurTime() then return false, "Цель на откате" end
    if ply:GetPos():DistToSqr(ent:GetPos()) > (targetCfg.startDistance * targetCfg.startDistance) then
        return false, "Слишком далеко"
    end

    local center = zoneCenter(ent, targetCfg)

    activeByEnt[ent] = {
        spawnRow = spawnRow,
        robber = ply,
        startedAt = CurTime(),
        endAt = CurTime() + targetCfg.duration,
        unlocked = false,
        targetCfg = targetCfg,
        displayName = targetCfg.displayName or targetCfg.name,
        center = center,
        mins = targetCfg.zoneMins,
        maxs = targetCfg.zoneMaxs,
        cooldown = targetCfg.cooldown,
        leaveAt = nil,
        lootRows = {}
    }

    ply:ChatPrint("[ROBBERY] Начато. Оставайтесь в зоне до завершения.")
    notifyPolice(ply, targetCfg.displayName or targetCfg.name, center, targetCfg.policeTeams)
    broadcastSync()

    timer.Simple(targetCfg.duration, function()
        if not IsValid(ent) then return end
        local st = activeByEnt[ent]
        if not st then return end
        if not IsValid(st.robber) then
            stopRobbery(ent, "грабитель вышел")
            return
        end
        if not inBox(st.robber:GetPos(), st.center, st.mins, st.maxs) then
            stopRobbery(ent, "вы покинули зону")
            return
        end
        unlockRobbery(ent)
    end)

    return true
end

local function openLootMenu(ply, ent)
    local st = activeByEnt[ent]
    if not st or not st.unlocked then return end
    if st.robber ~= ply then
        msgCd(ply, "not_owner", "[ROBBERY] Это не ваше ограбление.")
        return
    end
    if not inBox(ply:GetPos(), st.center, st.mins, st.maxs) then
        msgCd(ply, "outside", "[ROBBERY] Вы вне зоны ограбления.")
        return
    end

    net.Start("nexus_robbery_open_loot")
    net.WriteEntity(ent)
    net.WriteUInt(#st.lootRows, 8)
    for i = 1, #st.lootRows do
        local row = st.lootRows[i]
        net.WriteString(row.id)
        net.WriteUInt(math.max(0, row.amount), 16)
    end
    net.Send(ply)
end

local function takeLoot(ply, ent, idx)
    local st = activeByEnt[ent]
    if not st or not st.unlocked then return end
    if st.robber ~= ply then return end
    if not inBox(ply:GetPos(), st.center, st.mins, st.maxs) then return end
    if not bindInvApi() then
        msgCd(ply, "inv_unavailable", "[ROBBERY] Инвентарь недоступен.")
        return
    end

    local row = st.lootRows[idx]
    if not row or row.amount <= 0 then return end

    local ok = invApi.addItem(ply, row.id, 1)
    if not ok then
        msgCd(ply, "inv_full", "[ROBBERY] Невозможно выдать предмет.")
        return
    end

    row.amount = row.amount - 1
    invApi.sendSync(ply)

    local hasAny = false
    for i = 1, #st.lootRows do
        if st.lootRows[i].amount > 0 then hasAny = true break end
    end

    if hasAny then
        openLootMenu(ply, ent)
    else
        ply:ChatPrint("[ROBBERY] Лут забран. Ограбление завершено.")
        ent.NexusRobberyNextAt = CurTime() + math.max(10, tonumber(st.cooldown or 120))
        activeByEnt[ent] = nil
        broadcastSync()
    end
end

local function clearManaged()
    for id, ent in pairs(managedById) do
        if IsValid(ent) then ent:Remove() end
        managedById[id] = nil
    end
    managedByEnt = {}
end

local function applyModelOverride(ent, modelPath)
    modelPath = string.Trim(tostring(modelPath or ""))
    if modelPath == "" then return end
    if not util.IsValidModel(modelPath) then return end

    ent:SetModel(modelPath)
    ent:SetMaterial("")
end

local function spawnManagedEntities()
    clearManaged()

    local targets = effectiveTargets()
    local spawns = effectiveSpawns()

    for i = 1, #spawns do
        local row = spawns[i]
        local tcfg = targets[row.targetId]
        if not tcfg or tcfg.enabled == false then continue end

        local ent = ents.Create(row.class)
        if not IsValid(ent) then continue end

        ent:SetPos(row.pos)
        ent:SetAngles(row.ang)

        -- pre override (если энтити уважает pre-spawn model)
        if row.modelOverride and row.modelOverride ~= "" then
            applyModelOverride(ent, row.modelOverride)
        elseif tcfg.modelOverride and tcfg.modelOverride ~= "" then
            applyModelOverride(ent, tcfg.modelOverride)
        end

        ent:Spawn()
        ent:Activate()

        -- post override (если энтити ставит модель в Initialize)
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            if row.modelOverride and row.modelOverride ~= "" then
                applyModelOverride(ent, row.modelOverride)
            elseif tcfg.modelOverride and tcfg.modelOverride ~= "" then
                applyModelOverride(ent, tcfg.modelOverride)
            end
        end)

        ent.NexusRobberyManaged = true
        ent.NexusRobberySpawnId = row.id
        ent.NexusRobberyTargetId = row.targetId

        managedById[row.id] = ent
        managedByEnt[ent] = row
    end
end

local function getManagedRow(ent)
    if not IsValid(ent) then return nil end
    if not ent.NexusRobberyManaged then return nil end
    return managedByEnt[ent]
end

hook.Add("InitPostEntity", "NexusRobberySpawnManagedInit", function()
    timer.Simple(1, function()
        spawnManagedEntities()
    end)
end)

hook.Add("EntityRemoved", "NexusRobberyCleanup", function(ent)
    if activeByEnt[ent] then
        activeByEnt[ent] = nil
        broadcastSync()
    end

    local row = managedByEnt[ent]
    if row then
        managedByEnt[ent] = nil
        if row.id then managedById[row.id] = nil end
    end
end)

hook.Add("PlayerUse", "NexusRobberyUseManagedOnly", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end

    local spawnRow = getManagedRow(ent)
    if not spawnRow then return end

    local targets = effectiveTargets()
    local targetCfg = targets[spawnRow.targetId]
    if not targetCfg or targetCfg.enabled == false then return false end

    local st = activeByEnt[ent]
    if st then
        if st.unlocked then
            openLootMenu(ply, ent)
        else
            msgCd(ply, "already", "[ROBBERY] Ограбление уже идет.")
        end
        return false
    end

    local ok, err = startRobbery(ply, ent, spawnRow, targetCfg)
    if not ok and err then
        msgCd(ply, "start_fail", "[ROBBERY] " .. err)
    end
    return false
end)

hook.Add("Think", "NexusRobberyZoneGuard", function()
    if not next(activeByEnt) then return end

    local grace = tonumber(effectiveSettings().leaveZoneGrace) or 5
    local now = CurTime()

    for ent, st in pairs(activeByEnt) do
        if not IsValid(ent) then
            activeByEnt[ent] = nil
            broadcastSync()
            continue
        end

        if st.unlocked then continue end

        if not IsValid(st.robber) then
            stopRobbery(ent, "грабитель вышел")
            continue
        end

        local inside = inBox(st.robber:GetPos(), st.center, st.mins, st.maxs)
        if inside then
            st.leaveAt = nil
        else
            if not st.leaveAt then
                st.leaveAt = now + grace
                msgCd(st.robber, "leave_warn", "[ROBBERY] Вернитесь в зону в течение " .. grace .. " сек.")
            elseif now >= st.leaveAt then
                stopRobbery(ent, "вы покинули зону слишком надолго")
            end
        end
    end
end)

net.Receive("nexus_robbery_take_loot", function(_, ply)
    local ent = net.ReadEntity()
    local idx = net.ReadUInt(8)
    if not IsValid(ent) then return end
    takeLoot(ply, ent, idx)
end)

local function canAdmin(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:IsSuperAdmin()
end

concommand.Add("nexus_robbery_admin", function(ply)
    if not canAdmin(ply) then return end

    local payload = {
        settings = effectiveSettings(),
        targets = effectiveTargets(),
        spawns = effectiveSpawns()
    }

    net.Start("nexus_robbery_admin_open")
    net.WriteString(util.TableToJSON(payload, false) or "{}")
    net.Send(ply)
end)

net.Receive("nexus_robbery_admin_save", function(_, ply)
    if not canAdmin(ply) then return end

    local raw = net.ReadString()
    local parsed = util.JSONToTable(raw or "")
    if not istable(parsed) then
        ply:ChatPrint("[ROBBERY] Ошибка: плохой JSON.")
        return
    end

    runtime.settings = normalizeSettings(parsed.settings or {})
    runtime.targets = {}
    runtime.spawns = {}

    for targetId, target in pairs(parsed.targets or {}) do
        local id = sanitizeId(targetId)
        if id then runtime.targets[id] = normalizeTarget(target) end
    end

    local seen = {}
    for i = 1, #(parsed.spawns or {}) do
        local s = normalizeSpawn(parsed.spawns[i])
        if s and not seen[s.id] then
            seen[s.id] = true
            runtime.spawns[#runtime.spawns + 1] = s
        end
    end

    saveRuntime()
    spawnManagedEntities()
    broadcastSync()

    ply:ChatPrint("[ROBBERY] Сохранено. Спавны обновлены.")
end)

hook.Add("PlayerInitialSpawn", "NexusRobberyInitialSync", function(ply)
    timer.Simple(2.0, function()
        if not IsValid(ply) then return end
        local rows = serializeActive()
        net.Start("nexus_robbery_sync")
        net.WriteUInt(#rows, 10)
        for i = 1, #rows do
            local r = rows[i]
            net.WriteEntity(r.ent)
            net.WriteVector(r.center)
            net.WriteVector(r.mins)
            net.WriteVector(r.maxs)
            net.WriteFloat(r.endAt)
            net.WriteBool(r.unlocked)
            net.WriteString(r.robber)
            net.WriteString(r.name)
        end
        net.Send(ply)
    end)
end)

loadRuntime()