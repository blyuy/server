if CLIENT then return end

AddCSLuaFile("autorun/sh_nexus_ui_config.lua")
AddCSLuaFile("autorun/client/cl_nexus_lockpick.lua")

util.AddNetworkString("nexus_lockpick_request")
util.AddNetworkString("nexus_lockpick_open")
util.AddNetworkString("nexus_lockpick_input")
util.AddNetworkString("nexus_lockpick_update")
util.AddNetworkString("nexus_lockpick_close")

NEXUS_LOCKPICK = NEXUS_LOCKPICK or {}

local sessions = {}
local function cfgValue(key, fallback)
    local cfg = NEXUS_UI_CONFIG and NEXUS_UI_CONFIG.Lockpick
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

local function isDoor(ent)
    if not IsValid(ent) then return false end

    local class = ent:GetClass()
    return class == "prop_door_rotating"
        or class == "func_door"
        or class == "func_door_rotating"
end

local function closeSession(ply, success, message)
    sessions[ply] = nil

    net.Start("nexus_lockpick_close")
    net.WriteBool(success)
    net.WriteString(message or "")
    net.Send(ply)
end

local function openDoor(ent)
    if not IsValid(ent) then return end

    ent:Fire("unlock", "", 0)
    ent:Fire("open", "", 0)
end

function NEXUS_LOCKPICK.StartForPlayer(ply, ent)
    local requiredHits = cfgValue("requiredHits", 6)
    local roundTime = cfgValue("roundTime", 42)
    local maxUseDistance = cfgValue("maxUseDistance", 120)

    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not isDoor(ent) then return false end
    if ply:GetPos():Distance(ent:GetPos()) > maxUseDistance then return false end

    sessions[ply] = {
        ent = ent,
        hits = 0,
        required = requiredHits,
        expiresAt = CurTime() + roundTime,
        nextInputAt = 0
    }

    net.Start("nexus_lockpick_open")
    net.WriteUInt(requiredHits, 8)
    net.WriteUInt(roundTime, 8)
    net.Send(ply)

    return true
end

local function tryStartFromTrace(ply)
    local tr = ply:GetEyeTrace()
    if not tr or not IsValid(tr.Entity) then
        closeSession(ply, false, "Не найдена цель для взлома")
        return
    end

    local ok = NEXUS_LOCKPICK.StartForPlayer(ply, tr.Entity)
    if not ok then
        closeSession(ply, false, "Подойдите ближе к двери")
    end
end

net.Receive("nexus_lockpick_request", function(_, ply)
    if sessions[ply] then
        closeSession(ply, false, "Предыдущая попытка сброшена")
    end

    tryStartFromTrace(ply)
end)

net.Receive("nexus_lockpick_input", function(_, ply)
    local maxUseDistance = cfgValue("maxUseDistance", 120)
    local inputCooldown = cfgValue("inputCooldown", 0.2)
    local closeOnMiss = cfgValue("closeOnMiss", false)
    local missPenalty = cfgValue("missPenalty", 1)

    local session = sessions[ply]
    if not session then return end

    if session.expiresAt <= CurTime() then
        closeSession(ply, false, "Время вышло")
        return
    end

    if not IsValid(session.ent) then
        closeSession(ply, false, "Цель недоступна")
        return
    end

    if ply:GetPos():Distance(session.ent:GetPos()) > maxUseDistance then
        closeSession(ply, false, "Вы отошли слишком далеко")
        return
    end

    if session.nextInputAt > CurTime() then return end
    session.nextInputAt = CurTime() + inputCooldown

    local success = net.ReadBool()
    if not success then
        if closeOnMiss then
            closeSession(ply, false, "Попытка провалена")
            return
        end

        session.expiresAt = math.max(CurTime(), session.expiresAt - missPenalty)

        if session.expiresAt <= CurTime() then
            closeSession(ply, false, "Время вышло")
            return
        end

        net.Start("nexus_lockpick_update")
        net.WriteUInt(session.hits, 8)
        net.WriteUInt(session.required, 8)
        net.WriteUInt(math.max(0, math.ceil(session.expiresAt - CurTime())), 8)
        net.WriteBool(false)
        net.Send(ply)
        return
    end

    session.hits = session.hits + 1

    net.Start("nexus_lockpick_update")
    net.WriteUInt(session.hits, 8)
    net.WriteUInt(session.required, 8)
    net.WriteUInt(math.max(0, math.ceil(session.expiresAt - CurTime())), 8)
    net.WriteBool(true)
    net.Send(ply)

    if session.hits < session.required then return end

    openDoor(session.ent)
    closeSession(ply, true, "Замок вскрыт")
end)

concommand.Add("nexus_lockpick_start", function(ply)
    if not IsValid(ply) then return end
    tryStartFromTrace(ply)
end)

hook.Add("PlayerSay", "NexusLockpickChatCommand", function(ply, text)
    if not cfgValue("showChatCommands", true) then return end

    local lower = string.Trim(string.lower(text or ""))
    if lower ~= "/lockpick" and lower ~= "!lockpick" then return end

    tryStartFromTrace(ply)
    return ""
end)

hook.Add("Think", "NexusLockpickTimeout", function()
    local now = CurTime()
    for ply, session in pairs(sessions) do
        if not IsValid(ply) then
            sessions[ply] = nil
        elseif session.expiresAt <= now then
            closeSession(ply, false, "Время вышло")
        end
    end
end)

hook.Add("PlayerDisconnected", "NexusLockpickDisconnectCleanup", function(ply)
    sessions[ply] = nil
end)