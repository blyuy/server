AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_junk/cardboard_box003a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysWake()
    self:SetUseType(SIMPLE_USE)
end

function ENT:SetItemData(itemId, amount)
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    self:SetItemId(itemId)
    self:SetItemAmount(amount)

    local def = NEXUS_INV_CONFIG and NEXUS_INV_CONFIG.Items and NEXUS_INV_CONFIG.Items[itemId]
    if def and def.model and util.IsValidModel(def.model) then
        self:SetModel(def.model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:PhysWake()
    end
end

function ENT:GetItemData()
    return self:GetItemId(), self:GetItemAmount()
end