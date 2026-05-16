if SERVER then return end

local active = {}
local lootFrame
local adminFrame
local adminData
local selectedTargetId
local selectedSpawnId
local ui = {}

surface.CreateFont("NexusRobTitle", { font = "Roboto", size = 28, weight = 900, antialias = true })
surface.CreateFont("NexusRobBody", { font = "Roboto", size = 16, weight = 500, antialias = true })
surface.CreateFont("NexusRobSmall", { font = "Roboto", size = 13, weight = 500, antialias = true })

local function clone(tbl)
    if not istable(tbl) then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = clone(v) end
    return out
end

local function ensureAdminData()
    adminData = adminData or {}
    adminData.settings = adminData.settings or {}
    adminData.targets = adminData.targets or {}
    adminData.spawns = adminData.spawns or {}
end

local function newLabel(parent, x, y, txt, w)
    local l = vgui.Create("DLabel", parent)
    l:SetPos(x, y)
    l:SetSize(w or 180, 18)
    l:SetFont("NexusRobSmall")
    l:SetTextColor(Color(210, 220, 240))
    l:SetText(txt)
    return l
end

local function newEntry(parent, x, y, w, value)
    local e = vgui.Create("DTextEntry", parent)
    e:SetPos(x, y)
    e:SetSize(w, 24)
    e:SetValue(tostring(value or ""))
    return e
end

local function vecEntryRead(ax, ay, az)
    return {
        x = tonumber(ax:GetValue()) or 0,
        y = tonumber(ay:GetValue()) or 0,
        z = tonumber(az:GetValue()) or 0
    }
end

local function vecEntrySet(ax, ay, az, v)
    v = v or {}
    ax:SetValue(tostring(v.x or 0))
    ay:SetValue(tostring(v.y or 0))
    az:SetValue(tostring(v.z or 0))
end

local function angEntryRead(ap, ay, ar)
    return {
        p = tonumber(ap:GetValue()) or 0,
        y = tonumber(ay:GetValue()) or 0,
        r = tonumber(ar:GetValue()) or 0
    }
end

local function angEntrySet(ap, ay, ar, v)
    v = v or {}
    ap:SetValue(tostring(v.p or 0))
    ay:SetValue(tostring(v.y or 0))
    ar:SetValue(tostring(v.r or 0))
end

local function sortedTargetIds()
    local out = {}
    for id, _ in pairs((adminData and adminData.targets) or {}) do
        out[#out + 1] = id
    end
    table.sort(out, function(a, b) return a < b end)
    return out
end

local function sortedSpawns()
    local out = {}
    for i = 1, #(adminData and adminData.spawns or {}) do
        out[#out + 1] = adminData.spawns[i]
    end
    table.sort(out, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return out
end

local function findSpawnById(id)
    for i = 1, #(adminData.spawns or {}) do
        if tostring(adminData.spawns[i].id) == tostring(id) then
            return adminData.spawns[i], i
        end
    end
    return nil, nil
end

local function parseCsvTeams(text)
    local out = {}
    for token in string.gmatch(text or "", "([^,%s]+)") do
        local n = tonumber(token)
        if n then out[#out + 1] = math.floor(n) end
    end
    return out
end

local function openLoot(ent, rows)
    if IsValid(lootFrame) then lootFrame:Remove() end

    lootFrame = vgui.Create("DFrame")
    lootFrame:SetSize(520, 460)
    lootFrame:Center()
    lootFrame:SetTitle("")
    lootFrame:ShowCloseButton(false)
    lootFrame:MakePopup()
    lootFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(10, 14, 26, 245))
        draw.SimpleText("РОЗЫСК: ЛУТ", "NexusRobTitle", 16, 28, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", lootFrame)
    close:SetPos(lootFrame:GetWide() - 88, 18)
    close:SetSize(72, 30)
    close:SetText("Закрыть")
    close.DoClick = function() lootFrame:Remove() end

    local list = vgui.Create("DScrollPanel", lootFrame)
    list:SetPos(14, 64)
    list:SetSize(lootFrame:GetWide() - 28, lootFrame:GetTall() - 78)

    for i = 1, #rows do
        local row = rows[i]
        local line = vgui.Create("DButton", list)
        line:Dock(TOP)
        line:DockMargin(0, 0, 0, 8)
        line:SetTall(54)
        line:SetText("")
        line.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(22, 30, 50, self:IsHovered() and 245 or 225))
            draw.SimpleText(row.id, "NexusRobBody", 12, 18, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("x" .. tostring(row.amount), "NexusRobBody", w - 12, 18, Color(190, 208, 242), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Нажмите, чтобы взять 1 шт", "NexusRobSmall", 12, 38, Color(150, 170, 206), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        line.DoClick = function()
            net.Start("nexus_robbery_take_loot")
            net.WriteEntity(ent)
            net.WriteUInt(i, 8)
            net.SendToServer()
        end
    end
end

net.Receive("nexus_robbery_open_loot", function()
    local ent = net.ReadEntity()
    local n = net.ReadUInt(8)

    local rows = {}
    for i = 1, n do
        rows[i] = {
            id = net.ReadString(),
            amount = net.ReadUInt(16)
        }
    end

    openLoot(ent, rows)
end)

net.Receive("nexus_robbery_police_alert", function()
    local targetName = net.ReadString()
    local robberName = net.ReadString()
    local pos = net.ReadVector()

    chat.AddText(Color(255, 120, 120), "[POLICE] ", color_white, "Ограбление: ", Color(255, 220, 120), targetName, color_white, " | Грабитель: ", robberName)
    chat.AddText(Color(170, 190, 230), "Координаты: ", tostring(math.floor(pos.x)) .. " " .. tostring(math.floor(pos.y)) .. " " .. tostring(math.floor(pos.z)))
end)

net.Receive("nexus_robbery_sync", function()
    active = {}
    local n = net.ReadUInt(10)
    for i = 1, n do
        active[#active + 1] = {
            ent = net.ReadEntity(),
            center = net.ReadVector(),
            mins = net.ReadVector(),
            maxs = net.ReadVector(),
            endAt = net.ReadFloat(),
            unlocked = net.ReadBool(),
            robber = net.ReadString(),
            name = net.ReadString()
        }
    end
end)

hook.Add("PostDrawTranslucentRenderables", "NexusRobberyZoneDraw", function()
    if #active == 0 then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for i = 1, #active do
        local row = active[i]
        if not IsValid(row.ent) then continue end
        if lp:GetPos():DistToSqr(row.center) > (1500 * 1500) then continue end

        local col = row.unlocked and Color(90, 230, 120, 210) or Color(240, 70, 70, 230)
        render.DrawWireframeBox(row.center, angle_zero, row.mins, row.maxs, col, true)

        local p = row.ent:GetPos() + Vector(0, 0, 24)
        local a = EyeAngles()
        a = Angle(0, a.y - 90, 90)

        cam.Start3D2D(p, a, 0.08)
            draw.RoundedBox(8, -160, -28, 320, 56, Color(9, 14, 28, 225))
            draw.SimpleText(row.name, "NexusRobBody", 0, -10, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            local left = math.max(0, math.ceil(row.endAt - CurTime()))
            local status = row.unlocked and "ВСКРЫТО" or ("ВЗЛОМ: " .. left .. "с")
            draw.SimpleText(status, "NexusRobBody", 0, 12, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end)

local function refreshTargetsList()
    ui.targetsList:Clear()
    for _, id in ipairs(sortedTargetIds()) do
        local t = adminData.targets[id] or {}
        ui.targetsList:AddLine(id, t.name or id, t.displayName or "")
    end
end

local function refreshSpawnsList()
    ui.spawnsList:Clear()
    for _, s in ipairs(sortedSpawns()) do
        local p = s.pos or {}
        ui.spawnsList:AddLine(
            s.id or "",
            s.class or "",
            s.targetId or "",
            string.format("%d %d %d", tonumber(p.x) or 0, tonumber(p.y) or 0, tonumber(p.z) or 0),
            (s.modelOverride and s.modelOverride ~= "") and "custom" or "default",
            (istable(s.lootOverride) and #s.lootOverride > 0) and "custom" or "default"
        )
    end
end

local function saveTargetFromFields()
    if not selectedTargetId then return end
    local t = adminData.targets[selectedTargetId]
    if not istable(t) then return end

    t.name = ui.t_name:GetValue()
    t.displayName = ui.t_displayName:GetValue()
    t.enabled = ui.t_enabled:GetChecked()
    t.modelOverride = string.Trim(ui.t_modelOverride:GetValue() or "")

    t.startDistance = tonumber(ui.t_startDist:GetValue()) or 120
    t.duration = tonumber(ui.t_duration:GetValue()) or 45
    t.cooldown = tonumber(ui.t_cooldown:GetValue()) or 300

    t.useAbsoluteCenter = ui.t_absCenter:GetChecked()
    t.zoneCenter = vecEntryRead(ui.t_centerX, ui.t_centerY, ui.t_centerZ)
    t.zoneOffset = vecEntryRead(ui.t_offsetX, ui.t_offsetY, ui.t_offsetZ)
    t.zoneMins = vecEntryRead(ui.t_minsX, ui.t_minsY, ui.t_minsZ)
    t.zoneMaxs = vecEntryRead(ui.t_maxsX, ui.t_maxsY, ui.t_maxsZ)

    t.policeTeams = parseCsvTeams(ui.t_policeTeams:GetValue() or "")
end

local function loadTargetToFields(id)
    local t = adminData.targets[id]
    if not istable(t) then return end

    ui.targetHdr:SetText("Target: " .. id)
    ui.t_name:SetValue(t.name or "")
    ui.t_displayName:SetValue(t.displayName or t.name or "")
    ui.t_enabled:SetValue(t.enabled and 1 or 0)
    ui.t_modelOverride:SetValue(t.modelOverride or "")

    ui.t_startDist:SetValue(tostring(t.startDistance or 120))
    ui.t_duration:SetValue(tostring(t.duration or 45))
    ui.t_cooldown:SetValue(tostring(t.cooldown or 300))

    ui.t_absCenter:SetValue(t.useAbsoluteCenter and 1 or 0)
    vecEntrySet(ui.t_centerX, ui.t_centerY, ui.t_centerZ, t.zoneCenter)
    vecEntrySet(ui.t_offsetX, ui.t_offsetY, ui.t_offsetZ, t.zoneOffset)
    vecEntrySet(ui.t_minsX, ui.t_minsY, ui.t_minsZ, t.zoneMins)
    vecEntrySet(ui.t_maxsX, ui.t_maxsY, ui.t_maxsZ, t.zoneMaxs)

    local teams = {}
    for i = 1, #(t.policeTeams or {}) do teams[#teams + 1] = tostring(t.policeTeams[i]) end
    ui.t_policeTeams:SetValue(table.concat(teams, ", "))

    ui.targetLootList:Clear()
    for i = 1, #(t.loot or {}) do
        local r = t.loot[i]
        ui.targetLootList:AddLine(r.id, tostring(r.min), tostring(r.max), tostring(r.chance))
    end
end

local function loadSpawnToFields(spawnId)
    local s = findSpawnById(spawnId)
    if not s then return end

    ui.s_id:SetValue(s.id or "")
    ui.s_class:SetValue(s.class or "")
    ui.s_targetId:SetValue(s.targetId or "")
    ui.s_modelOverride:SetValue(s.modelOverride or "")

    vecEntrySet(ui.s_px, ui.s_py, ui.s_pz, s.pos)
    angEntrySet(ui.s_ap, ui.s_ay, ui.s_ar, s.ang)

    ui.spawnLootList:Clear()
    for i = 1, #(s.lootOverride or {}) do
        local r = s.lootOverride[i]
        ui.spawnLootList:AddLine(r.id, tostring(r.min), tostring(r.max), tostring(r.chance))
    end
end

local function saveSpawnFromFields()
    local id = string.Trim(string.lower(ui.s_id:GetValue() or ""))
    if id == "" then return nil end

    local className = string.Trim(ui.s_class:GetValue() or "")
    local targetId = string.Trim(string.lower(ui.s_targetId:GetValue() or ""))
    if className == "" or targetId == "" then return nil end

    local row, idx = findSpawnById(id)

    local payload = {
        id = id,
        class = className,
        targetId = targetId,
        pos = vecEntryRead(ui.s_px, ui.s_py, ui.s_pz),
        ang = angEntryRead(ui.s_ap, ui.s_ay, ui.s_ar),
        modelOverride = string.Trim(ui.s_modelOverride:GetValue() or ""),
        lootOverride = {}
    }

    for i = 1, ui.spawnLootList:GetLineCount() do
        local line = ui.spawnLootList:GetLine(i)
        if line then
            local lid = string.Trim(line:GetColumnText(1) or "")
            if lid ~= "" then
                payload.lootOverride[#payload.lootOverride + 1] = {
                    id = lid,
                    min = math.max(1, math.floor(tonumber(line:GetColumnText(2)) or 1)),
                    max = math.max(1, math.floor(tonumber(line:GetColumnText(3)) or 1)),
                    chance = math.Clamp(math.floor(tonumber(line:GetColumnText(4)) or 100), 0, 100)
                }
                if payload.lootOverride[#payload.lootOverride].max < payload.lootOverride[#payload.lootOverride].min then
                    payload.lootOverride[#payload.lootOverride].max = payload.lootOverride[#payload.lootOverride].min
                end
            end
        end
    end

    if row and idx then
        adminData.spawns[idx] = payload
    else
        adminData.spawns[#adminData.spawns + 1] = payload
    end

    return payload
end

local function applySettingsFromFields()
    adminData.settings.leaveZoneGrace = tonumber(ui.s_leaveGrace:GetValue()) or 5
    adminData.settings.chatCooldown = tonumber(ui.s_chatCd:GetValue()) or 1
    adminData.settings.policeNotifySound = tostring(ui.s_sound:GetValue() or "buttons/blip1.wav")
end

local function buildAdmin(payload)
    adminData = clone(payload or {})
    ensureAdminData()

    if IsValid(adminFrame) then adminFrame:Remove() end

    adminFrame = vgui.Create("DFrame")
    adminFrame:SetSize(1460, 840)
    adminFrame:Center()
    adminFrame:SetTitle("")
    adminFrame:ShowCloseButton(false)
    adminFrame:MakePopup()
    adminFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(12, 16, 28, 245))
        draw.SimpleText("NEXUS ROBBERY ADMIN (PRO)", "NexusRobTitle", 16, 24, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", adminFrame)
    close:SetPos(adminFrame:GetWide() - 88, 14)
    close:SetSize(72, 30)
    close:SetText("Закрыть")
    close.DoClick = function() adminFrame:Remove() end

    -- Global settings
    local top = vgui.Create("DPanel", adminFrame)
    top:SetPos(14, 58)
    top:SetSize(adminFrame:GetWide() - 28, 64)
    top.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 26, 42, 235))
    end

    newLabel(top, 10, 10, "leaveZoneGrace")
    ui.s_leaveGrace = newEntry(top, 110, 8, 60, adminData.settings.leaveZoneGrace or 5)

    newLabel(top, 178, 10, "chatCooldown")
    ui.s_chatCd = newEntry(top, 264, 8, 60, adminData.settings.chatCooldown or 1)

    newLabel(top, 332, 10, "policeNotifySound", 140)
    ui.s_sound = newEntry(top, 454, 8, 430, adminData.settings.policeNotifySound or "buttons/blip1.wav")

    local saveTop = vgui.Create("DButton", top)
    saveTop:SetPos(top:GetWide() - 290, 8)
    saveTop:SetSize(280, 24)
    saveTop:SetText("Сохранить все + применить спавны")

    -- LEFT: Targets
    local left = vgui.Create("DPanel", adminFrame)
    left:SetPos(14, 130)
    left:SetSize(430, adminFrame:GetTall() - 144)
    left.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 26, 42, 235))
    end

    ui.targetsList = vgui.Create("DListView", left)
    ui.targetsList:SetPos(10, 10)
    ui.targetsList:SetSize(left:GetWide() - 20, 220)
    ui.targetsList:AddColumn("targetId")
    ui.targetsList:AddColumn("name")
    ui.targetsList:AddColumn("displayName")

    local addTarget = vgui.Create("DButton", left)
    addTarget:SetPos(10, 236)
    addTarget:SetSize(left:GetWide() - 20, 24)
    addTarget:SetText("Добавить target")

    local remTarget = vgui.Create("DButton", left)
    remTarget:SetPos(10, 264)
    remTarget:SetSize(left:GetWide() - 20, 24)
    remTarget:SetText("Удалить target")

    ui.targetHdr = newLabel(left, 10, 294, "Target: -", 400)

    newLabel(left, 10, 322, "Name")
    ui.t_name = newEntry(left, 90, 320, 330, "")

    newLabel(left, 10, 350, "3D2D displayName")
    ui.t_displayName = newEntry(left, 120, 348, 300, "")

    newLabel(left, 10, 378, "modelOverride")
    ui.t_modelOverride = newEntry(left, 110, 376, 310, "")

    ui.t_enabled = vgui.Create("DCheckBoxLabel", left)
    ui.t_enabled:SetPos(10, 406)
    ui.t_enabled:SetText("Enabled")
    ui.t_enabled:SetValue(1)
    ui.t_enabled:SizeToContents()

    newLabel(left, 10, 432, "StartDist")
    ui.t_startDist = newEntry(left, 72, 430, 70, "120")
    newLabel(left, 148, 432, "Duration")
    ui.t_duration = newEntry(left, 206, 430, 70, "45")
    newLabel(left, 282, 432, "Cooldown")
    ui.t_cooldown = newEntry(left, 338, 430, 82, "300")

    newLabel(left, 10, 460, "Police Teams csv")
    ui.t_policeTeams = newEntry(left, 120, 458, 300, "2,3,4")

    ui.t_absCenter = vgui.Create("DCheckBoxLabel", left)
    ui.t_absCenter:SetPos(10, 486)
    ui.t_absCenter:SetText("Absolute Center")
    ui.t_absCenter:SetValue(0)
    ui.t_absCenter:SizeToContents()

    local btnCenterMe = vgui.Create("DButton", left)
    btnCenterMe:SetPos(154, 484)
    btnCenterMe:SetSize(266, 24)
    btnCenterMe:SetText("Center = моя позиция")

    newLabel(left, 10, 514, "Center XYZ")
    ui.t_centerX = newEntry(left, 78, 512, 106, "0")
    ui.t_centerY = newEntry(left, 188, 512, 106, "0")
    ui.t_centerZ = newEntry(left, 298, 512, 122, "0")

    newLabel(left, 10, 542, "Offset XYZ")
    ui.t_offsetX = newEntry(left, 78, 540, 106, "0")
    ui.t_offsetY = newEntry(left, 188, 540, 106, "0")
    ui.t_offsetZ = newEntry(left, 298, 540, 122, "0")

    newLabel(left, 10, 570, "Mins XYZ")
    ui.t_minsX = newEntry(left, 78, 568, 106, "-140")
    ui.t_minsY = newEntry(left, 188, 568, 106, "-140")
    ui.t_minsZ = newEntry(left, 298, 568, 122, "-10")

    newLabel(left, 10, 598, "Maxs XYZ")
    ui.t_maxsX = newEntry(left, 78, 596, 106, "140")
    ui.t_maxsY = newEntry(left, 188, 596, 106, "140")
    ui.t_maxsZ = newEntry(left, 298, 596, 122, "150")

    -- MIDDLE: Target loot
    local mid = vgui.Create("DPanel", adminFrame)
    mid:SetPos(452, 130)
    mid:SetSize(460, adminFrame:GetTall() - 144)
    mid.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 24, 38, 235))
        draw.SimpleText("Target Loot (default)", "NexusRobBody", 12, 14, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    ui.targetLootList = vgui.Create("DListView", mid)
    ui.targetLootList:SetPos(10, 34)
    ui.targetLootList:SetSize(mid:GetWide() - 20, 500)
    ui.targetLootList:AddColumn("id")
    ui.targetLootList:AddColumn("min")
    ui.targetLootList:AddColumn("max")
    ui.targetLootList:AddColumn("chance")

    newLabel(mid, 10, 542, "id")
    ui.tl_id = newEntry(mid, 34, 540, 170, "")

    newLabel(mid, 210, 542, "min")
    ui.tl_min = newEntry(mid, 236, 540, 52, "1")

    newLabel(mid, 294, 542, "max")
    ui.tl_max = newEntry(mid, 320, 540, 52, "1")

    newLabel(mid, 378, 542, "chance")
    ui.tl_chance = newEntry(mid, 424, 540, 30, "100")

    local addTL = vgui.Create("DButton", mid)
    addTL:SetPos(10, 572)
    addTL:SetSize(145, 24)
    addTL:SetText("Добавить")

    local updTL = vgui.Create("DButton", mid)
    updTL:SetPos(160, 572)
    updTL:SetSize(145, 24)
    updTL:SetText("Обновить")

    local remTL = vgui.Create("DButton", mid)
    remTL:SetPos(310, 572)
    remTL:SetSize(145, 24)
    remTL:SetText("Удалить")

    -- RIGHT: Spawn manager + spawn override loot
    local right = vgui.Create("DPanel", adminFrame)
    right:SetPos(920, 130)
    right:SetSize(adminFrame:GetWide() - 934, adminFrame:GetTall() - 144)
    right.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 26, 42, 235))
        draw.SimpleText("Spawns Manager + Overrides", "NexusRobBody", 12, 14, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    ui.spawnsList = vgui.Create("DListView", right)
    ui.spawnsList:SetPos(10, 34)
    ui.spawnsList:SetSize(right:GetWide() - 20, 220)
    ui.spawnsList:AddColumn("id")
    ui.spawnsList:AddColumn("class")
    ui.spawnsList:AddColumn("targetId")
    ui.spawnsList:AddColumn("model")
    ui.spawnsList:AddColumn("loot")

    newLabel(right, 10, 262, "spawn id")
    ui.s_id = newEntry(right, 72, 260, 170, "")

    newLabel(right, 10, 290, "class")
    ui.s_class = newEntry(right, 72, 288, 170, "nexus_inv_lootbin")

    newLabel(right, 10, 318, "targetId")
    ui.s_targetId = newEntry(right, 72, 316, 170, "")

    newLabel(right, 10, 346, "spawn modelOverride")
    ui.s_modelOverride = newEntry(right, 138, 344, right:GetWide() - 148, "")

    local setPos = vgui.Create("DButton", right)
    setPos:SetPos(250, 260)
    setPos:SetSize(right:GetWide() - 260, 24)
    setPos:SetText("Позиция/угол = игрок")

    newLabel(right, 10, 374, "pos xyz")
    ui.s_px = newEntry(right, 72, 372, 70, "0")
    ui.s_py = newEntry(right, 146, 372, 70, "0")
    ui.s_pz = newEntry(right, 220, 372, 70, "0")

    newLabel(right, 10, 402, "ang pyr")
    ui.s_ap = newEntry(right, 72, 400, 70, "0")
    ui.s_ay = newEntry(right, 146, 400, 70, "0")
    ui.s_ar = newEntry(right, 220, 400, 70, "0")

    local addSpawn = vgui.Create("DButton", right)
    addSpawn:SetPos(10, 432)
    addSpawn:SetSize(right:GetWide() - 20, 24)
    addSpawn:SetText("Добавить/обновить spawn")

    local remSpawn = vgui.Create("DButton", right)
    remSpawn:SetPos(10, 460)
    remSpawn:SetSize(right:GetWide() - 20, 24)
    remSpawn:SetText("Удалить выбранный spawn")

    newLabel(right, 10, 494, "Spawn Loot Override (если пусто -> target loot)")

    ui.spawnLootList = vgui.Create("DListView", right)
    ui.spawnLootList:SetPos(10, 514)
    ui.spawnLootList:SetSize(right:GetWide() - 20, 170)
    ui.spawnLootList:AddColumn("id")
    ui.spawnLootList:AddColumn("min")
    ui.spawnLootList:AddColumn("max")
    ui.spawnLootList:AddColumn("chance")

    newLabel(right, 10, 692, "id")
    ui.sl_id = newEntry(right, 34, 690, 150, "")

    newLabel(right, 190, 692, "min")
    ui.sl_min = newEntry(right, 216, 690, 50, "1")

    newLabel(right, 272, 692, "max")
    ui.sl_max = newEntry(right, 298, 690, 50, "1")

    newLabel(right, 354, 692, "chance")
    ui.sl_chance = newEntry(right, 402, 690, 30, "100")

    local addSL = vgui.Create("DButton", right)
    addSL:SetPos(10, 720)
    addSL:SetSize(100, 24)
    addSL:SetText("Добавить")

    local updSL = vgui.Create("DButton", right)
    updSL:SetPos(116, 720)
    updSL:SetSize(100, 24)
    updSL:SetText("Обновить")

    local remSL = vgui.Create("DButton", right)
    remSL:SetPos(222, 720)
    remSL:SetSize(100, 24)
    remSL:SetText("Удалить")

    local clearSL = vgui.Create("DButton", right)
    clearSL:SetPos(328, 720)
    clearSL:SetSize(right:GetWide() - 338, 24)
    clearSL:SetText("Очистить override")

    local saveBottom = vgui.Create("DButton", right)
    saveBottom:SetPos(10, 748)
    saveBottom:SetSize(right:GetWide() - 20, 28)
    saveBottom:SetText("Сохранить все + применить")

    -- handlers
    ui.targetsList.OnRowSelected = function(_, _, line)
        saveTargetFromFields()
        selectedTargetId = line:GetColumnText(1)
        loadTargetToFields(selectedTargetId)
        ui.s_targetId:SetValue(selectedTargetId or "")
    end

    ui.targetLootList.OnRowSelected = function(_, _, line)
        ui.tl_id:SetValue(line:GetColumnText(1))
        ui.tl_min:SetValue(line:GetColumnText(2))
        ui.tl_max:SetValue(line:GetColumnText(3))
        ui.tl_chance:SetValue(line:GetColumnText(4))
    end

    ui.spawnsList.OnRowSelected = function(_, _, line)
        selectedSpawnId = line:GetColumnText(1)
        loadSpawnToFields(selectedSpawnId)
    end

    ui.spawnLootList.OnRowSelected = function(_, _, line)
        ui.sl_id:SetValue(line:GetColumnText(1))
        ui.sl_min:SetValue(line:GetColumnText(2))
        ui.sl_max:SetValue(line:GetColumnText(3))
        ui.sl_chance:SetValue(line:GetColumnText(4))
    end

    addTarget.DoClick = function()
        Derma_StringRequest("New target", "Введите target id", "", function(id)
            id = string.Trim(string.lower(id or ""))
            if id == "" then return end
            if adminData.targets[id] then return end

            adminData.targets[id] = {
                name = id,
                displayName = string.upper(id),
                enabled = true,
                modelOverride = "",
                startDistance = 120,
                duration = 45,
                cooldown = 300,
                useAbsoluteCenter = false,
                zoneCenter = { x = 0, y = 0, z = 0 },
                zoneOffset = { x = 0, y = 0, z = 0 },
                zoneMins = { x = -140, y = -140, z = -10 },
                zoneMaxs = { x = 140, y = 140, z = 150 },
                policeTeams = { 2, 3, 4 },
                loot = {}
            }

            refreshTargetsList()
        end)
    end

    remTarget.DoClick = function()
        if not selectedTargetId then return end
        adminData.targets[selectedTargetId] = nil

        local kept = {}
        for i = 1, #adminData.spawns do
            if adminData.spawns[i].targetId ~= selectedTargetId then
                kept[#kept + 1] = adminData.spawns[i]
            end
        end
        adminData.spawns = kept

        selectedTargetId = nil
        selectedSpawnId = nil
        refreshTargetsList()
        refreshSpawnsList()
        ui.targetLootList:Clear()
    end

    btnCenterMe.DoClick = function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local p = lp:GetPos()
        ui.t_centerX:SetValue(tostring(math.floor(p.x)))
        ui.t_centerY:SetValue(tostring(math.floor(p.y)))
        ui.t_centerZ:SetValue(tostring(math.floor(p.z)))
    end

    addTL.DoClick = function()
        if not selectedTargetId then return end
        saveTargetFromFields()

        local t = adminData.targets[selectedTargetId]
        t.loot = t.loot or {}

        local id = string.Trim(ui.tl_id:GetValue() or "")
        if id == "" then return end

        local row = {
            id = id,
            min = math.max(1, math.floor(tonumber(ui.tl_min:GetValue()) or 1)),
            max = math.max(1, math.floor(tonumber(ui.tl_max:GetValue()) or 1)),
            chance = math.Clamp(math.floor(tonumber(ui.tl_chance:GetValue()) or 100), 0, 100)
        }
        if row.max < row.min then row.max = row.min end

        t.loot[#t.loot + 1] = row
        loadTargetToFields(selectedTargetId)
    end

    updTL.DoClick = function()
        if not selectedTargetId then return end
        local idx = ui.targetLootList:GetSelectedLine()
        if not idx then return end
        saveTargetFromFields()

        local t = adminData.targets[selectedTargetId]
        local row = t.loot and t.loot[idx]
        if not row then return end

        local id = string.Trim(ui.tl_id:GetValue() or "")
        if id == "" then return end

        row.id = id
        row.min = math.max(1, math.floor(tonumber(ui.tl_min:GetValue()) or 1))
        row.max = math.max(row.min, math.floor(tonumber(ui.tl_max:GetValue()) or row.min))
        row.chance = math.Clamp(math.floor(tonumber(ui.tl_chance:GetValue()) or 100), 0, 100)

        loadTargetToFields(selectedTargetId)
    end

    remTL.DoClick = function()
        if not selectedTargetId then return end
        local idx = ui.targetLootList:GetSelectedLine()
        if not idx then return end
        saveTargetFromFields()

        local t = adminData.targets[selectedTargetId]
        if not t or not t.loot then return end
        table.remove(t.loot, idx)
        loadTargetToFields(selectedTargetId)
    end

    setPos.DoClick = function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local p = lp:GetPos()
        local a = lp:EyeAngles()

        ui.s_px:SetValue(tostring(math.floor(p.x)))
        ui.s_py:SetValue(tostring(math.floor(p.y)))
        ui.s_pz:SetValue(tostring(math.floor(p.z)))

        ui.s_ap:SetValue("0")
        ui.s_ay:SetValue(tostring(math.floor(a.y)))
        ui.s_ar:SetValue("0")
    end

    addSpawn.DoClick = function()
        saveTargetFromFields()

        local row = saveSpawnFromFields()
        if not row then return end

        selectedSpawnId = row.id
        refreshSpawnsList()
    end

    remSpawn.DoClick = function()
        if not selectedSpawnId then return end
        local _, idx = findSpawnById(selectedSpawnId)
        if not idx then return end
        table.remove(adminData.spawns, idx)
        selectedSpawnId = nil
        refreshSpawnsList()
        ui.spawnLootList:Clear()
    end

    addSL.DoClick = function()
        if not selectedSpawnId then return end
        local row = findSpawnById(selectedSpawnId)
        if not row then return end

        row.lootOverride = row.lootOverride or {}

        local id = string.Trim(ui.sl_id:GetValue() or "")
        if id == "" then return end
        local r = {
            id = id,
            min = math.max(1, math.floor(tonumber(ui.sl_min:GetValue()) or 1)),
            max = math.max(1, math.floor(tonumber(ui.sl_max:GetValue()) or 1)),
            chance = math.Clamp(math.floor(tonumber(ui.sl_chance:GetValue()) or 100), 0, 100)
        }
        if r.max < r.min then r.max = r.min end

        row.lootOverride[#row.lootOverride + 1] = r
        loadSpawnToFields(selectedSpawnId)
        refreshSpawnsList()
    end

    updSL.DoClick = function()
        if not selectedSpawnId then return end
        local row = findSpawnById(selectedSpawnId)
        if not row then return end

        local idx = ui.spawnLootList:GetSelectedLine()
        if not idx then return end
        row.lootOverride = row.lootOverride or {}
        local r = row.lootOverride[idx]
        if not r then return end

        local id = string.Trim(ui.sl_id:GetValue() or "")
        if id == "" then return end

        r.id = id
        r.min = math.max(1, math.floor(tonumber(ui.sl_min:GetValue()) or 1))
        r.max = math.max(r.min, math.floor(tonumber(ui.sl_max:GetValue()) or r.min))
        r.chance = math.Clamp(math.floor(tonumber(ui.sl_chance:GetValue()) or 100), 0, 100)

        loadSpawnToFields(selectedSpawnId)
        refreshSpawnsList()
    end

    remSL.DoClick = function()
        if not selectedSpawnId then return end
        local row = findSpawnById(selectedSpawnId)
        if not row then return end

        local idx = ui.spawnLootList:GetSelectedLine()
        if not idx then return end

        row.lootOverride = row.lootOverride or {}
        table.remove(row.lootOverride, idx)
        loadSpawnToFields(selectedSpawnId)
        refreshSpawnsList()
    end

    clearSL.DoClick = function()
        if not selectedSpawnId then return end
        local row = findSpawnById(selectedSpawnId)
        if not row then return end
        row.lootOverride = {}
        loadSpawnToFields(selectedSpawnId)
        refreshSpawnsList()
    end

    local function saveAll()
        saveTargetFromFields()
        saveSpawnFromFields()
        applySettingsFromFields()

        net.Start("nexus_robbery_admin_save")
        net.WriteString(util.TableToJSON(adminData, false) or "{}")
        net.SendToServer()
    end

    saveTop.DoClick = saveAll
    saveBottom.DoClick = saveAll

    refreshTargetsList()
    refreshSpawnsList()

    local ids = sortedTargetIds()
    if #ids > 0 then
        selectedTargetId = ids[1]
        loadTargetToFields(selectedTargetId)
        ui.s_targetId:SetValue(selectedTargetId)
    end
end

net.Receive("nexus_robbery_admin_open", function()
    local raw = net.ReadString()
    local payload = util.JSONToTable(raw or "") or {}
    buildAdmin(payload)
end)