ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "XPDRP Inventory Drop"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ItemId")
    self:NetworkVar("Int", 0, "Amount")
end