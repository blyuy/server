ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Горшок для петрушки"
ENT.Category = "Nexus Farming"
ENT.Spawnable = true
ENT.AdminOnly = false

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "PlantStage")      -- 0 empty, 1 seed, 2 sprout, 3 mature
    self:NetworkVar("Float", 0, "NextActionAt")  -- cooldown after stage success
    self:NetworkVar("String", 0, "OwnerSID64")
    self:NetworkVar("Bool", 0, "Busy")
end