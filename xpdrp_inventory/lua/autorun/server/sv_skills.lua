XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}
XPDRP.Skills = XPDRP.Skills or {}

local Inv = XPDRP.Inv
local SkillsCfg = XPDRP.Skills.Config or {}

local jumpState = {}

local function jumpKey(ply)
    return tostring(IsValid(ply) and (ply:SteamID64() or "") or "")
end

local function resetJumpState(ply)
    if not IsValid(ply) then return end
    jumpState[jumpKey(ply)] = { used = 0, nextAt = 0 }
end

local function isGrounded(ply, mv)
    if mv and isfunction(mv.GetFlags) then
        return bit.band(mv:GetFlags(), FL_ONGROUND) ~= 0
    end
    return IsValid(ply) and ply:OnGround() or false
end

local function skillLevel(data, id)
    if not istable(data) or not istable(data.skills) then return 0 end
    return math.max(0, tonumber(data.skills[id]) or 0)
end

local function marathonRunMult(level)
    local bonus = 0
    if level >= 1 then bonus = bonus + 0.15 end
    if level >= 2 then bonus = bonus + 0.15 end
    if level >= 3 then bonus = bonus + 0.20 end
    if level >= 4 then bonus = bonus + 0.40 end
    return 1 + bonus
end

local function parkourJumpMult(level)
    local bonus = 0
    if level >= 1 then bonus = bonus + 0.10 end
    if level >= 2 then bonus = bonus + 0.10 end
    if level >= 4 then bonus = bonus + 0.10 end
    return 1 + bonus
end

local function parkourExtraJumps(level)
    if level >= 5 then return 2 end
    if level >= 3 then return 1 end
    return 0
end

function Inv.ApplySkillMovement(ply)
    if not IsValid(ply) then return end
    local data = Inv.GetPlayerData(ply)
    local mLvl = skillLevel(data, "marathoner")
    local pLvl = skillLevel(data, "parkourist")

    local run = tonumber(ply:GetRunSpeed()) or 240
    local walk = tonumber(ply:GetWalkSpeed()) or 160
    local jump = tonumber(ply:GetJumpPower()) or 200

    data._baseRunSpeed = data._baseRunSpeed or run
    data._baseWalkSpeed = data._baseWalkSpeed or walk
    data._baseJumpPower = data._baseJumpPower or jump

    local runMult = marathonRunMult(mLvl)
    local jumpMult = parkourJumpMult(pLvl)

    ply:SetRunSpeed(math.max(1, data._baseRunSpeed * runMult))
    ply:SetWalkSpeed(math.max(1, data._baseWalkSpeed * runMult))
    ply:SetJumpPower(math.max(1, data._baseJumpPower * jumpMult))
end

hook.Add("PlayerSpawn", "XPDRP.Skills.ApplyOnSpawn", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        local data = Inv.GetPlayerData(ply)
        data._baseRunSpeed = ply:GetRunSpeed()
        data._baseWalkSpeed = ply:GetWalkSpeed()
        data._baseJumpPower = ply:GetJumpPower()
        Inv.ApplySkillMovement(ply)
        resetJumpState(ply)
    end)
end)

hook.Add("PlayerDisconnected", "XPDRP.Skills.ClearJumpState", function(ply)
    jumpState[jumpKey(ply)] = nil
end)

hook.Add("EntityTakeDamage", "XPDRP.Skills.SadistDamage", function(target, dmginfo)
    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    local wep = attacker:GetActiveWeapon()
    if not IsValid(wep) then return end

    local data = Inv.GetPlayerData(attacker)
    local lvl = skillLevel(data, "sadist")
    local bonus = math.min(lvl, 3) * 0.05
    if bonus <= 0 then return end

    dmginfo:ScaleDamage(1 + bonus)
end)

hook.Add("PlayerDeath", "XPDRP.Skills.SadistReset", function(victim)
    if not IsValid(victim) then return end
    local data = Inv.GetPlayerData(victim)
    data.tempSadistBonusHP = 0
end)

hook.Add("PlayerDeath", "XPDRP.Skills.SadistOnKill", function(victim, _, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
    local data = Inv.GetPlayerData(attacker)
    if skillLevel(data, "sadist") < 4 then return end

    data.tempSadistBonusHP = (tonumber(data.tempSadistBonusHP) or 0) + 20
    local newMax = attacker:GetMaxHealth() + 20
    attacker:SetMaxHealth(newMax)
    attacker:SetHealth(math.min(newMax, attacker:Health() + 20))
    Inv.SavePlayerData(attacker)
    if Inv.SyncPlayer then Inv.SyncPlayer(attacker) end
end)

hook.Add("SetupMove", "XPDRP.Skills.ExtraJumps.Reset", function(ply, mv)
    if not IsValid(ply) or not ply:Alive() then return end
    local data = Inv.GetPlayerData(ply)
    local extra = parkourExtraJumps(skillLevel(data, "parkourist"))
    if extra <= 0 then return end

    local sid = jumpKey(ply)
    jumpState[sid] = jumpState[sid] or { used = 0, nextAt = 0 }
    local st = jumpState[sid]

    if isGrounded(ply, mv) then
        st.used = 0
    end
end)

hook.Add("KeyPress", "XPDRP.Skills.ExtraJumps.Trigger", function(ply, key)
    if key ~= IN_JUMP then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:OnGround() then return end
    if ply:WaterLevel() >= 2 then return end
    if ply:GetMoveType() == MOVETYPE_LADDER then return end

    local data = Inv.GetPlayerData(ply)
    local extra = parkourExtraJumps(skillLevel(data, "parkourist"))
    if extra <= 0 then return end

    local sid = jumpKey(ply)
    jumpState[sid] = jumpState[sid] or { used = 0, nextAt = 0 }
    local st = jumpState[sid]

    if st.used >= extra then return end
    if st.nextAt > CurTime() then return end

    local boost = math.max(110, math.floor((ply:GetJumpPower() or 200) * 0.9))
    ply:SetVelocity(Vector(0, 0, boost))
    st.used = st.used + 1
    st.nextAt = CurTime() + 0.08
end)

hook.Add("playerCanChangeTeam", "XPDRP.Skills.JobLocks", function(ply, teamId)
    local defs = (SkillsCfg and SkillsCfg.Definitions) or {}
    local data = Inv.GetPlayerData(ply)

    for skillId, def in pairs(defs) do
        if def.unlockTeam and _G[def.unlockTeam] == teamId then
            if skillLevel(data, skillId) < (def.maxLevel or 5) then
                return false, "Профессия открывается навыком: " .. tostring(def.name)
            end
        end
    end
end)

function Inv.ActionSkillUpgrade(ply, data, skillId)
    local defs = (SkillsCfg and SkillsCfg.Definitions) or {}
    local def = defs[skillId]
    if not def then return false, "Навык не найден" end

    data.skillPoints = math.max(0, tonumber(data.skillPoints) or 0)
    if data.skillPoints <= 0 then
        return false, "Нет очков навыка"
    end

    local maxLevel = tonumber(def.maxLevel) or tonumber(SkillsCfg.MaxLevel) or 5
    data.skills[skillId] = math.max(0, tonumber(data.skills[skillId]) or 0)
    if data.skills[skillId] >= maxLevel then
        return false, "Максимальный уровень"
    end

    data.skills[skillId] = data.skills[skillId] + 1
    data.skillPoints = data.skillPoints - 1

    Inv.ApplySkillMovement(ply)
    return true
end

timer.Create("XPDRP.Skills.Playtime", 60, 0, function()
    local step = 60
    local secondsPerPoint = math.max(600, tonumber(SkillsCfg.SecondsPerPoint) or 36000)

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        local data = Inv.GetPlayerData(ply)
        data.playtimeSeconds = math.max(0, tonumber(data.playtimeSeconds) or 0) + step

        local awarded = 0
        while data.playtimeSeconds >= secondsPerPoint do
            data.playtimeSeconds = data.playtimeSeconds - secondsPerPoint
            data.skillPoints = (tonumber(data.skillPoints) or 0) + 1
            awarded = awarded + 1
        end

        if awarded > 0 then
            ply:ChatPrint("[Skills] Выдано очков навыка: " .. tostring(awarded))
            if Inv.SyncPlayer then Inv.SyncPlayer(ply) end
        end
        Inv.SavePlayerData(ply)
    end
end)

local function canManageSkills(caller)
    if not IsValid(caller) then return true end
    return caller:IsSuperAdmin()
end

local function findOnlineBySid64(sid64)
    sid64 = tostring(sid64 or "")
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID64() == sid64 then
            return ply
        end
    end
    return nil
end

local function notify(caller, txt)
    if IsValid(caller) then
        caller:ChatPrint(txt)
    else
        print(txt)
    end
end

concommand.Add("xpdrp_skill_points_give", function(caller, _, args)
    if not canManageSkills(caller) then return end
    local sid64 = tostring(args[1] or "")
    local amount = math.max(1, math.floor(tonumber(args[2] or 1) or 1))
    local target = findOnlineBySid64(sid64)
    if not IsValid(target) then
        return notify(caller, "[Skills] Игрок не найден онлайн")
    end
    local data = Inv.GetPlayerData(target)
    data.skillPoints = (tonumber(data.skillPoints) or 0) + amount
    Inv.SavePlayerData(target)
    if Inv.SyncPlayer then Inv.SyncPlayer(target) end
    notify(caller, "[Skills] Выдано очков: " .. tostring(amount))
end)

concommand.Add("xpdrp_skill_points_take", function(caller, _, args)
    if not canManageSkills(caller) then return end
    local sid64 = tostring(args[1] or "")
    local amount = math.max(1, math.floor(tonumber(args[2] or 1) or 1))
    local target = findOnlineBySid64(sid64)
    if not IsValid(target) then
        return notify(caller, "[Skills] Игрок не найден онлайн")
    end
    local data = Inv.GetPlayerData(target)
    data.skillPoints = math.max(0, (tonumber(data.skillPoints) or 0) - amount)
    Inv.SavePlayerData(target)
    if Inv.SyncPlayer then Inv.SyncPlayer(target) end
    notify(caller, "[Skills] Снято очков: " .. tostring(amount))
end)

concommand.Add("xpdrp_skill_set", function(caller, _, args)
    if not canManageSkills(caller) then return end
    local sid64 = tostring(args[1] or "")
    local skillId = tostring(args[2] or "")
    local level = math.max(0, math.floor(tonumber(args[3] or 0) or 0))
    local def = (SkillsCfg.Definitions or {})[skillId]
    if not def then
        return notify(caller, "[Skills] Навык не найден")
    end

    local target = findOnlineBySid64(sid64)
    if not IsValid(target) then
        return notify(caller, "[Skills] Игрок не найден онлайн")
    end

    local data = Inv.GetPlayerData(target)
    data.skills[skillId] = math.Clamp(level, 0, tonumber(def.maxLevel) or 5)
    Inv.ApplySkillMovement(target)
    Inv.SavePlayerData(target)
    if Inv.SyncPlayer then Inv.SyncPlayer(target) end
    notify(caller, "[Skills] Установлен " .. skillId .. " = " .. tostring(data.skills[skillId]))
end)