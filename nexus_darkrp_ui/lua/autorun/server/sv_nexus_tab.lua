if CLIENT then return end

AddCSLuaFile("autorun/sh_nexus_ui_config.lua")
AddCSLuaFile("autorun/client/cl_nexus_tab.lua")

util.AddNetworkString("nexus_tab_teleport")

local teleportCooldown = {}

local function cfgValue(key, fallback)
    local cfg = NEXUS_UI_CONFIG and NEXUS_UI_CONFIG.Tab
    if not cfg then return fallback end

    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

local function quoteArg(text)
    local value = tostring(text or "")
    value = string.gsub(value, "\"", "")
    return "\"" .. value .. "\""
end

local function isActionEnabled(actionId)
    local cfg = NEXUS_UI_CONFIG and NEXUS_UI_CONFIG.Tab
    if not cfg or not istable(cfg.actions) then return true end

    for _, action in ipairs(cfg.actions) do
        if action.id == actionId then
            return action.enabled ~= false
        end
    end

    return false
end

net.Receive("nexus_tab_teleport", function(_, ply)
    if not IsValid(ply) then return end
    if not isActionEnabled("teleport_sam") then return end

    local adminOnly = cfgValue("adminOnlyTeleport", true)
    if adminOnly and not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:ChatPrint("[NEXUS] Недостаточно прав для teleport")
        return
    end

    local cooldown = cfgValue("teleportCooldown", 0.4)
    local nextUse = teleportCooldown[ply] or 0
    if nextUse > CurTime() then return end
    teleportCooldown[ply] = CurTime() + cooldown

    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then
        ply:ChatPrint("[NEXUS] Игрок не найден")
        return
    end

    local samCommand = tostring(cfgValue("samCommand", "sam teleport"))
    local samBase = string.Explode(" ", samCommand)[1] or "sam"
    local hasSam = concommand.GetTable()[samBase] ~= nil

    if hasSam then
        local cmd = samCommand .. " " .. quoteArg(ply:Nick()) .. " " .. quoteArg(target:Nick()) .. "\n"
        game.ConsoleCommand(cmd)
        return
    end

    if not cfgValue("fallbackTeleportIfSamMissing", true) then
        ply:ChatPrint("[NEXUS] SAM команда не найдена")
        return
    end

    local near = target:GetPos() + target:GetForward() * -56
    ply:SetPos(near)
    ply:ChatPrint("[NEXUS] SAM не найден, применен встроенный teleport")
end)

hook.Add("PlayerDisconnected", "NexusTabTeleportCleanup", function(ply)
    teleportCooldown[ply] = nil
end)