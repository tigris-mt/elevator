
local phash = elevator.phash
local get_node = elevator.get_node

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

minetest.register_node("elevator:shaft", {
    description = "Elevator Shaft",
    tiles = { "elevator_shaft.png" },
    drawtype = "nodebox",
    paramtype = "light",
    on_rotate = screwdriver.disallow,
    sunlight_propagates = true,
    groups = {cracky=2, oddly_breakable_by_hand=1},
    sounds = default.node_sound_stone_defaults(),
    node_box = {
        type = "fixed",
        fixed = {
            {-8/16,-8/16,-8/16,-7/16,8/16,8/16},
            {7/16,-8/16,-8/16,8/16,8/16,8/16},
            {-7/16,-8/16,-8/16,7/16,8/16,-7/16},
            {-7/16,-8/16,8/16,7/16,8/16,7/16},
        },
    },
    collisionbox = {
        type = "fixed",
        fixed = {
            {-8/16,-8/16,-8/16,-7/16,8/16,8/16},
            {7/16,-8/16,-8/16,8/16,8/16,8/16},
            {-7/16,-8/16,-8/16,7/16,8/16,-7/16},
            {-7/16,-8/16,8/16,7/16,8/16,7/16},
        },
    },
    after_place_node = function(pos)
        -- We might have connected a motor above to an elevator below.
        elevator.build_motor(elevator.locate_motor(pos))
    end,
    on_destruct = function(pos)
        -- Remove boxes and deactivate elevators below us.
        elevator.unbuild(pos, 1)
    end,
})

local box = {
    { 0.48, -0.5,-0.5,  0.5,  1.5, 0.5},
    {-0.5 , -0.5, 0.48, 0.48, 1.5, 0.5},
    {-0.5,  -0.5,-0.5 ,-0.48, 1.5, 0.5},
    {-0.5 , -0.5, -0.48, 0.5, 1.5, -0.5},
    { -0.5,-0.5,-0.5,0.5,-0.48, 0.5},
    { -0.5, 1.45,-0.5,0.5, 1.5, 0.5},
}

-- Elevator box node. Not intended to be placeable.
minetest.register_node("elevator:elevator_box", {
    description = "Elevator",
    drawtype = "nodebox",
    paramtype = 'light',
    paramtype2 = "facedir",
    wield_scale = {x=0.6, y=0.6, z=0.6},

    selection_box = {
            type = "fixed",
            fixed = { -0.5, -0.5, -0.5, 0.5, 1.5, 0.5 }
    },

    collision_box = {
            type = "fixed",
            fixed = box,
    },

    node_box = {
            type = "fixed",
            fixed = box,
    },

    tiles = {
            "default_steel_block.png",
            "default_steel_block.png",
            "elevator_box.png",
            "elevator_box.png",
            "elevator_box.png",
            "elevator_box.png",
    },
    groups = {not_in_creative_inventory = 1},

    light_source = 4,
})

minetest.register_node("elevator:motor", {
    description = "Elevator Motor",
    tiles = {
        "default_steel_block.png",
        "default_steel_block.png",
        "elevator_motor.png",
        "elevator_motor.png",
        "elevator_motor.png",
        "elevator_motor.png",
    },
    groups = {cracky=1},
    sounds = default.node_sound_stone_defaults(),
    after_place_node = function(pos, placer, itemstack)
        -- Set up the motor table.
        elevator.motors[phash(pos)] = {
            elevators = {},
            pnames = {},
            labels = {},
        }
        elevator.save_elevator()
        elevator.build_motor(phash(pos))
    end,
    on_destruct = function(pos)
        -- Destroy everything related to this motor.
        elevator.boxes[phash(pos)] = nil
        elevator.motors[phash(pos)] = nil
        elevator.save_elevator()
    end,
})

for _,mode in ipairs({"on", "off"}) do
    local nodename = "elevator:elevator_"..mode
    local on = (mode == "on")
    local box
    local cbox
    if on then
        -- Active elevators have a ceiling and floor.
        box = {

            { 0.48, -0.5,-0.5,  0.5,  1.5, 0.5},
            {-0.5 , -0.5, 0.48, 0.48, 1.5, 0.5},
            {-0.5,  -0.5,-0.5 ,-0.48, 1.5, 0.5},

            { -0.5,-0.5,-0.5,0.5,-0.48, 0.5},
            { -0.5, 1.45,-0.5,0.5, 1.5, 0.5},
        }
        cbox = table.copy(box)
        -- But you can enter them from the top.
        cbox[5] = nil
    else
        -- Inactive elevators are almost like shafts.
        box = {

            { 0.48, -0.5,-0.5,  0.5,  1.5, 0.5},
            {-0.5 , -0.5, 0.48, 0.48, 1.5, 0.5},
            {-0.5,  -0.5,-0.5 ,-0.48, 1.5, 0.5},
            {-0.5 , -0.5, -0.48, 0.5, 1.5, -0.5},
        }
        cbox = box
    end
    minetest.register_node(nodename, {
        description = "Elevator",
        drawtype = "nodebox",
        sunlight_propagates = false,
        paramtype = "light",
        paramtype2 = "facedir",
        on_rotate = screwdriver.disallow,

        selection_box = {
                type = "fixed",
                fixed = box,
        },

        collision_box = {
                type = "fixed",
                fixed = cbox,
        },

        node_box = {
                type = "fixed",
                fixed = box,
        },

        tiles = on and {
                "default_steel_block.png",
                "default_steel_block.png",
                "elevator_box.png",
                "elevator_box.png",
                "elevator_box.png",
                "elevator_box.png",
        } or {
                "elevator_box.png",
                "elevator_box.png",
                "elevator_box.png",
                "elevator_box.png",
                "elevator_box.png",
                "elevator_box.png",
        },
        groups = {cracky=1, choppy=1, snappy=1},
        drop = "elevator:elevator_off",

        -- Emit a bit of light when active.
        light_source = (on and 4 or nil),

        after_place_node  = function(pos, placer, itemstack)
            local meta = minetest.get_meta(pos)
            meta:set_int("version", elevator.VERSION)

            -- Add a placeholder to avoid nodes being placed in the top.
            local p = vector.add(pos, {x=0, y=1, z=0})
            local p2 = minetest.dir_to_facedir(placer:get_look_dir())
            minetest.set_node(p, {name="elevator:placeholder", paramtype2="facedir", param2=p2})

            -- Try to build a motor above.
            local motor = elevator.locate_motor(pos)
            if motor then
                elevator.build_motor(motor)
            end
        end,

        after_dig_node = function(pos, node, meta, digger)
            elevator.unbuild(pos, 2)
        end,

        on_place = function(itemstack, placer, pointed_thing)
            local pos  = pointed_thing.above
            local node = minetest.get_node(vector.add(pos, {x=0, y=1, z=0}))
            if (node ~= nil and node.name ~= "air" and node.name ~= "elevator:placeholder") then
                return
            end
            return minetest.item_place(itemstack, placer, pointed_thing)
        end,

        on_rightclick = function(pos, node, sender)
            if not sender or not sender:is_player() then
                return
            end
            local formspec
            local meta = minetest.get_meta(pos)
            elevator.formspecs[sender:get_player_name()] = {pos}
            if on then
                if vector.distance(sender:getpos(), pos) > 1 or minetest.get_node(sender:getpos()).name ~= nodename then
                    minetest.chat_send_player(sender:get_player_name(), "You are not inside the booth.")
                    return
                end
                -- Build the formspec from the motor table.
                local tpnames = {}
                local tpnames_l = {}
                local motorhash = meta:get_string("motor")
                local motor = elevator.motors[motorhash]
                for ji,jv in ipairs(motor.pnames) do
                    if tonumber(jv) ~= pos.y then
                        table.insert(tpnames, jv)
                        table.insert(tpnames_l, (motor.labels[ji] and motor.labels[ji] ~= "") and (jv.." - "..minetest.formspec_escape(motor.labels[ji])) or jv)
                    end
                end
                elevator.formspecs[sender:get_player_name()] = {pos, tpnames}
                if #tpnames > 0 then
                    if not minetest.is_protected(pos, sender:get_player_name()) then
                        formspec = "size[4,6]"
                        .."label[0,0;Click once to travel.]"
                        .."textlist[-0.1,0.5;4,4;target;"..table.concat(tpnames_l, ",").."]"
                        .."field[0.25,5.25;4,0;label;;"..minetest.formspec_escape(meta:get_string("label")).."]"
                        .."button_exit[-0.05,5.5;4,1;setlabel;Set label]"
                    else
                        formspec = "size[4,4.4]"
                        .."label[0,0;Click once to travel.]"
                        .."textlist[-0.1,0.5;4,4;target;"..table.concat(tpnames_l, ",").."]"
                    end
                else
                    if not minetest.is_protected(pos, sender:get_player_name()) then
                        formspec = "size[4,2]"
                        .."label[0,0;No targets available.]"
                        .."field[0.25,1.25;4,0;label;;"..minetest.formspec_escape(meta:get_string("label")).."]"
                        .."button_exit[-0.05,1.5;4,1;setlabel;Set label]"
                    else
                        formspec = "size[4,0.4]"
                        .."label[0,0;No targets available.]"
                    end
                end
                minetest.show_formspec(sender:get_player_name(), "elevator:elevator", formspec)
            elseif not elevator.motors[meta:get_string("motor")] then
                if not minetest.is_protected(pos, sender:get_player_name()) then
                    formspec = "size[4,2]"
                    .."label[0,0;This elevator is inactive.]"
                    .."field[0.25,1.25;4,0;label;;"..minetest.formspec_escape(meta:get_string("label")).."]"
                    .."button_exit[-0.05,1.5;4,1;setlabel;Set label]"
                else
                    formspec = "size[4,0.4]"
                    .."label[0,0;This elevator is inactive.]"
                end
                minetest.show_formspec(sender:get_player_name(), "elevator:elevator", formspec)
            elseif elevator.boxes[meta:get_string("motor")] then
                if not minetest.is_protected(pos, sender:get_player_name()) then
                    formspec = "size[4,2]"
                    .."label[0,0;This elevator is in use.]"
                    .."field[0.25,1.25;4,0;label;;"..minetest.formspec_escape(meta:get_string("label")).."]"
                    .."button_exit[-0.05,1.5;4,1;setlabel;Set label]"
                else
                    formspec = "size[4,0.4]"
                    .."label[0,0;This elevator is in use.]"
                end
                minetest.show_formspec(sender:get_player_name(), "elevator:elevator", formspec)
            end
        end,

        on_destruct = function(pos)
            local p = vector.add(pos, {x=0, y=1, z=0})
            if get_node(p).name == "elevator:placeholder" then
                minetest.remove_node(p)
            end
        end,
    })
end

-- Compatability with an older version.
minetest.register_alias("elevator:elevator", "elevator:elevator_off")
