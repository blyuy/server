XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

local Inv = XPDRP.Inv
local Cfg = Inv.Config

Inv.DB = Inv.DB or {}

local function ensureDataDir()
    if not file.Exists(Cfg.DataDir, "DATA") then
        file.CreateDir(Cfg.DataDir)
    end
end

function Inv.ReadAll()
    ensureDataDir()
    if not file.Exists(Cfg.DataFile, "DATA") then
        return {}
    end

    local raw = file.Read(Cfg.DataFile, "DATA") or "{}"
    local parsed = util.JSONToTable(raw)
    return istable(parsed) and parsed or {}
end

function Inv.WriteAll(all)
    ensureDataDir()
    file.Write(Cfg.DataFile, util.TableToJSON(all or {}, true))
end

function Inv.GetDefaultPlayerData()
    return {
        balance = 12000,
        maxSlots = Cfg.MaxSlots,
        slots = {
            { id = "metal_scrap", qty = 50 },
            { id = "polymer", qty = 15 }
        },
        customItems = {},
        txSet = {},
        txOrder = {},
        skillPoints = 0,
        playtimeSeconds = 0,
        skills = {
            marathoner = 0,
            sadist = 0,
            parkourist = 0
        },
        tempSadistBonusHP = 0
    }
end

local function normalizePlayerData(data)
    data = istable(data) and data or {}

    data.maxSlots = tonumber(data.maxSlots) or Cfg.MaxSlots
    data.balance = tonumber(data.balance) or 12000

    if not istable(data.slots) then
        data.slots = {}
    end

    if not istable(data.customItems) then
        data.customItems = {}
    end

    if not istable(data.txOrder) then
        data.txOrder = {}
    end

    if not istable(data.txSet) then
        data.txSet = {}
        for _, txid in ipairs(data.txOrder) do
            data.txSet[tostring(txid)] = true
        end
    end

    data.skillPoints = math.max(0, math.floor(tonumber(data.skillPoints) or 0))
    data.playtimeSeconds = math.max(0, math.floor(tonumber(data.playtimeSeconds) or 0))
    data.tempSadistBonusHP = math.max(0, math.floor(tonumber(data.tempSadistBonusHP) or 0))

    if not istable(data.skills) then
        data.skills = {}
    end
    data.skills.marathoner = math.max(0, math.floor(tonumber(data.skills.marathoner) or 0))
    data.skills.sadist = math.max(0, math.floor(tonumber(data.skills.sadist) or 0))
    data.skills.parkourist = math.max(0, math.floor(tonumber(data.skills.parkourist) or 0))

    return data
end

local function storageKeyForPlayer(ply)
    if not IsValid(ply) then return "none" end
    local sid64 = ply:SteamID64() or "0"
    return "sid64:" .. sid64
end

function Inv.GetPlayerData(ply)
    local key = storageKeyForPlayer(ply)
    if key == "none" or key == "sid64:0" then
        return Inv.GetDefaultPlayerData()
    end

    if Inv.DB[key] then
        return Inv.DB[key]
    end

    local all = Inv.ReadAll()

    -- Legacy migration: old builds used plain SteamID64 key.
    local sid64 = IsValid(ply) and (ply:SteamID64() or "0") or "0"
    if sid64 ~= "0" and not all[key] then
        if all[sid64] then
            all[key] = all[sid64]
            all[sid64] = nil
        else
            for oldKey, oldValue in pairs(all) do
                if tostring(oldKey) == sid64 then
                    all[key] = oldValue
                    all[oldKey] = nil
                    break
                end
            end
        end
    end

    all[key] = normalizePlayerData(all[key] or Inv.GetDefaultPlayerData())
    Inv.DB[key] = all[key]
    Inv.WriteAll(all)

    return Inv.DB[key]
end

function Inv.SavePlayerData(ply)
    if not IsValid(ply) then return end
    local key = storageKeyForPlayer(ply)

    local all = Inv.ReadAll()
    all[key] = normalizePlayerData(Inv.DB[key] or Inv.GetDefaultPlayerData())
    Inv.WriteAll(all)
end