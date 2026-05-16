AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel((NEXUS_FARM_CFG and NEXUS_FARM_CFG.PotModel) or "models/props_junk/terracotta01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    self:SetPlantStage(0)
    self:SetNextActionAt(0)
    self:SetBusy(false)
    self:SetOwnerSID64("")
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if NEXUS_FARM and isfunction(NEXUS_FARM.OpenPotMenu) then
        NEXUS_FARM.OpenPotMenu(activator, self)
    end
end

function ENT:SpawnFunction(ply, tr)
    if not tr.Hit then return end

    local ent = ents.Create("sent_pot")
    ent:SetPos(tr.HitPos + tr.HitNormal * 8)
    ent:Spawn()
    ent:Activate()
    ent:SetOwnerSID64(ply:SteamID64() or "")
    return ent
end