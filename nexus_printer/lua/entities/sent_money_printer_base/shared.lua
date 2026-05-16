ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Money Printer Base"
ENT.Category = "Nexus Printers"
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "StoredMoney")
    self:NetworkVar("Float", 0, "Heat")
    self:NetworkVar("Float", 1, "Ink")
    self:NetworkVar("Bool", 0, "Jammed")
    self:NetworkVar("Bool", 1, "Active")
    self:NetworkVar("Int", 1, "Tier")
    self:NetworkVar("String", 0, "OwnerSID64")
end