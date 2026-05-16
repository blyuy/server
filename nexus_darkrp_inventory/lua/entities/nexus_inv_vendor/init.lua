AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    local profileId = self:GetProfileId()
    local profile = NEXUS_INV and NEXUS_INV.GetVendorProfile and NEXUS_INV.GetVendorProfile(profileId) or nil

    self:SetModel((profile and profile.model) or "models/Humans/Group01/Male_07.mdl")
    self:SetMoveType(MOVETYPE_STEP)
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetNPCState(NPC_STATE_SCRIPT)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)
    self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
    self:PhysicsInitBox(Vector(-16, -16, 0), Vector(16, 16, 72))
    self:CapabilitiesAdd(CAP_ANIMATEDFACE + CAP_TURN_HEAD)
    self:SetUseType(SIMPLE_USE)
    self:DropToFloor()
    self:SetMaxYawSpeed(90)
    self:SetVendorName((profile and profile.name) or "Торговец")

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ply:GetPos():Distance(self:GetPos()) > ((NEXUS_INV_CONFIG.VendorDefaults and NEXUS_INV_CONFIG.VendorDefaults.useDistance) or 140) then return end
    if not NEXUS_INV or not NEXUS_INV.OpenVendor then return end
    NEXUS_INV.OpenVendor(ply, self)
end