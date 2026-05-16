if CLIENT then return end

AddCSLuaFile("autorun/sh_nexus_plus_config.lua")
AddCSLuaFile("autorun/client/cl_nexus_plus_f4.lua")
AddCSLuaFile("autorun/client/cl_nexus_plus_cmenu.lua")
AddCSLuaFile("autorun/client/cl_nexus_plus_door.lua")
AddCSLuaFile("autorun/client/cl_nexus_plus_hud.lua")
AddCSLuaFile("autorun/client/cl_nexus_plus_esc.lua")
AddCSLuaFile("autorun/client/cl_nexus_plus_chat.lua")

util.AddNetworkString("nexus_plus_door_request")
util.AddNetworkString("nexus_plus_door_state")
util.AddNetworkString("nexus_plus_door_admin")
util.AddNetworkString("nexus_plus_door_action")

local function cfgValue(group, key, fallback)
    local cfg = NEXUS_PLUS_CONFIG and NEXUS_PLUS_CONFIG[group]
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

local function getDoorFromTrace(ply)
    local tr = ply:GetEyeTrace()
    if not tr or not IsValid(tr.Entity) then return nil end

    local ent = tr.Entity
    if not isDoor(ent) then return nil end

    local maxDist = cfgValue("General", "maxUseDistance", 140)
    if ply:GetPos():Distance(ent:GetPos()) > maxDist then return nil end

    return ent
end

local function getOwnerNames(ent)
    local names = {}

    if ent.isKeysOwnedBy then
        for _, ply in ipairs(player.GetAll()) do
            if ent:isKeysOwnedBy(ply) then
                names[#names + 1] = ply:Nick()
            end
        end
    end

    return table.concat(names, ", ")
end

local ADMIN_ACTIONS = {
    unlock = function(ent)
        ent:Fire("unlock", "", 0)
    end,
    lock = function(ent)
        ent:Fire("lock", "", 0)
    end,
    open = function(ent)
        ent:Fire("open", "", 0)
    end,
    close = function(ent)
        ent:Fire("close", "", 0)
    end,
    set_ownable = function(ent)
        if ent.setKeysOwnable then
            ent:setKeysOwnable(true)
            return
        end

        if ent.setKeysNonOwnable then
            ent:setKeysNonOwnable(false)
        end
    end,
    set_unownable = function(ent)
        if ent.setKeysOwnable then
            ent:setKeysOwnable(false)
            return
        end

        if ent.setKeysNonOwnable then
            ent:setKeysNonOwnable(true)
        end
    end,
    set_group = function(ent, groupName)
        if not isstring(groupName) or groupName == "" then return false end

        if ent.setKeysDoorGroup then
            ent:setKeysDoorGroup(groupName)
            return true
        end

        if ent.setDoorGroup then
            ent:setDoorGroup(groupName)
            return true
        end

        return false
    end
}

local function quote(text)
    local value = tostring(text or "")
    value = string.gsub(value, "\"", "")
    return "\"" .. value .. "\""
end

net.Receive("nexus_plus_door_request", function(_, ply)
    local ent = getDoorFromTrace(ply)

    local valid = IsValid(ent)
    local ownable = false
    local owned = false
    local isOwner = false
    local title = ""
    local owners = ""

    if valid then
        ownable = ent.isKeysOwnable and ent:isKeysOwnable() or true
        owned = ent.isKeysOwned and ent:isKeysOwned() or false
        isOwner = ent.isKeysOwnedBy and ent:isKeysOwnedBy(ply) or false
        title = ent.getDoorData and (ent:getDoorData().title or "") or ""
        owners = getOwnerNames(ent)
    end

    net.Start("nexus_plus_door_state")
    net.WriteBool(valid)
    net.WriteBool(ownable)
    net.WriteBool(owned)
    net.WriteBool(isOwner)
    net.WriteBool(ply:IsSuperAdmin())
    net.WriteString(title)
    net.WriteString(owners)
    net.Send(ply)
end)

net.Receive("nexus_plus_door_action", function(_, ply)
    if not IsValid(ply) then return end

    local actionId = net.ReadString()
    local payload = net.ReadString()

    local ent = getDoorFromTrace(ply)
    if not IsValid(ent) then return end

    if actionId == "buy" then
        if ent.keysOwn then
            ent:keysOwn(ply)
            return
        end

        local cmd = tostring(cfgValue("Door", "buyDoorCommand", "/buydoor"))
        ply:ConCommand("say " .. cmd)
        return
    end

    if actionId == "sell" then
        if ent.keysUnOwn then
            ent:keysUnOwn(ply)
            return
        end

        local cmd = tostring(cfgValue("Door", "sellDoorCommand", "/selldoor"))
        ply:ConCommand("say " .. cmd)
        return
    end

    if actionId == "title" then
        local title = string.Trim(payload or "")
        if title == "" then return end

        local maxLen = tonumber(cfgValue("Door", "maxTitleLength", 48)) or 48
        title = string.sub(title, 1, math.max(1, maxLen))

        if ent.setKeysTitle then
            ent:setKeysTitle(title)
            return
        end

        if ent.getDoorData and ent.setDoorData then
            local data = ent:getDoorData() or {}
            data.title = title
            ent:setDoorData(data)
            return
        end

        local cmd = tostring(cfgValue("Door", "titleCommand", "/title"))
        ply:ConCommand("say " .. cmd .. " " .. quote(title))
    end
end)

net.Receive("nexus_plus_door_admin", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local actionId = net.ReadString()
    local action = ADMIN_ACTIONS[actionId]
    if not action then return end

    local groupName = ""
    if actionId == "set_group" then
        groupName = string.Trim(net.ReadString() or "")
        if groupName == "" then return end
    end

    local ent = getDoorFromTrace(ply)
    if not IsValid(ent) then return end

    local ok = action(ent, groupName)
    if actionId ~= "set_group" or ok then return end

    -- Fallback to chat command on builds where direct method is unavailable.
    local chatCommand = tostring(cfgValue("Door", "doorGroupChatCommand", "/setdoorgroup"))
    ply:ConCommand("say " .. chatCommand .. " " .. quote(groupName))
end)