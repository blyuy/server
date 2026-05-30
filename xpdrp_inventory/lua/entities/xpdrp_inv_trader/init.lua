AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self:GetModel() ~= "" and self:GetModel() or "models/Humans/Group01/male_07.mdl")
    self:PhysicsInit(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_PLAYER)
    self:DropToFloor()
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if not XPDRP or not XPDRP.Inv or not XPDRP.Inv.OpenTraderMenu then return end

    XPDRP.Inv.ActiveTraderByPlayer = XPDRP.Inv.ActiveTraderByPlayer or {}
    XPDRP.Inv.ActiveTraderEntByPlayer = XPDRP.Inv.ActiveTraderEntByPlayer or {}
    XPDRP.Inv.ActiveTraderByPlayer[tostring(activator:SteamID64() or "")] = self:GetTraderId()
    XPDRP.Inv.ActiveTraderEntByPlayer[tostring(activator:SteamID64() or "")] = self:EntIndex()

    XPDRP.Inv.OpenTraderMenu(activator, self:GetTraderId(), self)
end