-- Detect optional mods.
local technic_path = minetest.get_modpath("technic")
local chains_path = minetest.get_modpath("chains")
local technic_path = minetest.get_modpath("technic")
local chains_path = minetest.get_modpath("chains")
local homedecor_path = minetest.get_modpath("homedecor")

-- Use homedecor's placeholder if possible.
if homedecor_path then
    minetest.register_alias("elevator:placeholder", "homedecor:expansion_placeholder")
else
    -- Placeholder node, in the style of homedecor.
    minetest.register_node("elevator:placeholder", {
        description = "Expansion Placeholder",
        selection_box = {
            type = "fixed",
            fixed = {0, 0, 0, 0, 0, 0},
        },
        groups = {
            not_in_creative_inventory=1
        },
        drawtype = "airlike",
        paramtype = "light",
        sunlight_propagates = true,

        walkable = false,
        buildable_to = false,
        is_ground_content = false,

        on_dig = function(pos, node, player)
            minetest.remove_node(pos)
            minetest.set_node(pos, {name="elevator:placeholder"})
        end
    })
end

if technic_path and chains_path then
    minetest.register_craft({
        output = "elevator:elevator",
        recipe = {
            {"technic:cast_iron_ingot", "chains:chain", "technic:cast_iron_ingot"},
            {"technic:cast_iron_ingot", "default:mese_crystal", "technic:cast_iron_ingot"},
            {"technic:stainless_steel_ingot", "default:glass", "technic:stainless_steel_ingot"},
        },
    })

    minetest.register_craft({
        output = "elevator:shaft",
        recipe = {
            {"technic:cast_iron_ingot", "default:glass"},
            {"default:glass", "glooptest:chainlink"},
        },
    })

    minetest.register_craft({
        output = "elevator:motor",
        recipe = {
            {"default:diamond", "technic:control_logic_unit", "default:diamond"},
            {"default:steelblock", "technic:motor", "default:steelblock"},
            {"chains:chain", "default:diamond", "chains:chain"}
        },
    })
elseif technic_path and farming and farming.mod and farming.mod == "redo" then
   -- add alternative recipe with hemp rope
       minetest.register_craft({
        output = "elevator:elevator",
        recipe = {
            {"technic:cast_iron_ingot", "farming:hemp_rope", "technic:cast_iron_ingot"},
            {"technic:cast_iron_ingot", "default:mese_crystal", "technic:cast_iron_ingot"},
            {"technic:stainless_steel_ingot", "default:glass", "technic:stainless_steel_ingot"},
        },
    })

    minetest.register_craft({
        output = "elevator:shaft",
        recipe = {
            {"technic:cast_iron_ingot", "default:glass"},
            {"default:glass", "farming:hemp_rope"},
        },
    })

    minetest.register_craft({
        output = "elevator:motor",
        recipe = {
            {"default:diamond", "technic:control_logic_unit", "default:diamond"},
            {"default:steelblock", "technic:motor", "default:steelblock"},
            {"farming:hemp_rope", "default:diamond", "farming:hemp_rope"}
        },
    })

-- Recipes without technic & chains required.
-- Recipes for default dependency fallback.
else
    minetest.register_craft({
        output = "elevator:elevator",
        recipe = {
            {"default:steel_ingot", "farming:cotton", "default:steel_ingot"},
            {"default:steel_ingot", "default:mese_crystal", "default:steel_ingot"},
            {"xpanes:pane_flat", "default:glass", "xpanes:pane_flat"},
        },
    })

    minetest.register_craft({
        output = "elevator:shaft",
        recipe = {
            {"default:steel_ingot", "default:obsidian_glass"},
            {"default:obsidian_glass", "default:steel_ingot"},
        },
    })

    minetest.register_craft({
        output = "elevator:motor",
        recipe = {
            {"default:diamond", "default:copper_ingot", "default:diamond"},
            {"default:steelblock", "default:furnace", "default:steelblock"},
            {"farming:cotton", "default:diamond", "farming:cotton"}
        },
    })
end
