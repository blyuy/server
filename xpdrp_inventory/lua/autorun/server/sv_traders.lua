XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

local Inv = XPDRP.Inv
local Cfg = Inv.Config

util.AddNetworkString("XPDRP.Inv.OpenTrader")
util.AddNetworkString("XPDRP.Inv.RequestTrader")

Inv.TraderSpawns = Inv.TraderSpawns or {}
Inv.ActiveTraderByPlayer = Inv.ActiveTraderByPlayer or {}
Inv.ActiveTraderEntByPlayer = Inv.ActiveTraderEntByPlayer or {}

local function normalizeTraderId(raw)
    local id = string.Trim(tostring(raw or ""))
    if id ~= "" and Inv.Traders[id] then
        return id
    end

    local low = string.lower(id)
    if low ~= "" then
        for key, trader in pairs(Inv.Traders or {}) do
            if string.lower(tostring(key)) == low then
                return key
            end
            if string.lower(tostring(trader and trader.name or "")) == low then
                return key
            end
        end
    end

    return nil
end

local function ensureDir()
    if not file.Exists(Cfg.DataDir, "DATA") then
        file.CreateDir(Cfg.DataDir)
    end
end

local function readSpawns()
    ensureDir()
    if not file.Exists(Cfg.TraderSpawnsFile, "DATA") then
        return {}
    end
    local raw = file.Read(Cfg.TraderSpawnsFile, "DATA") or "[]"
    local t = util.JSONToTable(raw)
    return istable(t) and t or {}
end

local function writeSpawns(spawns)
    ensureDir()
    file.Write(Cfg.TraderSpawnsFile, util.TableToJSON(spawns or {}, true))
end

function Inv.SpawnTrader(traderId, pos, ang, model)
    local traderCfg = Inv.Traders[traderId]
    if not traderCfg then return end
    local ent = ents.Create("xpdrp_inv_trader")
    if not IsValid(ent) then return end

    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:SetTraderId(traderId)
    ent:SetTraderName(tostring(traderCfg.name or traderId))
    if isstring(model) and model ~= "" then
        ent:SetModel(model)
    end
    ent:Spawn()
    -- Re-apply networked fields after Spawn for bases that can reset datatable values.
    ent:SetTraderId(traderId)
    ent:SetTraderName(tostring(traderCfg.name or traderId))
end

function Inv.ReloadTraders()
    for _, ent in ipairs(ents.FindByClass("xpdrp_inv_trader")) do
        ent:Remove()
    end

    Inv.TraderSpawns = readSpawns()
    for _, s in ipairs(Inv.TraderSpawns) do
        Inv.SpawnTrader(s.traderId, Vector(s.pos.x, s.pos.y, s.pos.z), Angle(s.ang.p, s.ang.y, s.ang.r), s.model)
    end
end

function Inv.AddTraderSpawn(traderId, pos, ang, model)
    traderId = normalizeTraderId(traderId)
    if not traderId then
        return false, "Торговец не найден"
    end

    local spawns = readSpawns()
    spawns[#spawns + 1] = {
        traderId = traderId,
        pos = { x = pos.x, y = pos.y, z = pos.z },
        ang = { p = ang.p, y = ang.y, r = ang.r },
        model = model
    }
    writeSpawns(spawns)
    Inv.TraderSpawns = spawns
    Inv.SpawnTrader(traderId, pos, ang, model)
    return true
end

function Inv.RemoveNearestTraderSpawn(pos, radius)
    radius = radius or 120
    local spawns = readSpawns()
    local bestIdx
    local bestDist = (radius * radius)

    for idx, s in ipairs(spawns) do
        local d = Vector(s.pos.x, s.pos.y, s.pos.z):DistToSqr(pos)
        if d <= bestDist then
            bestDist = d
            bestIdx = idx
        end
    end

    if not bestIdx then
        return false, "Точка не найдена"
    end

    table.remove(spawns, bestIdx)
    writeSpawns(spawns)
    Inv.TraderSpawns = spawns
    Inv.ReloadTraders()
    return true
end

local function sendTraderMenu(ply, traderId, traderEntIndex)
    traderId = Inv.ResolveTraderId and Inv.ResolveTraderId(ply, traderId, traderEntIndex) or traderId
    local data = Inv.GetPlayerData(ply)
    local trader = Inv.Traders[traderId]
    if not trader then return end

    if IsValid(ply) then
        local sid64 = tostring(ply:SteamID64() or "")
        Inv.ActiveTraderByPlayer[sid64] = traderId
        Inv.ActiveTraderEntByPlayer[sid64] = tonumber(traderEntIndex or 0) or 0
    end

    local counts = {}
    for _, slot in ipairs(data.slots or {}) do
        counts[slot.id] = (counts[slot.id] or 0) + (slot.qty or 0)
    end

    net.Start("XPDRP.Inv.OpenTrader")
    net.WriteTable({
        traderId = traderId,
        traderEnt = tonumber(traderEntIndex or 0) or 0,
        trader = trader,
        balance = Inv.GetPlayerBalance(ply, data),
        counts = counts,
        items = Inv.GetItemMapFor(data)
    })
    net.Send(ply)
end

function Inv.OpenTraderMenu(ply, traderId, sourceEnt)
    local entIndex = IsValid(sourceEnt) and sourceEnt:EntIndex() or 0
    sendTraderMenu(ply, traderId, entIndex)
end

net.Receive("XPDRP.Inv.RequestTrader", function(_, ply)
    local traderId = tostring(net.ReadString() or "")
    local entIndex = 0
    if net.BytesLeft() >= 2 then
        entIndex = net.ReadUInt(16)
    end
    sendTraderMenu(ply, traderId, entIndex)
end)

hook.Add("InitPostEntity", "XPDRP.Inv.SpawnSavedTraders", function()
    Inv.ReloadTraders()
end)

hook.Add("PlayerDisconnected", "XPDRP.Inv.ClearActiveTrader", function(ply)
    if not IsValid(ply) then return end
    local sid64 = tostring(ply:SteamID64() or "")
    Inv.ActiveTraderByPlayer[sid64] = nil
    Inv.ActiveTraderEntByPlayer[sid64] = nil
end)