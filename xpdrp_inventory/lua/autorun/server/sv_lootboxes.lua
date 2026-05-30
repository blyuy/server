XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

local Inv = XPDRP.Inv
Inv.Config = Inv.Config or {}
local Cfg = Inv.Config

-- Hard defaults so module works even if loaded before config for any reason.
Cfg.DataDir = Cfg.DataDir or "xpdrp"
Cfg.LootBoxSpawnsFile = Cfg.LootBoxSpawnsFile or (Cfg.DataDir .. "/lootbox_spawns.json")

Inv.LootBoxSpawns = Inv.LootBoxSpawns or {}
Inv.ActiveLootSessions = Inv.ActiveLootSessions or {}

util.AddNetworkString("XPDRP.Inv.OpenLootBox")
util.AddNetworkString("XPDRP.Inv.LootBoxClaim")
util.AddNetworkString("XPDRP.Inv.LootBoxRefresh")

local function ensureDir()
    if not file.Exists(Cfg.DataDir, "DATA") then
        file.CreateDir(Cfg.DataDir)
    end
end

local function readSpawns()
    ensureDir()
    if not file.Exists(Cfg.LootBoxSpawnsFile, "DATA") then
        return {}
    end
    local raw = file.Read(Cfg.LootBoxSpawnsFile, "DATA") or "[]"
    local t = util.JSONToTable(raw)
    return istable(t) and t or {}
end

local function writeSpawns(spawns)
    ensureDir()
    file.Write(Cfg.LootBoxSpawnsFile, util.TableToJSON(spawns or {}, true))
end

local function normalizeBoxId(raw)
    local id = string.Trim(tostring(raw or ""))
    if id ~= "" and Inv.LootBoxes and Inv.LootBoxes[id] then
        return id
    end

    local low = string.lower(id)
    if low ~= "" then
        for key, box in pairs(Inv.LootBoxes or {}) do
            if string.lower(tostring(key)) == low then return key end
            if string.lower(tostring(box and box.name or "")) == low then return key end
        end
    end

    return nil
end

local function firstLootBoxId()
    for key in pairs(Inv.LootBoxes or {}) do
        return key
    end
    return nil
end

function Inv.SpawnLootBox(boxId, pos, ang, model)
    boxId = normalizeBoxId(boxId)
    if not boxId then
        boxId = firstLootBoxId()
    end
    if not boxId then return end

    local cfgBox = Inv.LootBoxes[boxId]
    local ent = ents.Create("xpdrp_inv_lootbox")
    if not IsValid(ent) then return end

    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:SetBoxId(boxId)
    ent:SetBoxName(tostring(cfgBox.name or boxId))
    ent:SetRefreshSeconds(math.max(60, tonumber(cfgBox.refresh) or 600))
    ent:SetLootReady(true)
    ent:SetNextRefreshAt(0)
    ent:SetModel((isstring(model) and model ~= "") and model or cfgBox.model or "models/Items/item_item_crate.mdl")
    ent:Spawn()

    ent:SetBoxId(boxId)
    ent:SetBoxName(tostring(cfgBox.name or boxId))
end

function Inv.ReloadLootBoxes()
    for _, ent in ipairs(ents.FindByClass("xpdrp_inv_lootbox")) do
        ent:Remove()
    end

    Inv.LootBoxSpawns = readSpawns()
    for _, s in ipairs(Inv.LootBoxSpawns) do
        Inv.SpawnLootBox(
            s.boxId,
            Vector(s.pos.x, s.pos.y, s.pos.z),
            Angle(s.ang.p, s.ang.y, s.ang.r),
            s.model
        )
    end
end

function Inv.AddLootBoxSpawn(boxId, pos, ang, model)
    boxId = normalizeBoxId(boxId)
    if not boxId then
        boxId = firstLootBoxId()
        if not boxId then
            return false, "Лутбоксы не сконфигурированы"
        end
    end

    local spawns = readSpawns()
    spawns[#spawns + 1] = {
        boxId = boxId,
        pos = { x = pos.x, y = pos.y, z = pos.z },
        ang = { p = ang.p, y = ang.y, r = ang.r },
        model = model
    }

    writeSpawns(spawns)
    Inv.LootBoxSpawns = spawns
    Inv.SpawnLootBox(boxId, pos, ang, model)
    return true
end

function Inv.RemoveNearestLootBoxSpawn(pos, radius)
    radius = radius or 140
    local spawns = readSpawns()
    local bestIdx
    local bestDist = radius * radius

    for i, s in ipairs(spawns) do
        local d = Vector(s.pos.x, s.pos.y, s.pos.z):DistToSqr(pos)
        if d <= bestDist then
            bestDist = d
            bestIdx = i
        end
    end

    if not bestIdx then
        return false, "Точка не найдена"
    end

    table.remove(spawns, bestIdx)
    writeSpawns(spawns)
    Inv.LootBoxSpawns = spawns
    Inv.ReloadLootBoxes()
    return true
end

local function rollAmount(entry)
    local mn = math.max(1, math.floor(tonumber(entry.min) or tonumber(entry.qty) or 1))
    local mx = math.max(mn, math.floor(tonumber(entry.max) or mn))
    return math.random(mn, mx)
end

local function buildLootDrops(boxCfg)
    local drops = {}
    for _, entry in ipairs(boxCfg.loot or {}) do
        local chance = math.Clamp(tonumber(entry.chance) or 0, 0, 1)
        if math.Rand(0, 1) <= chance then
            drops[#drops + 1] = {
                itemId = entry.itemId,
                qty = rollAmount(entry)
            }
        end
    end

    if #drops == 0 and boxCfg.loot and boxCfg.loot[1] then
        local fallback = boxCfg.loot[1]
        drops[1] = { itemId = fallback.itemId, qty = rollAmount(fallback) }
    end

    return drops
end

local function sessionKey(ply)
    return tostring(IsValid(ply) and (ply:SteamID64() or "") or "")
end

local function collectCounts(data)
    local counts = {}
    for _, slot in ipairs(data.slots or {}) do
        counts[slot.id] = (counts[slot.id] or 0) + (slot.qty or 0)
    end
    return counts
end

local function sendLootMenu(ply, session)
    if not IsValid(ply) or not session then return end
    local data = Inv.GetPlayerData(ply)
    local boxCfg = Inv.LootBoxes and Inv.LootBoxes[session.boxId]
    local ent = Entity(session.entIndex)

    net.Start("XPDRP.Inv.OpenLootBox")
    net.WriteTable({
        sessionId = session.sessionId,
        entIndex = session.entIndex,
        boxId = session.boxId,
        boxName = (boxCfg and boxCfg.name) or session.boxId,
        drops = session.drops or {},
        counts = collectCounts(data),
        items = Inv.GetItemMapFor(data),
        lootReady = IsValid(ent) and ent:GetLootReady() or false,
        refreshAt = IsValid(ent) and ent:GetNextRefreshAt() or 0
    })
    net.Send(ply)
end

function Inv.OpenLootBoxMenu(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return false, "Ошибка" end
    if ent:GetPos():DistToSqr(ply:GetPos()) > (140 * 140) then
        return false, "Слишком далеко"
    end

    local boxId = ent:GetBoxId()
    local boxCfg = Inv.LootBoxes and Inv.LootBoxes[boxId]
    if not boxCfg then return false, "Конфиг лутбокса не найден" end

    local sid = sessionKey(ply)
    local existing = Inv.ActiveLootSessions[sid]
    if existing and tonumber(existing.entIndex or 0) == ent:EntIndex() and istable(existing.drops) and #existing.drops > 0 then
        sendLootMenu(ply, existing)
        return true
    end

    if not ent:GetLootReady() then
        local sec = math.max(0, math.ceil(ent:GetNextRefreshAt() - CurTime()))
        return false, "Пусто. Обновится через " .. tostring(sec) .. "с"
    end

    local session = {
        sessionId = string.format("lb_%d_%d", os.time(), math.random(100000, 999999)),
        entIndex = ent:EntIndex(),
        boxId = boxId,
        drops = buildLootDrops(boxCfg)
    }

    if #session.drops == 0 then
        return false, "Нечего выдавать"
    end

    -- Anti-dup: consume box on open, not on full take, so re-open cannot reroll loot.
    ent:SetLootReady(false)
    ent:SetNextRefreshAt(CurTime() + math.max(60, tonumber(boxCfg.refresh) or 600))

    Inv.ActiveLootSessions[sid] = session
    sendLootMenu(ply, session)
    return true
end

function Inv.TryLootBox(ply, ent)
    return Inv.OpenLootBoxMenu(ply, ent)
end

local function finishSession(ply, session, ent)
    Inv.ActiveLootSessions[sessionKey(ply)] = nil
end

local function claimLoot(ply, payload)
    local sid = sessionKey(ply)
    local session = Inv.ActiveLootSessions[sid]
    if not session then return false, "Сессия лута не найдена" end
    if tostring(payload.sessionId or "") ~= tostring(session.sessionId or "") then
        return false, "Сессия устарела"
    end

    local ent = Entity(tonumber(payload.entIndex or 0) or 0)
    if not IsValid(ent) then
        Inv.ActiveLootSessions[sid] = nil
        return false, "Лутбокс не найден"
    end
    if ent:GetPos():DistToSqr(ply:GetPos()) > (180 * 180) then
        return false, "Слишком далеко"
    end

    local idx = tonumber(payload.lootIndex or 0) or 0
    local entry = session.drops[idx]
    if not entry then return false, "Лут не найден" end

    local want = math.max(1, math.floor(tonumber(payload.qty) or entry.qty or 1))
    local qty = math.min(want, tonumber(entry.qty) or 0)
    if qty <= 0 then return false, "Пустой слот" end

    local data = Inv.GetPlayerData(ply)
    if not Inv.TryAddItem(data, entry.itemId, qty) then
        return false, "Нет места в инвентаре"
    end

    entry.qty = entry.qty - qty
    if entry.qty <= 0 then
        table.remove(session.drops, idx)
    end

    Inv.SavePlayerData(ply)
    if Inv.SyncPlayer then
        Inv.SyncPlayer(ply)
    end

    if #session.drops <= 0 then
        finishSession(ply, session, ent)
        return true, "Лутбокс очищен"
    end

    sendLootMenu(ply, session)
    return true, "Получено"
end

net.Receive("XPDRP.Inv.LootBoxClaim", function(_, ply)
    local payload = net.ReadTable() or {}
    local ok, msg = claimLoot(ply, payload)
    if msg and msg ~= "" then
        ply:ChatPrint("[LootBox] " .. msg)
    end
    if not ok then return end
end)

net.Receive("XPDRP.Inv.LootBoxRefresh", function(_, ply)
    local sid = sessionKey(ply)
    local session = Inv.ActiveLootSessions[sid]
    if not session then return end
    sendLootMenu(ply, session)
end)

hook.Add("InitPostEntity", "XPDRP.Inv.SpawnSavedLootBoxes", function()
    Inv.ReloadLootBoxes()
end)

hook.Add("PlayerDisconnected", "XPDRP.Inv.ClearLootSession", function(ply)
    Inv.ActiveLootSessions[sessionKey(ply)] = nil
end)