AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    if not self:GetModel() or self:GetModel() == "" then
        self:SetModel("models/props_junk/trashdumpster02.mdl")
    end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not NEXUS_LOOTBIN or not NEXUS_LOOTBIN.OpenForPlayer then return end
    NEXUS_LOOTBIN.OpenForPlayer(ply, self)
end