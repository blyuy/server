if not CLIENT then return end

XPDRP = XPDRP or {}

local files = {
    "xpdrp_menus/cl_config.lua",
    "xpdrp_menus/cl_utils.lua",
    "xpdrp_menus/cl_3d2d.lua",
    "xpdrp_menus/cl_hud.lua",
    "xpdrp_menus/cl_f4.lua",
    "xpdrp_menus/cl_tab.lua",
    "xpdrp_menus/cl_cmenu.lua",
    "xpdrp_menus/cl_door.lua"
}

for _, path in ipairs(files) do
    include(path)
end
