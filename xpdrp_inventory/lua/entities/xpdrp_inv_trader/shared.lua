ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "XPDRP Trader"
ENT.Category = "XPDRP"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "TraderId")
    self:NetworkVar("String", 1, "TraderName")
end