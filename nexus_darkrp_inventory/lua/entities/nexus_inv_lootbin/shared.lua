ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Nexus Loot Bin"
ENT.Category = "Nexus Inventory"
ENT.Spawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ProfileId")
    self:NetworkVar("String", 1, "BinName")
end