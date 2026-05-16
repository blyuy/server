ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Inventory World Item"
ENT.Category = "Nexus Inventory"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ItemId")
    self:NetworkVar("Int", 0, "ItemAmount")
end