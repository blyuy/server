AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local function getProfileAndId(ent)
    local rawId = ent.GetProfileId and ent:GetProfileId() or ""
    if rawId == "" then rawId = "default" end

    local profile, resolvedId = nil, rawId
    if NEXUS_INV and NEXUS_INV.GetVendorProfile then
        profile, resolvedId = NEXUS_INV.GetVendorProfile(rawId)
    end

    if not isstring(resolvedId) or resolvedId == "" then
        resolvedId = "default"
    end

    return profile, resolvedId
end

function ENT:Initialize()
    local profile, resolvedId = getProfileAndId(self)

    self:SetProfileId(resolvedId)
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

    -- Runtime stock per vendor profile for client-side vendor UI
    self:SetNWString("NexusVendorStock", util.TableToJSON((profile and profile.stock) or {}, false) or "[]")
    self:SetNWInt("NexusVendorUseDistance", tonumber(profile and profile.useDistance) or 140)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not NEXUS_INV or not NEXUS_INV.OpenVendor then return end

    local profile = nil
    if NEXUS_INV.GetVendorProfile then
        profile = select(1, NEXUS_INV.GetVendorProfile(self:GetProfileId()))
    end

    local useDistance = tonumber((profile and profile.useDistance)) or self:GetNWInt("NexusVendorUseDistance", 140)
    if ply:GetPos():Distance(self:GetPos()) > useDistance then return end

    NEXUS_INV.OpenVendor(ply, self)
end