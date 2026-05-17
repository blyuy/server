if not CLIENT then return end

XPDRP = XPDRP or {}
XPDRP.Config = XPDRP.Config or {}
XPDRP.Config.Colors = XPDRP.Config.Colors or {
    Accent = Color(109, 191, 255),
    AccentSoft = Color(109, 191, 255, 45),
    BgA = Color(11, 14, 24, 238),
    BgB = Color(21, 28, 44, 235),
    Line = Color(255, 255, 255, 24),
    Good = Color(106, 228, 152),
    Warn = Color(255, 189, 96)
}

function XPDRP.RunDarkRPCommand(cmd)
    if not cmd or cmd == "" then return end
    LocalPlayer():ConCommand("say /" .. cmd)
end

function XPDRP.FormatMoney(value)
    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(tonumber(value) or 0)
    end

    return "$" .. tostring(math.floor(tonumber(value) or 0))
end

function XPDRP.SafeText(value)
    if value == nil then return "-" end
    return tostring(value)
end

function XPDRP.GetLookDoor()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local trace = ply:GetEyeTrace()
    if not trace or not IsValid(trace.Entity) then return nil end

    local ent = trace.Entity
    if ent.isKeysOwnable and ent:isKeysOwnable() then
        return ent
    end

    if ent.isDoor and ent:isDoor() then
        return ent
    end

    local class = ent:GetClass()
    if class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating" then
        return ent
    end

    return nil
end

function XPDRP.GetDoorOwnerName(door)
    if not IsValid(door) then return "Нет двери" end

    if door.getDoorOwner then
        local owner = door:getDoorOwner()
        if IsValid(owner) then
            return owner:Nick()
        end
    end

    return "Не куплена"
end

function XPDRP.GetModelPath(value)
    if istable(value) then
        for _, mdl in ipairs(value) do
            if isstring(mdl) and mdl ~= "" then
                return mdl
            end
        end
        return "models/player/kleiner.mdl"
    end

    if isstring(value) and value ~= "" then
        return value
    end

    return "models/player/kleiner.mdl"
end

function XPDRP.PaintSoftGradient(w, h)
    local colors = XPDRP.Config.Colors
    draw.RoundedBox(8, 0, 0, w, h, colors.BgA)
    surface.SetDrawColor(colors.BgB)
    surface.DrawRect(0, h * 0.35, w, h)
    surface.SetDrawColor(colors.Line)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

function XPDRP.PaintGlass(w, h, radius, accent)
    local colors = XPDRP.Config.Colors
    radius = radius or 8
    accent = accent or colors.Accent

    draw.RoundedBox(radius, 0, 0, w, h, Color(9, 13, 22, 215))
    draw.RoundedBox(radius, 0, 0, w, h * 0.42, Color(22, 30, 46, 170))

    local pulse = 35 + math.abs(math.sin(RealTime() * 1.8)) * 35
    surface.SetDrawColor(accent.r, accent.g, accent.b, pulse)
    surface.DrawRect(1, 1, w - 2, 2)

    surface.SetDrawColor(255, 255, 255, 18)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

function XPDRP.PaintTileButton(self, w, h, colorMain)
    local a = self:IsDown() and 105 or (self:IsHovered() and 82 or 56)
    draw.RoundedBox(10, 0, 0, w, h, Color(colorMain.r, colorMain.g, colorMain.b, a))
    surface.SetDrawColor(255, 255, 255, self:IsHovered() and 35 or 18)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

