XPDRP = XPDRP or {}
XPDRP.Inventory = XPDRP.Inventory or {}

XPDRP.Inventory.Items = XPDRP.Inventory.Items or {}
XPDRP.Inventory.Recipes = XPDRP.Inventory.Recipes or {}
XPDRP.Inventory.Merchants = XPDRP.Inventory.Merchants or {}

function XPDRP.Inventory.RegisterItem(id, data)
    if not isstring(id) or id == "" or not istable(data) then return end

    data.id = id
    data.name = data.name or id
    data.stack = math.max(1, math.floor(data.stack or XPDRP.Inventory.Config.MaxStack or 1))
    data.icon = data.icon or "icon16/box.png"
    data.description = data.description or ""

    XPDRP.Inventory.Items[id] = data
end

function XPDRP.Inventory.GetItem(id)
    return XPDRP.Inventory.Items[id]
end

function XPDRP.Inventory.RegisterRecipe(id, data)
    if not isstring(id) or id == "" or not istable(data) then return end
    if not isstring(data.result) then return end

    data.id = id
    data.name = data.name or id
    data.amount = math.max(1, math.floor(data.amount or 1))
    data.require = data.require or {}

    XPDRP.Inventory.Recipes[id] = data
end

function XPDRP.Inventory.GetRecipe(id)
    return XPDRP.Inventory.Recipes[id]
end

function XPDRP.Inventory.RegisterMerchant(id, data)
    if not isstring(id) or id == "" or not istable(data) then return end

    data.id = id
    data.name = data.name or id
    data.model = data.model or "models/Humans/Group01/male_07.mdl"
    data.buy = data.buy or {}
    data.sell = data.sell or {}
    data.spawns = data.spawns or {}

    XPDRP.Inventory.Merchants[id] = data
end

function XPDRP.Inventory.GetMerchant(id)
    return XPDRP.Inventory.Merchants[id]
end
