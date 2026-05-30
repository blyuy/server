ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "XPDRP Loot Box"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "BoxId")
    self:NetworkVar("String", 1, "BoxName")
    self:NetworkVar("Bool", 0, "LootReady")
    self:NetworkVar("Int", 0, "RefreshSeconds")
    self:NetworkVar("Float", 0, "NextRefreshAt")
end