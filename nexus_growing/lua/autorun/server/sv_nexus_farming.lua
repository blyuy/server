if CLIENT then return end

AddCSLuaFile("autorun/sh_nexus_farming_config.lua")
AddCSLuaFile("autorun/sh_nexus_farming_inv_items.lua")
AddCSLuaFile("autorun/client/cl_nexus_farming.lua")

util.AddNetworkString("nexus_farm_open")
util.AddNetworkString("nexus_farm_request")
util.AddNetworkString("nexus_farm_game_begin")
util.AddNetworkString("nexus_farm_game_update")
util.AddNetworkString("nexus_farm_game_finish")
util.AddNetworkString("nexus_farm_game_input")
util.AddNetworkString("nexus_farm_notify")

NEXUS_FARM = NEXUS_FARM or {}

local sessions = {}
local invApi = { addItem = nil, removeItem = nil, sendSync = nil }

local function cfg()
    return NEXUS_FARM_CFG or {}
end

local function bindInvApi()
    if NEXUS_INV then
        if isfunction(NEXUS_INV.AddItem) then invApi.addItem = NEXUS_INV.AddItem end
        if isfunction(NEXUS_INV.RemoveItem) then invApi.removeItem = NEXUS_INV.RemoveItem end
        if isfunction(NEXUS_INV.SendSync) then invApi.sendSync = NEXUS_INV.SendSync end
    end
    return isfunction(invApi.addItem) and isfunction(invApi.removeItem) and isfunction(invApi.sendSync)
end

timer.Create("NexusFarmBindInvApi", 1, 0, function()
    if bindInvApi() then timer.Remove("NexusFarmBindInvApi") end
end)

local function notify(ply, msg)
    net.Start("nexus_farm_notify")
    net.WriteString(msg or "")
    net.Send(ply)
end

local function canUsePot(ply, ent)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not IsValid(ent) or ent:GetClass() ~= "sent_pot" then return false end

    local maxDist = tonumber(cfg().UseDistance or 150) or 150
    if ply:GetPos():DistToSqr(ent:GetPos()) > (maxDist * maxDist) then return false end

    local owner = ent:GetOwnerSID64()
    if owner ~= "" and owner ~= ply:SteamID64() and not ply:IsAdmin() then return false end

    return true
end

local function stageToGame(stage)
    if stage == 1 then return 1 end
    if stage == 2 then return 2 end
    if stage == 3 then return 3 end
    return 0
end

local function resetPlant(ent)
    if not IsValid(ent) then return end
    ent:SetPlantStage(0)
    ent:SetNextActionAt(0)
    ent:SetBusy(false)
end

local function finishFail(ply, msg)
    local s = sessions[ply]
    if not s then return end

    if IsValid(s.ent) then resetPlant(s.ent) end
    sessions[ply] = nil

    net.Start("nexus_farm_game_finish")
    net.WriteBool(false)
    net.WriteString(msg or "Провал")
    net.Send(ply)
end

local function finishSuccess(ply, msg)
    local s = sessions[ply]
    if not s then return end

    local ent = s.ent
    sessions[ply] = nil
    if not IsValid(ent) then return end

    local st = ent:GetPlantStage()
    local cd = tonumber(cfg().StageCooldown or 60) or 60

    if s.gameType == 1 and st == 1 then
        ent:SetPlantStage(2)
        ent:SetNextActionAt(CurTime() + cd)
        ent:SetBusy(false)
    elseif s.gameType == 2 and st == 2 then
        ent:SetPlantStage(3)
        ent:SetNextActionAt(CurTime() + cd)
        ent:SetBusy(false)
    elseif s.gameType == 3 and st == 3 then
        if not bindInvApi() then
            resetPlant(ent)
            net.Start("nexus_farm_game_finish")
            net.WriteBool(false)
            net.WriteString("Инвентарь недоступен")
            net.Send(ply)
            return
        end

        local rewardId = (cfg().Items and cfg().Items.reward) or "parsley_dried_pack"
        local ok = invApi.addItem(ply, rewardId, 1)
        if ok then invApi.sendSync(ply) end
        resetPlant(ent)
    else
        finishFail(ply, "Некорректная стадия.")
        return
    end

    net.Start("nexus_farm_game_finish")
    net.WriteBool(true)
    net.WriteString(msg or "Успех")
    net.Send(ply)
end

-- КЛЮЧЕВОЙ ФИКС: этап 1 проходит только по порогу стабильности (клики не обязательны)
local function stage1Passed(s)
    local c = cfg().Stage1
    local needStability = tonumber(c.needStability or 45) or 45
    return (tonumber(s.stability) or 0) >= needStability
end

function NEXUS_FARM.OpenPotMenu(ply, ent)
    if not canUsePot(ply, ent) then return end

    net.Start("nexus_farm_open")
    net.WriteEntity(ent)
    net.WriteUInt(ent:GetPlantStage(), 3)
    net.WriteFloat(ent:GetNextActionAt())
    net.Send(ply)
end

local function beginStage1(ply, ent)
    local c = cfg().Stage1
    sessions[ply] = {
        ent = ent,
        gameType = 1,
        started = CurTime(),
        expires = CurTime() + c.duration,
        phase = math.Rand(0, math.pi * 2),
        speed = c.speed,
        stability = 50,
        clicks = 0
    }

    ent:SetBusy(true)

    net.Start("nexus_farm_game_begin")
    net.WriteUInt(1, 3)
    net.WriteFloat(c.duration)
    net.WriteFloat(sessions[ply].phase)
    net.WriteFloat(c.speed)
    net.WriteFloat(c.zoneMin)
    net.WriteFloat(c.zoneMax)
    net.Send(ply)
end

local function beginStage2(ply, ent)
    local c = cfg().Stage2
    local pool = {
        {0.2,0.25},{0.35,0.38},{0.55,0.28},{0.72,0.42},
        {0.26,0.58},{0.44,0.62},{0.62,0.70},{0.78,0.60}
    }

    local used, points = {}, {}
    for i = 1, c.pointsToHit do
        local idx
        repeat idx = math.random(1, #pool) until not used[idx]
        used[idx] = true
        points[i] = pool[idx]
    end

    sessions[ply] = {
        ent = ent,
        gameType = 2,
        expires = CurTime() + c.timeLimit,
        points = points,
        hit = {}
    }

    ent:SetBusy(true)

    net.Start("nexus_farm_game_begin")
    net.WriteUInt(2, 3)
    net.WriteFloat(c.timeLimit)
    net.WriteUInt(#points, 8)
    for i = 1, #points do
        net.WriteFloat(points[i][1])
        net.WriteFloat(points[i][2])
    end
    net.Send(ply)
end

local function beginStage3(ply, ent)
    local c = cfg().Stage3
    local seq = {}
    for i = 1, c.sequenceLen do
        seq[i] = c.keys[math.random(1, #c.keys)]
    end

    sessions[ply] = {
        ent = ent,
        gameType = 3,
        expires = CurTime() + c.timeLimit,
        seq = seq,
        idx = 1
    }

    ent:SetBusy(true)

    net.Start("nexus_farm_game_begin")
    net.WriteUInt(3, 3)
    net.WriteFloat(c.timeLimit)
    net.WriteUInt(#seq, 8)
    for i = 1, #seq do
        net.WriteString(seq[i])
    end
    net.Send(ply)
end

net.Receive("nexus_farm_request", function(_, ply)
    local action = net.ReadString()
    local ent = net.ReadEntity()

    if not canUsePot(ply, ent) then return end

    if action == "open" then
        NEXUS_FARM.OpenPotMenu(ply, ent)
        return
    end

    if action == "plant" then
        if ent:GetPlantStage() ~= 0 then
            notify(ply, "Горшок уже занят.")
            return
        end

        if not bindInvApi() then
            notify(ply, "Инвентарь недоступен.")
            return
        end

        local items = cfg().Items or {}
        local seed = items.seed or "parsley_seed"
        local soil = items.soil or "parsley_soil"
        local water = items.water or "parsley_water"

        local okSeed = invApi.removeItem(ply, seed, 1)
        local okSoil = invApi.removeItem(ply, soil, 1)
        local okWater = invApi.removeItem(ply, water, 1)

        if not (okSeed and okSoil and okWater) then
            if okSeed then invApi.addItem(ply, seed, 1) end
            if okSoil then invApi.addItem(ply, soil, 1) end
            if okWater then invApi.addItem(ply, water, 1) end
            invApi.sendSync(ply)
            notify(ply, "Нужны: семя, земля, вода.")
            return
        end

        invApi.sendSync(ply)
        ent:SetPlantStage(1)
        ent:SetNextActionAt(0)
        ent:SetBusy(false)
        if ent:GetOwnerSID64() == "" then
            ent:SetOwnerSID64(ply:SteamID64() or "")
        end

        notify(ply, "Семя посажено.")
        NEXUS_FARM.OpenPotMenu(ply, ent)
        return
    end

    if action == "start_game" then
        if ent:GetBusy() then
            notify(ply, "Этап уже активен.")
            return
        end

        local st = ent:GetPlantStage()
        if st <= 0 then
            notify(ply, "Сначала посадите семя.")
            return
        end

        if ent:GetNextActionAt() > CurTime() then
            notify(ply, "Подождите откат этапа.")
            return
        end

        sessions[ply] = nil

        local gameType = stageToGame(st)
        if gameType == 1 then beginStage1(ply, ent)
        elseif gameType == 2 then beginStage2(ply, ent)
        elseif gameType == 3 then beginStage3(ply, ent)
        end
    end
end)

net.Receive("nexus_farm_game_input", function(_, ply)
    local ent = net.ReadEntity()
    local inputType = net.ReadUInt(3)

    local s = sessions[ply]
    if not s then return end
    if not IsValid(ent) or ent ~= s.ent then return end

    if not canUsePot(ply, ent) then
        finishFail(ply, "Слишком далеко от горшка.")
        return
    end

    if stageToGame(ent:GetPlantStage()) ~= s.gameType then
        finishFail(ply, "Стадия изменилась.")
        return
    end

    if CurTime() > s.expires then
        if s.gameType == 1 and stage1Passed(s) then
            finishSuccess(ply, "Этап 1 пройден.")
        else
            finishFail(ply, s.gameType == 1 and "Растение увяло на этапе 1." or "Время вышло.")
        end
        return
    end

    if inputType == 1 and s.gameType == 1 then
        local c = cfg().Stage1
        local t = CurTime() - s.started
        local pos = 0.5 + 0.45 * math.sin((t * s.speed) + s.phase)
        local inZone = (pos >= c.zoneMin and pos <= c.zoneMax)

        s.clicks = (s.clicks or 0) + 1
        if inZone then
            s.stability = math.min(100, (tonumber(s.stability) or 0) + c.stabilityGood)
        else
            s.stability = math.max(0, (tonumber(s.stability) or 0) - c.stabilityBad)
        end

        net.Start("nexus_farm_game_update")
        net.WriteUInt(1, 3)
        net.WriteUInt(math.floor(s.stability), 8)
        net.Send(ply)

        -- Моментальный успех при достижении порога
        if stage1Passed(s) then
            finishSuccess(ply, "Этап 1 пройден.")
        end
        return
    end

    if inputType == 2 and s.gameType == 2 then
        local idx = net.ReadUInt(8)
        if idx < 1 or idx > #s.points then return end
        if s.hit[idx] then return end
        s.hit[idx] = true

        local count = 0
        for _ in pairs(s.hit) do count = count + 1 end

        net.Start("nexus_farm_game_update")
        net.WriteUInt(2, 3)
        net.WriteUInt(count, 8)
        net.Send(ply)

        if count >= #s.points then
            finishSuccess(ply, "Этап 2 пройден.")
        end
        return
    end

    if inputType == 3 and s.gameType == 3 then
        local key = net.ReadString()
        local expected = s.seq[s.idx]

        if key ~= expected then
            finishFail(ply, "Растение увяло (ошибка QTE).")
            return
        end

        s.idx = s.idx + 1

        net.Start("nexus_farm_game_update")
        net.WriteUInt(3, 3)
        net.WriteUInt(s.idx - 1, 8)
        net.Send(ply)

        if s.idx > #s.seq then
            finishSuccess(ply, "Урожай собран и высушен.")
        end
        return
    end
end)

hook.Add("Think", "NexusFarmSessionThink", function()
    for ply, s in pairs(sessions) do
        if not IsValid(ply) then
            sessions[ply] = nil
        elseif not IsValid(s.ent) then
            sessions[ply] = nil
        elseif CurTime() > s.expires then
            if s.gameType == 1 and stage1Passed(s) then
                finishSuccess(ply, "Этап 1 пройден.")
            else
                finishFail(ply, s.gameType == 1 and "Растение увяло на этапе 1." or "Время вышло.")
            end
        end
    end
end)

hook.Add("PlayerDisconnected", "NexusFarmDisconnect", function(ply)
    sessions[ply] = nil
end)