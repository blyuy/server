include("shared.lua")

local stageScale = {
    [1] = 0.42,
    [2] = 0.75,
    [3] = 1.00
}

local cachedPlantModel = nil

local function resolvePlantModel()
    if cachedPlantModel ~= nil then
        return cachedPlantModel
    end

    local candidates = {
        (NEXUS_FARM_CFG and NEXUS_FARM_CFG.PlantModel) or "",
        "models/props_lab/plant01.mdl",
        "models/props_lab/cactus.mdl"
    }

    for i = 1, #candidates do
        local mdl = tostring(candidates[i] or "")
        if mdl ~= "" and util.IsValidModel(mdl) then
            cachedPlantModel = mdl
            return cachedPlantModel
        end
    end

    cachedPlantModel = false
    return cachedPlantModel
end

function ENT:Draw()
    self:DrawModel()

    local st = self:GetPlantStage()
    if st > 0 then
        local mdl = resolvePlantModel()
        if mdl and mdl ~= false then
            local scale = stageScale[st] or 0.42
            local m = Matrix()
            m:Scale(Vector(scale, scale, scale))

            render.Model({
                model = mdl,
                pos = self:GetPos() + Vector(0, 0, 8),
                angle = self:GetAngles(),
                matrix = m
            })
        end
    end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:GetPos():DistToSqr(self:GetPos()) > (220 * 220) then return end

    local title = "Пустой горшок"
    if st == 1 then title = "Семя посажено" end
    if st == 2 then title = "Росток" end
    if st == 3 then title = "Зрелый куст" end

    local cd = math.max(0, math.ceil(self:GetNextActionAt() - CurTime()))
    local sub = (cd > 0) and ("Откат: " .. cd .. "с") or "Нажмите E"

    local ang = EyeAngles()
    ang = Angle(0, ang.y - 90, 90)
    local pos = self:GetPos() + Vector(0, 0, 28)

    cam.Start3D2D(pos, ang, 0.08)
        draw.RoundedBox(8, -118, -22, 236, 46, Color(10, 16, 32, 235))
        draw.SimpleText(title, "DermaDefaultBold", 0, -5, Color(238, 244, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(sub, "DermaDefault", 0, 12, Color(170, 190, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end