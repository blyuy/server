if CLIENT then return end

AddCSLuaFile("autorun/sh_nexus_miner_config.lua")
AddCSLuaFile("autorun/client/cl_nexus_miner.lua")

util.AddNetworkString("nexus_miner_round")
util.AddNetworkString("nexus_miner_input")
util.AddNetworkString("nexus_miner_finish")

NEXUS_MINER = NEXUS_MINER or {}

local sessions = {}
local validKeys = { "W", "A", "S", "D" }

local invApi = {
    addItem = nil,
    sendSync = nil
}

local function cfg(group, key, fallback)
    local block = NEXUS_MINER_CONFIG and NEXUS_MINER_CONFIG[group]
    if not block then return fallback end
    local v = block[key]
    if v == nil then return fallback end
    return v
end

local function isOre(ent)
    if not IsValid(ent) then return false end
    local model = string.lower(ent:GetModel() or "")
    return model == string.lower(NEXUS_MINER_CONFIG.OreModel or "models/props_junk/rock001a.mdl")
end

local function distOk(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return false end
    local maxDist = tonumber(cfg("Mining", "useDistance", 140)) or 140
    return ply:GetPos():DistToSqr(ent:GetPos()) <= (maxDist * maxDist)
end

local function bindInvApi()
    if NEXUS_INV then
        if isfunction(NEXUS_INV.AddItem) then invApi.addItem = NEXUS_INV.AddItem end
        if isfunction(NEXUS_INV.SendSync) then invApi.sendSync = NEXUS_INV.SendSync end
    end

    if isfunction(invApi.addItem) and isfunction(invApi.sendSync) then
        return true
    end

    if not istable(net.Receivers) then return false end
    for _, rx in pairs(net.Receivers) do
        if not isfunction(rx) then continue end
        for i = 1, 96 do
            local name, val = debug.getupvalue(rx, i)
            if not name then break end
            if name == "addItem" and isfunction(val) then invApi.addItem = val end
            if name == "sendSync" and isfunction(val) then invApi.sendSync = val end
        end
        if isfunction(invApi.addItem) and isfunction(invApi.sendSync) then
            return true
        end
    end

    return false
end

timer.Create("NexusMinerBindInvApi", 1, 0, function()
    if bindInvApi() then
        timer.Remove("NexusMinerBindInvApi")
    end
end)

local function rollRewardId()
    local rewards = (NEXUS_MINER_CONFIG and NEXUS_MINER_CONFIG.Rewards) or {}
    local total = 0
    for _, r in ipairs(rewards) do
        total = total + math.max(0, tonumber(r.chance) or 0)
    end
    if total <= 0 then return nil end

    local roll = math.Rand(0, total)
    local acc = 0
    for _, r in ipairs(rewards) do
        acc = acc + math.max(0, tonumber(r.chance) or 0)
        if roll <= acc then
            return tostring(r.id or "")
        end
    end

    return tostring(rewards[#rewards] and rewards[#rewards].id or "")
end

local function finishSession(ply, success, message)
    local s = sessions[ply]
    if not s then return end

    sessions[ply] = nil

    if IsValid(s.ore) then
        s.ore.NexusMinerBusy = nil
        local cooldown = success and tonumber(cfg("Mining", "successCooldown", 8)) or tonumber(cfg("Mining", "failCooldown", 2))
        s.ore.NexusNextMineAt = CurTime() + math.max(0, cooldown or 0)
    end

    if IsValid(ply) then
        ply:Freeze(false)

        net.Start("nexus_miner_finish")
        net.WriteBool(success)
        net.WriteString(message or "")
        net.Send(ply)
    end
end

local function sendRound(ply)
    local s = sessions[ply]
    if not s then return end
    if not IsValid(ply) or not IsValid(s.ore) then
        finishSession(ply, false, "Добыча прервана.")
        return
    end

    if not distOk(ply, s.ore) then
        finishSession(ply, false, "Вы отошли от руды.")
        return
    end

    s.expected = validKeys[math.random(1, #validKeys)]
    local base = tonumber(cfg("Mining", "firstRoundTime", 1.15)) or 1.15
    local dec = tonumber(cfg("Mining", "roundTimeDecrease", 0.14)) or 0.14
    local minT = tonumber(cfg("Mining", "minRoundTime", 0.65)) or 0.65
    local duration = math.max(minT, base - ((s.step - 1) * dec))

    s.expiresAt = CurTime() + duration
    s.awaiting = true
    s.token = (s.token or 0) + 1

    net.Start("nexus_miner_round")
    net.WriteString(s.expected)
    net.WriteFloat(duration)
    net.WriteUInt(s.step, 8)
    net.WriteUInt(s.total, 8)
    net.Send(ply)
end

local function startSession(ply, ore)
    if sessions[ply] then return end
    if not IsValid(ply) or not IsValid(ore) then return end
    if not isOre(ore) then return end
    if not distOk(ply, ore) then return end
    if IsValid(ore.NexusMinerBusy) then return end
    if (ore.NexusNextMineAt or 0) > CurTime() then
        ply:ChatPrint("[NEXUS] Жила еще не восстановилась.")
        return
    end

    ore.NexusMinerBusy = ply

    sessions[ply] = {
        ore = ore,
        step = 1,
        total = math.max(1, math.floor(tonumber(cfg("Mining", "stepsToWin", 3)) or 3)),
        expected = nil,
        expiresAt = 0,
        awaiting = false,
        token = 0
    }

    ply:Freeze(true)
    sendRound(ply)
end

hook.Add("KeyPress", "NexusMinerUseRock", function(ply, key)
    if key ~= IN_USE then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if sessions[ply] then return end

    local tr = ply:GetEyeTrace()
    if not tr or not IsValid(tr.Entity) then return end
    local ent = tr.Entity

    if not isOre(ent) then return end
    if not distOk(ply, ent) then return end

    startSession(ply, ent)
end)

net.Receive("nexus_miner_input", function(_, ply)
    local pressed = tostring(net.ReadString() or "")
    local s = sessions[ply]
    if not s then return end

    if not IsValid(ply) or not IsValid(s.ore) then
        finishSession(ply, false, "Добыча прервана.")
        return
    end

    if not distOk(ply, s.ore) then
        finishSession(ply, false, "Вы отошли от руды.")
        return
    end

    if not s.awaiting then return end

    if CurTime() > (s.expiresAt or 0) then
        finishSession(ply, false, "Вы повредили инструмент или упустили жилу!")
        return
    end

    if pressed ~= s.expected then
        finishSession(ply, false, "Вы повредили инструмент или упустили жилу!")
        return
    end

    s.awaiting = false

    if s.step >= s.total then
        -- Серверная проверка дистанции перед выдачей награды.
        if not distOk(ply, s.ore) then
            finishSession(ply, false, "Вы отошли от руды.")
            return
        end

        if not bindInvApi() then
            finishSession(ply, false, "Инвентарь недоступен, попробуйте позже.")
            return
        end

        local rewardId = rollRewardId()
        if rewardId == "" or not rewardId then
            finishSession(ply, false, "Ошибка таблицы наград.")
            return
        end

        local ok = invApi.addItem(ply, rewardId, 1)
        if not ok then
            finishSession(ply, false, "Инвентарь заполнен или предмет недоступен.")
            return
        end

        invApi.sendSync(ply)
        finishSession(ply, true, "Вы добыли: " .. rewardId)
        return
    end

    s.step = s.step + 1
    local stepToken = s.token
    local delay = math.max(0, tonumber(cfg("Mining", "stepDelay", 1.0)) or 1.0)

    timer.Simple(delay, function()
        local now = sessions[ply]
        if not now then return end
        if not IsValid(ply) then return end
        if not IsValid(now.ore) then
            finishSession(ply, false, "Добыча прервана.")
            return
        end
        if now.token ~= stepToken then return end
        sendRound(ply)
    end)
end)

hook.Add("Think", "NexusMinerTimeoutThink", function()
    for ply, s in pairs(sessions) do
        if not IsValid(ply) then
            sessions[ply] = nil
        elseif not IsValid(s.ore) then
            finishSession(ply, false, "Добыча прервана.")
        elseif s.awaiting and CurTime() > (s.expiresAt or 0) then
            finishSession(ply, false, "Вы повредили инструмент или упустили жилу!")
        end
    end
end)

hook.Add("PlayerDisconnected", "NexusMinerCleanupDisconnect", function(ply)
    if sessions[ply] then
        finishSession(ply, false, "Добыча прервана.")
    end
end)

hook.Add("PlayerDeath", "NexusMinerCleanupDeath", function(ply)
    if sessions[ply] then
        finishSession(ply, false, "Добыча прервана.")
    end
end)

concommand.Add("nexus_miner_spawn_ore", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local ore = ents.Create("prop_physics")
    if not IsValid(ore) then return end

    ore:SetModel(NEXUS_MINER_CONFIG.OreModel or "models/props_junk/rock001a.mdl")

    if IsValid(ply) then
        local tr = ply:GetEyeTrace()
        ore:SetPos(tr.HitPos + Vector(0, 0, 8))
    else
        ore:SetPos(Vector(0, 0, 0))
    end

    ore:Spawn()

    local phys = ore:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end)