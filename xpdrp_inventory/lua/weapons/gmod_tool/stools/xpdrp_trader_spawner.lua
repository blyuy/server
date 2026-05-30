TOOL.Category = "XPDRP"
TOOL.Name = "Trader Spawner"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["trader_id"] = "bunker_master"
TOOL.ClientConVar["model"] = "models/Humans/Group01/male_07.mdl"

if CLIENT then
    language.Add("tool.xpdrp_trader_spawner.name", "XPDRP Trader Spawner")
    language.Add("tool.xpdrp_trader_spawner.desc", "Spawn and save trader NPC points")
    language.Add("tool.xpdrp_trader_spawner.0", "LMB: Spawn+save | RMB: Remove nearest save point | Reload: Reload all")
end

local function hasAccess(ply)
    local cfg = XPDRP and XPDRP.Inv and XPDRP.Inv.Config
    if not cfg then return false end
    return cfg.AdminGroups[ply:GetUserGroup()] == true
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not hasAccess(ply) then return false end
    if not trace.Hit then return false end

    local traderId = self:GetClientInfo("trader_id")
    local model = self:GetClientInfo("model")
    local pos = trace.HitPos + trace.HitNormal * 2
    local ang = Angle(0, ply:EyeAngles().y, 0)

    local ok, err = XPDRP.Inv.AddTraderSpawn(traderId, pos, ang, model)
    if not ok then
        ply:ChatPrint("[Trader Tool] " .. tostring(err or "Ошибка"))
    else
        ply:ChatPrint("[Trader Tool] Точка торговца сохранена")
    end
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not hasAccess(ply) then return false end

    local ok, err = XPDRP.Inv.RemoveNearestTraderSpawn(trace.HitPos, 140)
    if not ok then
        ply:ChatPrint("[Trader Tool] " .. tostring(err or "Ошибка"))
    else
        ply:ChatPrint("[Trader Tool] Ближайшая точка удалена")
    end
    return true
end

function TOOL:Reload()
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not hasAccess(ply) then return false end
    XPDRP.Inv.ReloadTraders()
    ply:ChatPrint("[Trader Tool] Точки торговцев перезагружены")
    return true
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {
        Text = "XPDRP Trader Spawner",
        Description = "Выбери trader_id из конфига xpdrp_inventory/config/sh_traders.lua"
    })

    panel:AddControl("TextBox", {
        Label = "Trader ID",
        Command = "xpdrp_trader_spawner_trader_id"
    })

    panel:AddControl("TextBox", {
        Label = "Model",
        Command = "xpdrp_trader_spawner_model"
    })
end