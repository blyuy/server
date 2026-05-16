ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Nexus Ore"
ENT.Category = "Nexus Miner"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Depleted")
    self:NetworkVar("Float", 0, "RegenAt")
end