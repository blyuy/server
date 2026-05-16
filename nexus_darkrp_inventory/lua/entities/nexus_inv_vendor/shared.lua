ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Nexus Vendor"
ENT.Category = "Nexus Inventory"
ENT.Spawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "VendorName")
    self:NetworkVar("String", 1, "ProfileId")
end