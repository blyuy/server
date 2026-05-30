if not CLIENT then return end

XPDRP = XPDRP or {}
XPDRP.UI = XPDRP.UI or {}

local T = XPDRP.UI

T.Colors = {
    Bg = Color(7, 12, 20, 230),
    Surface = Color(10, 16, 26, 236),
    SurfaceSoft = Color(12, 19, 30, 228),
    Border = Color(255, 255, 255, 14),
    Accent = Color(82, 162, 255),
    Text = Color(236, 243, 255),
    Dim = Color(171, 188, 210),
    Money = Color(112, 214, 136)
}

T.Rarity = {
    common = { Color(120, 140, 165), Label = "Обычный" },
    uncommon = { Color(112, 214, 136), Label = "Необычный" },
    rare = { Color(82, 162, 255), Label = "Редкий" },
    epic = { Color(184, 116, 255), Label = "Эпический" },
    legendary = { Color(255, 176, 74), Label = "Легендарный" }
}

function T.GetRarityInfo(id)
    return T.Rarity[id or "common"] or T.Rarity.common
end

function T.DrawPanel(w, h, alpha)
    local c = T.Colors
    draw.RoundedBox(8, 0, 0, w, h, Color(c.Surface.r, c.Surface.g, c.Surface.b, alpha or c.Surface.a))
    surface.SetDrawColor(c.Border)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

function T.DrawHeader(w)
    local c = T.Colors
    draw.RoundedBox(8, 0, 0, w, 3, Color(c.Accent.r, c.Accent.g, c.Accent.b, 78))
end

function T.DrawGlassGrid(w, h, step, alpha)
    local c = T.Colors
    draw.RoundedBox(8, 0, 0, w, h, Color(c.Bg.r, c.Bg.g, c.Bg.b, alpha or 210))
    step = step or 56
    surface.SetDrawColor(255, 255, 255, 8)
    for x = 0, w, step do
        surface.DrawLine(x, 0, x, h)
    end
    for y = 0, h, step do
        surface.DrawLine(0, y, w, y)
    end
end

local function lerpColor(t, a, b)
    return Color(
        Lerp(t, a.r, b.r),
        Lerp(t, a.g, b.g),
        Lerp(t, a.b, b.b),
        Lerp(t, a.a or 255, b.a or 255)
    )
end

function T.DrawRarityGradient(x, y, w, h, rarityId, alpha)
    local info = T.GetRarityInfo(rarityId)
    local c = info.Color or Color(82, 162, 255)
    local a = math.Clamp(tonumber(alpha) or 120, 0, 255)

    -- Material-free gradient to avoid pink/black checker on servers with missing gradient materials.
    local slices = 22
    local sw = w / slices
    for i = 0, slices - 1 do
        local t = i / (slices - 1)
        local colA = a * (0.28 + 0.72 * t)
        local col = Color(
            math.Clamp(c.r * (0.42 + 0.58 * t), 0, 255),
            math.Clamp(c.g * (0.42 + 0.58 * t), 0, 255),
            math.Clamp(c.b * (0.42 + 0.58 * t), 0, 255),
            colA
        )
        surface.SetDrawColor(col)
        surface.DrawRect(x + i * sw, y, sw + 1, h)
    end

    -- Soft top highlight for depth.
    surface.SetDrawColor(255, 255, 255, math.floor(a * 0.12))
    surface.DrawRect(x, y, w, math.max(1, math.floor(h * 0.18)))
end