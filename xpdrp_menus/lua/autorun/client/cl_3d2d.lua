if not CLIENT then return end

XPDRP = XPDRP or {}

local cfg = (XPDRP.Config and XPDRP.Config.World3D2D) or {
    Enabled = true,
    DoorDistance = 650,
    PlayerDistance = 520,
    RefreshRate = 0.35,
    Scale = 0.05,
    DoorScale = 0.05,
    PlayerScale = 0.045
}

surface.CreateFont("XPDRP_3D2D_Title", {
    font = "Trebuchet MS",
    size = 32,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("XPDRP_3D2D_Sub", {
    font = "Trebuchet MS",
    size = 22,
    weight = 700,
    antialias = true,
    extended = true
})

local doorCache = {}
local nextRefresh = 0

local cBg = Color(10, 14, 22, 236)
local cBorder = Color(255, 255, 255, 28)
local cAccent = Color(82, 162, 255, 160)
local cGood = Color(112, 214, 136, 170)
local cBad = Color(235, 120, 120, 170)
local cText = Color(238, 244, 255)
local cDim = Color(174, 191, 214)

local function drawTextShadow(text, font, x, y, color, ax, ay)
    draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 220), ax, ay)
    draw.SimpleText(text, font, x, y, color, ax, ay)
end

local function isLookedAt(eyePos, eyeForward, targetPos, maxDist, dotLimit)
    local to = targetPos - eyePos
    if to:LengthSqr() > (maxDist * maxDist) then return false end
    to:Normalize()
    return eyeForward:Dot(to) >= dotLimit
end

local function hasLineOfSight(viewer, targetEnt, startPos, endPos)
    local tr = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = { viewer, targetEnt },
        mask = MASK_VISIBLE_AND_NPCS
    })

    return not tr.Hit
end

local function isDoorEntity(ent)
    if not IsValid(ent) then return false end

    if ent.isKeysOwnable and ent:isKeysOwnable() then return true end
    if ent.isDoor and ent:isDoor() then return true end

    local class = ent:GetClass()
    if class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating" then
        return true
    end

    return string.find(class, "door", 1, true) ~= nil
end

local function getDoorLines(door)
    local title = "Дверь"
    local owner = "Не куплена"
    local status = "Свободна"

    if door.getKeysTitle then
        local t = door:getKeysTitle()
        if isstring(t) and t ~= "" then
            title = t
        end
    end

    if door.getDoorOwner then
        local ownerPly = door:getDoorOwner()
        if IsValid(ownerPly) then
            owner = "Владелец: " .. ownerPly:Nick()
            status = "Куплена"
        end
    end

    if door.getKeysNonOwnable and door:getKeysNonOwnable() then
        status = "Нельзя купить"
    elseif door.isKeysOwned and door:isKeysOwned() then
        status = "Куплена"
    end

    return title, owner, status
end

local function getDoorAccent(status)
    if status == "Свободна" then return cGood end
    if status == "Нельзя купить" then return cBad end
    return cAccent
end

local function buildDoorSides(door)
    local mins, maxs = door:OBBMins(), door:OBBMaxs()
    local extX, extY, extZ = (maxs.x - mins.x), (maxs.y - mins.y), (maxs.z - mins.z)

    local center = (mins + maxs) * 0.5
    -- Keep the panel on the vertical center of the door surface.
    local z = center.z
    local eps = 1.2

    local long = math.max(extX, extY)
    local panelW = math.Clamp(long * 12, 280, 620)
    local panelH = 106

    local isThinX = extX < extY
    if isThinX then
        local offset = extX * 0.5 + eps
        local posA = door:LocalToWorld(Vector(center.x + offset, center.y, z))
        local posB = door:LocalToWorld(Vector(center.x - offset, center.y, z))
        local angA = door:LocalToWorldAngles(Angle(0, 90, 90))
        local angB = door:LocalToWorldAngles(Angle(0, -90, 90))
        return {
            { pos = posA, ang = angA, w = panelW, h = panelH },
            { pos = posB, ang = angB, w = panelW, h = panelH }
        }
    end

    local offset = extY * 0.5 + eps
    local posA = door:LocalToWorld(Vector(center.x, center.y + offset, z))
    local posB = door:LocalToWorld(Vector(center.x, center.y - offset, z))
    local angA = door:LocalToWorldAngles(Angle(0, 0, 90))
    local angB = door:LocalToWorldAngles(Angle(0, 180, 90))
    return {
        { pos = posA, ang = angA, w = panelW, h = panelH },
        { pos = posB, ang = angB, w = panelW, h = panelH }
    }
end

local function drawDoorPanel(side, lines, accent)
    local w, h = side.w, side.h
    local t1 = tostring(lines[1] or "Дверь")
    local t2 = tostring(lines[2] or "Не куплена")
    local t3 = tostring(lines[3] or "Свободна")

    cam.Start3D2D(side.pos, side.ang, cfg.DoorScale or cfg.Scale or 0.05)
        draw.RoundedBox(0, -w * 0.5, -h * 0.5, w, h, cBg)
        draw.RoundedBox(0, -w * 0.5, -h * 0.5, w, 4, accent)
        surface.SetDrawColor(cBorder)
        surface.DrawOutlinedRect(-w * 0.5, -h * 0.5, w, h, 1)

        drawTextShadow(t1, "XPDRP_3D2D_Title", 0, -22, cText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        drawTextShadow(t2, "XPDRP_3D2D_Sub", 0, 5, cDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        drawTextShadow("Статус: " .. t3, "XPDRP_3D2D_Sub", 0, 30, cDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

local function drawPlayerPanel(target, eyePos)
    local mins, maxs = target:OBBMins(), target:OBBMaxs()
    local pos = target:GetPos() + Vector(0, 0, maxs.z + 4)
    local ang = (eyePos - pos):Angle()
    ang = Angle(0, ang.y - 90, 90)

    local w, h = 460, 102
    local name = tostring(target:Nick() or "Игрок")
    local job = tostring((target.getDarkRPVar and target:getDarkRPVar("job")) or team.GetName(target:Team()) or "Неизвестно")

    cam.Start3D2D(pos, ang, cfg.PlayerScale or cfg.Scale or 0.045)
        draw.RoundedBox(0, -w * 0.5, -h * 0.5, w, h, cBg)
        draw.RoundedBox(0, -w * 0.5, -h * 0.5, w, 4, cAccent)
        surface.SetDrawColor(cBorder)
        surface.DrawOutlinedRect(-w * 0.5, -h * 0.5, w, h, 1)

        surface.SetAlphaMultiplier(1)
        draw.SimpleTextOutlined(name, "XPDRP_3D2D_Title", 0, -14, cText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 235))
        draw.SimpleTextOutlined(job, "XPDRP_3D2D_Sub", 0, 18, cDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 235))
    cam.End3D2D()
end

local function refreshCache()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    doorCache = {}

    local lpPos = lp:GetPos()
    local doorDist = cfg.DoorDistance or 650

    local near = ents.FindInSphere(lpPos, doorDist)
    for i = 1, #near do
        local ent = near[i]
        if isDoorEntity(ent) then
            local title, owner, status = getDoorLines(ent)
            doorCache[#doorCache + 1] = {
                ent = ent,
                lines = { title, owner, status },
                accent = getDoorAccent(status),
                sides = buildDoorSides(ent)
            }
        end
    end

end

hook.Add("Think", "XPDRP.3D2D.Refresh", function()
    if not cfg.Enabled then return end
    if CurTime() < nextRefresh then return end

    nextRefresh = CurTime() + (cfg.RefreshRate or 0.35)
    refreshCache()
end)

hook.Add("PostDrawTranslucentRenderables", "XPDRP.3D2D.Draw", function(_, isSkybox)
    if isSkybox or not cfg.Enabled then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local eyePos = lp:EyePos()
    local eyeForward = EyeAngles():Forward()
    local tr = lp:GetEyeTrace()
    local lookedEnt = IsValid(tr.Entity) and tr.Entity or nil

    local doorMaxDist = cfg.DoorDistance or 650
    for i = 1, #doorCache do
        local data = doorCache[i]
        local door = data.ent
        if not IsValid(door) then continue end

        local doorCenter = door:WorldSpaceCenter()
        local looked = (lookedEnt == door) or isLookedAt(eyePos, eyeForward, doorCenter, doorMaxDist, 0.55)
        if not looked then continue end
        if not hasLineOfSight(lp, door, eyePos, doorCenter) then continue end

        drawDoorPanel(data.sides[1], data.lines, data.accent)
        drawDoorPanel(data.sides[2], data.lines, data.accent)
    end

    local playerMaxDist = cfg.PlayerDistance or 520
    local players = player.GetAll()
    for i = 1, #players do
        local target = players[i]
        if not IsValid(target) or not target:Alive() then continue end
        if target == lp then continue end

        local headPos = target:EyePos()
        local looked = (lookedEnt == target) or isLookedAt(eyePos, eyeForward, headPos, playerMaxDist, 0.4)
        if not looked then continue end

        drawPlayerPanel(target, eyePos)
    end
end)
