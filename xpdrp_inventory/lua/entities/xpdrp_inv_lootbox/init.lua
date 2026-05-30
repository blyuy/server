AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self:GetModel() ~= "" and self:GetModel() or "models/Items/item_item_crate.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end

    if self:GetRefreshSeconds() <= 0 then
        self:SetRefreshSeconds(600)
    end
    if self:GetBoxName() == "" then
        self:SetBoxName("Лутбокс")
    end
    if self:GetLootReady() == false and self:GetNextRefreshAt() <= 0 then
        self:SetNextRefreshAt(CurTime() + self:GetRefreshSeconds())
    end
end

function ENT:Think()
    if (not self:GetLootReady()) and self:GetNextRefreshAt() > 0 and CurTime() >= self:GetNextRefreshAt() then
        self:SetLootReady(true)
        self:SetNextRefreshAt(0)
    end
    self:NextThink(CurTime() + 1)
    return true
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not XPDRP or not XPDRP.Inv or not XPDRP.Inv.OpenLootBoxMenu then return end

    local ok, msg = XPDRP.Inv.OpenLootBoxMenu(activator, self)
    if msg and msg ~= "" then
        activator:ChatPrint("[LootBox] " .. msg)
    end
end