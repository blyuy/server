local sharedFiles = {
    "xpdrp_script/config/sh_core.lua",
    "xpdrp_script/sh_registry.lua",
    "xpdrp_script/config/sh_items_medical.lua",
    "xpdrp_script/config/sh_items_materials.lua",
    "xpdrp_script/config/sh_items_utility.lua",
    "xpdrp_script/config/sh_recipes_basic.lua",
    "xpdrp_script/config/sh_merchants_default.lua"
}

if SERVER then
    for _, path in ipairs(sharedFiles) do
        AddCSLuaFile(path)
        include(path)
    end

    AddCSLuaFile("xpdrp_script/cl_core.lua")
    include("xpdrp_script/sv_core.lua")
else
    for _, path in ipairs(sharedFiles) do
        include(path)
    end

    include("xpdrp_script/cl_core.lua")
end
