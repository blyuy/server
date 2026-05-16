if SERVER then
    AddCSLuaFile()
end

local USE_DIST = 150
local USE_DIST_SQR = USE_DIST * USE_DIST

local PRINTER_CLASSES = {
    sent_printer_tier1 = {
        printName = "Кустарный принтер",
        model = "models/props_lab/reciever01a.mdl",
        modelFallback = "models/props_lab/reciever01b.mdl",
        moneyPerTick = 100,
        tickTime = 10,
        maxMoney = 7000,
        tier = 1
    },
    sent_printer_tier2 = {
        printName = "Продвинутый принтер",
        model = "models/props_lab/printedcircuitboard.mdl",
        modelFallback = "models/props_lab/partsbin01.mdl",
        moneyPerTick = 300,
        tickTime = 15,
        maxMoney = 30000,
        tier = 2
    },
    sent_printer_tier3 = {
        printName = "Профессиональный принтер",
        model = "models/props_combine/combine_interface001a.mdl",
        modelFallback = "models/props_combine/combine_interface001.mdl",
        moneyPerTick = 800,
        tickTime = 20,
        maxMoney = 100000,
        tier = 3
    }
}

local RESOURCE_CLASSES = {
    sent_cooler = {
        printName = "Охлаждающий спрей",
        model = "models/props_junk/garbage_glassbottle003a.mdl"
    },
    sent_ink = {
        printName = "Картридж с чернилами",
        model = "models/props_lab/box01a.mdl"
    }
}

local function isPrinterClass(className)
    return PRINTER_CLASSES[className] ~= nil
end

local function safeModel(primary, fallback)
    if util.IsValidModel(primary) then return primary end
    if util.IsValidModel(fallback) then return fallback end
    return "models/props_lab/reciever01a.mdl"
end

local function ownerCanUse(ply, ent)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if not IsValid(ent) or not isPrinterClass(ent:GetClass()) then return false end
    if ply:GetPos():DistToSqr(ent:GetPos()) > USE_DIST_SQR then return false end

    local ownerSid = (ent.GetOwnerSID64 and ent:GetOwnerSID64()) or ""
    if ownerSid ~= "" and ownerSid ~= ply:SteamID64() and not ply:IsAdmin() then
        return false
    end

    return true
end

local function addDarkRPMoney(ply, amount)
    if ply.addMoney then
        ply:addMoney(amount)
        return
    end

    if DarkRP and DarkRP.storeMoney and DarkRP.retrieveMoney then
        local cur = DarkRP.retrieveMoney(ply)
        DarkRP.storeMoney(ply, cur + amount)
        return
    end

    ply:SetNWInt("money", ply:GetNWInt("money", 0) + amount)
end

local function createExplosion(ent)
    local pos = ent:GetPos()

    local exp = ents.Create("env_explosion")
    exp:SetPos(pos)
    exp:SetKeyValue("iMagnitude", "90")
    exp:SetOwner(ent)
    exp:Spawn()
    exp:Fire("Explode", "", 0)

    util.BlastDamage(ent, ent, pos, 240, 40)
end

local function registerPrinter(className, cfg)
    local ENT = {}
    ENT.Type = "anim"
    ENT.Base = "base_anim"
    ENT.PrintName = cfg.printName
    ENT.Category = "Nexus Printers"
    ENT.Spawnable = true
    ENT.AdminOnly = false
    ENT.RenderGroup = RENDERGROUP_OPAQUE

    function ENT:SetupDataTables()
        self:NetworkVar("Int", 0, "StoredMoney")
        self:NetworkVar("Float", 0, "Heat")
        self:NetworkVar("Float", 1, "Ink")
        self:NetworkVar("Bool", 0, "Jammed")
        self:NetworkVar("Bool", 1, "Active")
        self:NetworkVar("Int", 1, "Tier")
        self:NetworkVar("String", 0, "OwnerSID64")
    end

    if SERVER then
        function ENT:Initialize()
            self:SetModel(safeModel(cfg.model, cfg.modelFallback))
            self:PhysicsInit(SOLID_VPHYSICS)
            self:SetMoveType(MOVETYPE_VPHYSICS)
            self:SetSolid(SOLID_VPHYSICS)
            self:SetUseType(SIMPLE_USE)

            local phys = self:GetPhysicsObject()
            if IsValid(phys) then phys:Wake() end

            self:SetStoredMoney(0)
            self:SetHeat(0)
            self:SetInk(100)
            self:SetJammed(false)
            self:SetActive(true)
            self:SetTier(cfg.tier)
            self:SetOwnerSID64("")

            self.NextPrint = CurTime() + cfg.tickTime
            self.WorkLoop = CreateSound(self, "ambient/machines/combine_terminal_idle4.wav")
            self.LoopOn = false
        end

        function ENT:SpawnFunction(ply, tr)
            if not tr.Hit then return end

            local ent = ents.Create(className)
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

        function ENT:UpdateLoopSound()
            local shouldPlay = self:GetActive() and not self:GetJammed()

            if shouldPlay and not self.LoopOn then
                if self.WorkLoop then self.WorkLoop:PlayEx(0.35, 100) end
                self.LoopOn = true
            elseif not shouldPlay and self.LoopOn then
                if self.WorkLoop then self.WorkLoop:FadeOut(0.4) end
                self.LoopOn = false
            end
        end

        function ENT:CollectMoney(ply)
            if not ownerCanUse(ply, self) then return end

            local money = self:GetStoredMoney()
            if money <= 0 then
                ply:ChatPrint("[PRINTER] Денег в принтере нет.")
                self:EmitSound("buttons/button19.wav", 60, 95)
                return
            end

            addDarkRPMoney(ply, money)
            self:SetStoredMoney(0)
            self:EmitSound("items/ammo_pickup.wav", 65, 100)
            ply:ChatPrint("[PRINTER] Вы сняли $" .. money)
        end

        function ENT:RepairJam(ply)
            if not ownerCanUse(ply, self) then return end
            if cfg.tier ~= 3 then return end
            if not self:GetJammed() then return end

            self:SetJammed(false)
            self:SetActive(true)
            self:EmitSound("buttons/button14.wav", 65, 110)
            ply:ChatPrint("[PRINTER] Бумага извлечена, печать восстановлена.")
        end

        function ENT:Use(activator)
            if not ownerCanUse(activator, self) then return end

            if cfg.tier == 3 and self:GetJammed() then
                self:RepairJam(activator)
                return
            end

            self:CollectMoney(activator)
        end

        function ENT:StartTouch(other)
            if not IsValid(other) then return end
            local oClass = other:GetClass()

            if cfg.tier == 1 and oClass == "sent_cooler" then
                self:SetHeat(0)
                self:EmitSound("ambient/water/water_spray1.wav", 60, 100)
                other:Remove()
                return
            end

            if cfg.tier == 2 and oClass == "sent_ink" then
                self:SetInk(100)
                self:SetActive(true)
                self:EmitSound("items/battery_pickup.wav", 60, 110)
                other:Remove()
                return
            end
        end

        function ENT:Think()
            if CurTime() < (self.NextPrint or 0) then
                self:UpdateLoopSound()
                self:NextThink(CurTime() + 0.2)
                return true
            end

            self.NextPrint = CurTime() + cfg.tickTime

            if self:GetStoredMoney() >= cfg.maxMoney then
                self:SetActive(false)
                self:UpdateLoopSound()
                self:NextThink(CurTime() + 0.2)
                return true
            end

            local canPrint = true

            if cfg.tier == 1 then
                local heat = math.Clamp(self:GetHeat() + 5, 0, 100)
                self:SetHeat(heat)
                if heat >= 100 then
                    self:EmitSound("ambient/explosions/explode_4.wav", 90, 100)
                    createExplosion(self)
                    self:Remove()
                    return
                end
            end

            if cfg.tier == 2 then
                local ink = self:GetInk()
                if ink <= 0 then
                    canPrint = false
                else
                    ink = math.Clamp(ink - 4, 0, 100)
                    self:SetInk(ink)
                    if ink <= 0 then canPrint = false end
                end

                if not canPrint then
                    self:EmitSound("buttons/button8.wav", 55, 85)
                end
            end

            if cfg.tier == 3 then
                if self:GetJammed() then
                    canPrint = false
                elseif math.random(1, 100) <= 15 then
                    self:SetJammed(true)
                    canPrint = false
                    self:EmitSound("buttons/combine_button_locked.wav", 65, 100)
                end
            end

            self:SetActive(canPrint)

            if canPrint then
                local add = math.min(cfg.moneyPerTick, cfg.maxMoney - self:GetStoredMoney())
                if add > 0 then
                    self:SetStoredMoney(self:GetStoredMoney() + add)
                    self:EmitSound("ambient/machines/combine_terminal_idle1.wav", 55, 105)
                end
            end

            self:UpdateLoopSound()
            self:NextThink(CurTime() + 0.2)
            return true
        end

        function ENT:OnRemove()
            if self.WorkLoop then self.WorkLoop:Stop() end
        end
    else
        function ENT:Draw()
            self:DrawModel()
        end
    end

    scripted_ents.Register(ENT, className, true)
end

local function registerResource(className, cfg)
    local ENT = {}
    ENT.Type = "anim"
    ENT.Base = "base_anim"
    ENT.PrintName = cfg.printName
    ENT.Category = "Nexus Printers"
    ENT.Spawnable = true
    ENT.AdminOnly = false

    if SERVER then
        function ENT:Initialize()
            self:SetModel(cfg.model)
            self:PhysicsInit(SOLID_VPHYSICS)
            self:SetMoveType(MOVETYPE_VPHYSICS)
            self:SetSolid(SOLID_VPHYSICS)
            local phys = self:GetPhysicsObject()
            if IsValid(phys) then phys:Wake() end
        end
    else
        function ENT:Draw()
            self:DrawModel()
        end
    end

    scripted_ents.Register(ENT, className, true)
end

for className, cfg in pairs(PRINTER_CLASSES) do
    registerPrinter(className, cfg)
end

for className, cfg in pairs(RESOURCE_CLASSES) do
    registerResource(className, cfg)
end

if SERVER then
    hook.Add("PhysgunPickup", "NexusPrinters_BlockForeignPhysgun", function(ply, ent)
        if not IsValid(ent) or not isPrinterClass(ent:GetClass()) then return end
        if ownerCanUse(ply, ent) then return true end
        return false
    end)

    hook.Add("GravGunPickupAllowed", "NexusPrinters_BlockForeignGravGun", function(ply, ent)
        if not IsValid(ent) or not isPrinterClass(ent:GetClass()) then return end
        if ownerCanUse(ply, ent) then return true end
        return false
    end)
end

if CLIENT then
    list.Set("SpawnableEntities", "sent_printer_tier1", {
        PrintName = "Кустарный принтер",
        ClassName = "sent_printer_tier1",
        Category = "Nexus Printers",
        AdminOnly = false
    })

    list.Set("SpawnableEntities", "sent_printer_tier2", {
        PrintName = "Продвинутый принтер",
        ClassName = "sent_printer_tier2",
        Category = "Nexus Printers",
        AdminOnly = false
    })

    list.Set("SpawnableEntities", "sent_printer_tier3", {
        PrintName = "Профессиональный принтер",
        ClassName = "sent_printer_tier3",
        Category = "Nexus Printers",
        AdminOnly = false
    })

    list.Set("SpawnableEntities", "sent_cooler", {
        PrintName = "Охлаждающий спрей",
        ClassName = "sent_cooler",
        Category = "Nexus Printers",
        AdminOnly = false
    })

    list.Set("SpawnableEntities", "sent_ink", {
        PrintName = "Картридж с чернилами",
        ClassName = "sent_ink",
        Category = "Nexus Printers",
        AdminOnly = false
    })

    surface.CreateFont("PrinterUI_Title", { font = "Roboto", size = 34, weight = 900, antialias = true })
    surface.CreateFont("PrinterUI_Sub", { font = "Roboto", size = 18, weight = 700, antialias = true })
    surface.CreateFont("PrinterUI_Body", { font = "Roboto", size = 24, weight = 800, antialias = true })
    surface.CreateFont("PrinterUI_Small", { font = "Roboto", size = 15, weight = 600, antialias = true })

    local TIER_UI = {
        [1] = { name = "Кустарный Принтер", accent = Color(255, 154, 104), mode = "heat", status = "Температура", chip = "HEAT" },
        [2] = { name = "Продвинутый Принтер", accent = Color(102, 176, 255), mode = "ink", status = "Чернила", chip = "INK" },
        [3] = { name = "Профессиональный Принтер", accent = Color(97, 235, 190), mode = "jam", status = "Статус", chip = "CORE" }
    }

    local PANEL_W, PANEL_H = 500, 290
    local PANEL_SCALE = 0.042

    local RENDER_DIST = 280
    local RENDER_DIST_SQR = RENDER_DIST * RENDER_DIST

    local cachedPrinters = {}
    local nextCacheRefresh = 0

    local function refreshPrinterCache()
        cachedPrinters = {}
        local t1 = ents.FindByClass("sent_printer_tier1")
        local t2 = ents.FindByClass("sent_printer_tier2")
        local t3 = ents.FindByClass("sent_printer_tier3")

        for i = 1, #t1 do cachedPrinters[#cachedPrinters + 1] = t1[i] end
        for i = 1, #t2 do cachedPrinters[#cachedPrinters + 1] = t2[i] end
        for i = 1, #t3 do cachedPrinters[#cachedPrinters + 1] = t3[i] end
    end

local function txt(text, font, x, y, col, ax, ay)
    -- Мягкая тень вместо рваной обводки
    draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 120), ax, ay)
    draw.SimpleText(text, font, x, y, col, ax, ay)
end

    local function moneyText(v)
        return "$" .. tostring(math.floor(v or 0))
    end

    local function getAnchor(ent)
        local _, maxs = ent:OBBMins(), ent:OBBMaxs()
        return ent:LocalToWorld(Vector(0, 0, maxs.z + 12))
    end

    local function getBillboardAng()
        local ea = EyeAngles()
        return Angle(0, ea.y - 90, 90)
    end

    local function progressBar(x, y, w, h, frac, col)
        frac = math.Clamp(frac, 0, 1)
        draw.RoundedBox(6, x, y, w, h, Color(20, 28, 44, 235))
        draw.RoundedBox(6, x, y, math.max(4, w * frac), h, col)
    end

    local function drawPanel(ent, ui)
        local w, h = PANEL_W, PANEL_H
        local x, y = -w * 0.5, -h * 0.5

        local stored = ent:GetStoredMoney()
        local statusFrac = 1
        local statusText = "OK"
        local statusColor = ui.accent
        local chipText = ui.chip

        if ui.mode == "heat" then
            local heat = ent:GetHeat()
            statusFrac = math.Clamp(heat / 100, 0, 1)
            statusText = ui.status .. ": " .. math.floor(heat) .. "%"
            if heat >= 75 then statusColor = Color(250, 95, 95) end
        elseif ui.mode == "ink" then
            local ink = ent:GetInk()
            statusFrac = math.Clamp(ink / 100, 0, 1)
            statusText = ui.status .. ": " .. math.floor(ink) .. "%"
            if ink <= 20 then statusColor = Color(245, 135, 95) end
        else
            local jam = ent:GetJammed()
            if jam then
                statusText = "ОШИБКА: ЗАСТРЯЛА БУМАГА"
                statusColor = Color(245, 88, 88)
                chipText = "ERROR"
            else
                statusText = "Статус: Работает"
                statusColor = Color(110, 225, 155)
                chipText = "READY"
            end
        end

        draw.RoundedBox(12, x, y, w, h, Color(7, 11, 22, 246))
        draw.RoundedBox(12, x, y, w, 42, Color(ui.accent.r, ui.accent.g, ui.accent.b, 245))
        draw.RoundedBox(8, x + 10, y + 50, w - 20, h - 60, Color(12, 18, 34, 242))

        txt(ui.name, "PrinterUI_Sub", 0, y + 21, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.RoundedBox(5, x + 14, y + 64, 90, 20, Color(22, 32, 54, 245))
        txt(chipText, "PrinterUI_Small", x + 59, y + 74, Color(225, 238, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        txt("Баланс", "PrinterUI_Small", 0, y + 90, Color(200, 220, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        txt(moneyText(stored), "PrinterUI_Body", 0, y + 118, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        txt(statusText, "PrinterUI_Sub", 0, y + 143, Color(225, 238, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        progressBar(x + 26, y + 156, w - 52, 14, statusFrac, statusColor)

        draw.RoundedBox(8, -165, y + h - 48, 330, 36, Color(76, 124, 224, 246))
        txt("СНЯТЬ ДЕНЬГИ [E]", "PrinterUI_Sub", 0, y + h - 30, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if ui.mode == "jam" and ent:GetJammed() then
            draw.RoundedBox(8, -165, y + h - 86, 330, 30, Color(236, 84, 84, 246))
            txt("ПОЧИНИТЬ [E]", "PrinterUI_Small", 0, y + h - 71, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    hook.Remove("PostDrawOpaqueRenderables", "NexusPrinters_Draw3D2D_Big")

    hook.Add("PostDrawOpaqueRenderables", "NexusPrinters_Draw3D2D_Big", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        if CurTime() >= nextCacheRefresh then
            refreshPrinterCache()
            nextCacheRefresh = CurTime() + 1.0
        end

        local ang = getBillboardAng()

        for i = #cachedPrinters, 1, -1 do
            local ent = cachedPrinters[i]
            if not IsValid(ent) then
                table.remove(cachedPrinters, i)
                continue
            end

            if lp:GetPos():DistToSqr(ent:GetPos()) > RENDER_DIST_SQR then continue end
            if not ent.GetTier then continue end

            local ui = TIER_UI[ent:GetTier()] or TIER_UI[1]
            local anchor = getAnchor(ent)

            cam.Start3D2D(anchor, ang, PANEL_SCALE)
                drawPanel(ent, ui)
            cam.End3D2D()
        end
    end)
end