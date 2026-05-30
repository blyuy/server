XPDRP = XPDRP or {}
XPDRP.Inv = XPDRP.Inv or {}

function XPDRP.Inv.SafeText(v)
    if v == nil then return "" end
    return tostring(v)
end

function XPDRP.Inv.FormatMoney(v)
    v = tonumber(v) or 0
    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(v)
    end
    return string.format("%s$", string.Comma(math.floor(v)))
end

function XPDRP.Inv.GenerateTx(prefix)
    prefix = tostring(prefix or "tx")
    return string.format("%s_%d_%d", prefix, os.time(), math.random(100000, 999999))
end

function XPDRP.Inv.SortByName(list, getter)
    table.sort(list, function(a, b)
        local an = string.lower(XPDRP.Inv.SafeText(getter(a)))
        local bn = string.lower(XPDRP.Inv.SafeText(getter(b)))
        return an < bn
    end)
end

function XPDRP.Inv.ToArray(map)
    local arr = {}
    for _, v in pairs(map or {}) do
        arr[#arr + 1] = v
    end
    return arr
end