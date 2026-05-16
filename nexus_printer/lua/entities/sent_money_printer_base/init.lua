AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local PRINTER_CFG = {
    sent_printer_tier1 = {
        tier = 1,
        name = "Кустарный принтер",
        model = "models/props_lab/reciever01a.mdl",
        moneyPerTick = 100,
        tickTime = 10,
        maxMoney = 7000
    },
    sent_printer_tier2 = {
        tier = 2,
        name = "Продвинутый принтер",
        model = "models/props_lab/printedcircuitboard.mdl",
        moneyPerTick = 300,
        tickTime = 15,
        maxMoney = 30000
    },
    sent_printer_tier3 = {
        tier = 3,
        name = "Профессиональный принтер",
        model = "models/props_combine/combine_interface001a.mdl",
        moneyPerTick = 800,
        tickTime = 20,
        maxMoney = 100000
    }
}

local USE_DIST_SQR = 150 * 150

local function getCfg(ent)
    return PRINTER_CFG[ent:GetClass()]
end

local function canUsePrinter(ply, ent)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not IsValid(ent) then return false end
    if ply:GetPos():DistToSqr(ent:GetPos()) > USE_DIST_SQR then return false end

    local ownerSid = ent:GetOwnerSID64()
    if ownerSid ~= "" and ownerSid ~= ply:SteamID64() and not ply:IsAdmin() then
        return false
    end

    return true
end

function ENT:Initialize()
    local cfg = getCfg(self)
    if not cfg then
        self:Remove()
        return
    end

    self:SetModel(cfg.model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    self:SetStoredMoney(0)
    self:SetHeat(0)
    self:SetInk(100)
    self:SetJammed(false)
    self:SetActive(true)
    self:SetTier(cfg.tier)

    self.NextPrint = CurTime() + cfg.tickTime
end

function ENT:SpawnFunction(ply, tr)
    if not tr.Hit then return end

    local ent = ents.Create(self.ClassName)
    ent:SetPos(tr.HitPos + tr.HitNormal * 10)
    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ent:Spawn()
    ent:Activate()
    ent:SetOwnerSID64(ply:SteamID64() or "")
    return ent
end

function ENT:OnTakeDamage(dmg)
    self:TakePhysicsDamage(dmg)
end

function ENT:ExplodePrinter()
    local pos = self:GetPos()

    local fx = ents.Create("env_explosion")
    fx:SetPos(pos)
    fx:SetKeyValue("iMagnitude", "80")
    fx:SetOwner(self)
    fx:Spawn()
    fx:Fire("Explode", 0, 0)

    util.BlastDamage(self, self, pos, 220, 35)
    self:Remove()
end

function ENT:CollectMoney(ply)
    if not canUsePrinter(ply, self) then return end

    local money = self:GetStoredMoney()
    if money <= 0 then
        ply:ChatPrint("[PRINTER] Нечего снимать.")
        return
    end

    if ply.addMoney then
        ply:addMoney(money)
    else
        -- fallback
        ply:SetNWInt("money", (ply:GetNWInt("money", 0) + money))
    end

    self:SetStoredMoney(0)
    ply:ChatPrint("[PRINTER] Вы сняли $" .. money)
end

function ENT:RepairJam(ply)
    if not canUsePrinter(ply, self) then return end
    if self:GetTier() ~= 3 then return end
    if not self:GetJammed() then return end

    self:SetJammed(false)
    self:SetActive(true)
    ply:ChatPrint("[PRINTER] Бумага исправлена, печать возобновлена.")
end

function ENT:Use(activator)
    if not IsValid(activator) then return end
    if not canUsePrinter(activator, self) then return end

    if self:GetTier() == 3 and self:GetJammed() then
        self:RepairJam(activator)
        return
    end

    self:CollectMoney(activator)
end

function ENT:StartTouch(other)
    if not IsValid(other) then return end
    local class = other:GetClass()

    -- Tier1: охлаждение
    if self:GetTier() == 1 and class == "sent_cooler" then
        self:SetHeat(0)
        other:Remove()
        return
    end

    -- Tier2: чернила
    if self:GetTier() == 2 and class == "sent_ink" then
        self:SetInk(100)
        self:SetActive(true)
        other:Remove()
        return
    end
end

function ENT:Think()
    local cfg = getCfg(self)
    if not cfg then return end

    if CurTime() < (self.NextPrint or 0) then
        self:NextThink(CurTime() + 0.2)
        return true
    end

    self.NextPrint = CurTime() + cfg.tickTime

    local stored = self:GetStoredMoney()
    if stored >= cfg.maxMoney then
        self:SetActive(false)
        self:NextThink(CurTime() + 0.2)
        return true
    end

    -- Tier1: перегрев
    if cfg.tier == 1 then
        local heat = math.Clamp(self:GetHeat() + 5, 0, 100)
        self:SetHeat(heat)

        if heat >= 100 then
            self:ExplodePrinter()
            return
        end
    end

    -- Tier2: чернила
    if cfg.tier == 2 then
        if self:GetInk() <= 0 then
            self:SetActive(false)
            self:NextThink(CurTime() + 0.2)
            return true
        end

        local ink = math.Clamp(self:GetInk() - 4, 0, 100)
        self:SetInk(ink)

        if ink <= 0 then
            self:SetActive(false)
        else
            self:SetActive(true)
        end
    end

    -- Tier3: застряла бумага
    if cfg.tier == 3 then
        if self:GetJammed() then
            self:SetActive(false)
            self:NextThink(CurTime() + 0.2)
            return true
        end

        if math.random(1, 100) <= 15 then
            self:SetJammed(true)
            self:SetActive(false)
            self:NextThink(CurTime() + 0.2)
            return true
        end
    end

    if self:GetActive() or cfg.tier == 1 or cfg.tier == 3 then
        local add = math.min(cfg.moneyPerTick, cfg.maxMoney - self:GetStoredMoney())
        self:SetStoredMoney(self:GetStoredMoney() + add)
        self:SetActive(true)
    end

    self:NextThink(CurTime() + 0.2)
    return true
end