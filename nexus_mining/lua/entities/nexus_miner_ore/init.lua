AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel((NEXUS_MINER_CONFIG and NEXUS_MINER_CONFIG.OreModel) or "models/props_junk/rock001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    self:SetDepleted(false)
    self:SetRegenAt(0)
    self:SetNWBool("NexusMinerOre", true)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end

function ENT:SetCooldown(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    self:SetDepleted(seconds > 0)
    self:SetRegenAt(CurTime() + seconds)
    self:SetNWBool("NexusMinerOre", true)
end

function ENT:Think()
    if self:GetDepleted() and CurTime() >= self:GetRegenAt() then
        self:SetDepleted(false)
        self:SetRegenAt(0)
    end

    self:NextThink(CurTime() + 0.2)
    return true
end