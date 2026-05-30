TOOL.Category = "XPDRP"
TOOL.Name = "LootBox Spawner"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["box_id"] = "basic_crate"
TOOL.ClientConVar["model"] = ""

if CLIENT then
    language.Add("tool.xpdrp_lootbox_spawner.name", "XPDRP LootBox Spawner")
    language.Add("tool.xpdrp_lootbox_spawner.desc", "Spawn and save lootbox points")
    language.Add("tool.xpdrp_lootbox_spawner.0", "LMB: Spawn+save | RMB: Remove nearest save point | Reload: Reload all")
end

local function hasAccess(ply)
    local cfg = XPDRP and XPDRP.Inv and XPDRP.Inv.Config
    if not cfg then return false end
    return cfg.AdminGroups[ply:GetUserGroup()] == true
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not hasAccess(ply) then
        ply:ChatPrint("[LootBox Tool] Нет доступа")
        return false
    end
    if not trace.Hit then return false end

    local boxId = string.Trim(self:GetClientInfo("box_id") or "")
    if boxId == "" then
        for key in pairs((XPDRP and XPDRP.Inv and XPDRP.Inv.LootBoxes) or {}) do
            boxId = key
            break
        end
    end
    local model = self:GetClientInfo("model")
    local pos = trace.HitPos + trace.HitNormal * 2
    local ang = Angle(0, ply:EyeAngles().y, 0)

    local ok, err = XPDRP.Inv.AddLootBoxSpawn(boxId, pos, ang, model)
    if not ok then
        ply:ChatPrint("[LootBox Tool] " .. tostring(err or "Ошибка") .. " | box_id=" .. tostring(boxId))
    else
        ply:ChatPrint("[LootBox Tool] Точка лутбокса сохранена | box_id=" .. tostring(boxId))
    end
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not hasAccess(ply) then return false end

    local ok, err = XPDRP.Inv.RemoveNearestLootBoxSpawn(trace.HitPos, 140)
    if not ok then
        ply:ChatPrint("[LootBox Tool] " .. tostring(err or "Ошибка"))
    else
        ply:ChatPrint("[LootBox Tool] Ближайшая точка удалена")
    end
    return true
end

function TOOL:Reload()
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not hasAccess(ply) then return false end
    XPDRP.Inv.ReloadLootBoxes()
    ply:ChatPrint("[LootBox Tool] Точки лутбоксов перезагружены")
    return true
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {
        Text = "XPDRP LootBox Spawner",
        Description = "Выбери box_id из конфига xpdrp_inventory/config/sh_lootboxes.lua"
    })

    local combo = vgui.Create("DComboBox")
    combo:SetValue("Выбери лутбокс")
    combo.OnSelect = function(_, _, _, data)
        if not data then return end
        RunConsoleCommand("xpdrp_lootbox_spawner_box_id", tostring(data))
    end

    for id, box in pairs((XPDRP and XPDRP.Inv and XPDRP.Inv.LootBoxes) or {}) do
        combo:AddChoice(tostring(box.name or id), id)
    end

    panel:AddItem(combo)

    panel:AddControl("TextBox", {
        Label = "Box ID (manual)",
        Command = "xpdrp_lootbox_spawner_box_id"
    })

    panel:AddControl("TextBox", {
        Label = "Model (optional)",
        Command = "xpdrp_lootbox_spawner_model"
    })
end