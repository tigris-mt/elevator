local SPEED = 10
local ACCEL = 1
local VERSION = 6

local elevator = {
    motors = {},
}
local boxes = {}
local formspecs = {}
local lastpp = {}
local time = 0
minetest.register_globalstep(function(dtime)
    time = time + dtime
    if time < 0.5 then
        return
    end
    time = 0
    for _,p in ipairs(minetest.get_connected_players()) do
        local pos = p:getpos()
        if minetest.get_node(pos).name ~= "elevator:elevator_on" then
            lastpp[p:get_player_name()] = pos
        end
    end
end)
minetest.register_on_leaveplayer(function(player)
    if lastpp[player:get_player_name()] and vector.distance(lastpp[player:get_player_name()], player:getpos()) < 20 then
        player:setpos(lastpp[player:get_player_name()])
    end
end)
local elevator_file = minetest.get_worldpath() .. "/elevator"

local function load_elevator()
    local file = io.open(elevator_file)
    if file then
        elevator = minetest.deserialize(file:read("*all")) or {}
        file:close()
    end
end

local function save_elevator()
    local f = io.open(elevator_file .. ".tmp", "w")
    f:write(minetest.serialize(elevator))
    f:close()
    os.rename(elevator_file .. ".tmp", elevator_file)
end

load_elevator()

local function phash(pos)
    return minetest.pos_to_string(pos)
end

local function locate_motor(pos)
    local p = vector.new(pos)
    while true do
        local node = technic.get_or_load_node(p) or technic.get_or_load_node(p)
        if node.name == "elevator:elevator_on" or node.name == "elevator:elevator_off" then
            p.y = p.y + 2
        elseif node.name == "elevator:shaft" then
            p.y = p.y + 1
        elseif node.name == "elevator:motor" then
            return phash(p)
        else
            return nil
        end
    end
end

local function build_motor(hash)
    local need_saving = false
    local motor = elevator.motors[hash]
    if not motor then
        return
    end
    local p = minetest.string_to_pos(hash)
    local node = technic.get_or_load_node(p) or technic.get_or_load_node(p)
    if node.name ~= "elevator:motor" then
        return
    end
    p.y = p.y - 1
    motor.elevators = {}
    motor.pnames = {}
    while true do
        local node = technic.get_or_load_node(p) or technic.get_or_load_node(p)
        if node.name == "elevator:shaft" then
            p.y = p.y - 1
        else
            p.y = p.y - 1
            local node = technic.get_or_load_node(p) or technic.get_or_load_node(p)
            if node.name == "elevator:elevator_on" or node.name == "elevator:elevator_off" then
                table.insert(motor.elevators, phash(p))
                table.insert(motor.pnames, tostring(p.y))
                p.y = p.y - 1
                need_saving = true
            else
                break
            end
        end
    end
    for i,m in ipairs(motor.elevators) do
        local tpnames = {}
        local pos = minetest.string_to_pos(m)
        local meta = minetest.get_meta(pos)
        for ji,jv in ipairs(motor.pnames) do
            if ji ~= i then
                table.insert(tpnames, jv)
            end
        end
        meta:set_string("elevator_formspec", "size[3,2]"
            .."dropdown[0,0;3;target;"..table.concat(tpnames, ",")..";1]"
            .."button_exit[0,1;3,1;go;Go]")
        meta:set_int("version", VERSION)
        if meta:get_string("formspec") ~= "" then
            meta:set_string("formspec", "")
        end
        if meta:get_string("motor") ~= hash then
            build_motor(meta:get_string("motor"))
        end
        meta:set_string("motor", hash)
    end
    if need_saving then
        save_elevator()
    end
end

local function unbuild(pos, add)
    local need_saving = false
    local p = table.copy(pos)
    p.y = p.y - 1
    while true do
        local node = technic.get_or_load_node(p) or technic.get_or_load_node(p)
        if node.name == "elevator:shaft" then
            p.y = p.y - 1
        else
            p.y = p.y - 1
            local node = technic.get_or_load_node(p) or technic.get_or_load_node(p)
            if node.name == "elevator:elevator_on" or node.name == "elevator:elevator_off" then
                local meta = minetest.get_meta(p)
                meta:set_string("motor", "")
                p.y = p.y - 1
            else
                break
            end
        end
    end
    minetest.after(0.01, function(p2)
        p2.y = p2.y + add
        local motorhash = locate_motor(p2)
        build_motor(motorhash)
        if boxes[motorhash] and p2.y >= boxes[motorhash]:getpos().y then
            boxes[motorhash] = nil
        end
    end, table.copy(pos))
end

minetest.register_node("elevator:motor", {
    description = "Elevator Motor",
    tiles = { "technic_wrought_iron_block.png^homedecor_motor.png" },
    groups = {cracky=1},
    sounds = default.node_sound_stone_defaults(),
    after_place_node = function(pos, placer, itemstack)
        elevator.motors[phash(pos)] = {
            elevators = {},
            pnames = {},
        }
        save_elevator()
        build_motor(phash(pos))
    end,
    on_destruct = function(pos)
        boxes[phash(pos)] = nil
        elevator.motors[phash(pos)] = nil
        save_elevator()
    end,
})

for _,mode in ipairs({"on", "off"}) do
local nodename = "elevator:elevator_"..mode
local on = (mode == "on")
local box
local cbox
if on then
    box = {

        { 0.48, -0.5,-0.5,  0.5,  1.5, 0.5},
        {-0.5 , -0.5, 0.48, 0.48, 1.5, 0.5},
        {-0.5,  -0.5,-0.5 ,-0.48, 1.5, 0.5},

        { -0.5,-0.5,-0.5,0.5,-0.48, 0.5},
        { -0.5, 1.45,-0.5,0.5, 1.5, 0.5},
    }
    cbox = box
    cbox[5] = nil
else
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
    drawtype = (on and "mesh" or "nodebox"),
    mesh = "travelnet_elevator.obj",
    sunlight_propagates = false,
    paramtype = 'light',
    paramtype2 = "facedir",

    selection_box = {
            type = "fixed",
            fixed = { -0.5, -0.5, -0.5, 0.5, 1.5, 0.5 }
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
            "elevator_box.png",
            "elevator_box.png",
            "elevator_box.png",
            "elevator_box.png",
            "default_steel_block.png",
            "default_steel_block.png",
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

    light_source = (on and 4 or nil),

    after_place_node  = function(pos, placer, itemstack)
        local meta = minetest.get_meta(pos)
        meta:set_int("version", VERSION)
        local p = {x=pos.x, y=pos.y+1, z=pos.z}
        local p2 = minetest.dir_to_facedir(placer:get_look_dir())
        minetest.set_node(p, {name="homedecor:expansion_placeholder", paramtype2="facedir", param2=p2})
        local motor = locate_motor(pos)
        if motor then
            build_motor(motor)
        end
    end,

    after_dig_node = function(pos, node, meta, digger)
        unbuild(pos, 2)
    end,

    on_place = function(itemstack, placer, pointed_thing)
       local pos  = pointed_thing.above
       local node = minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z})
       if( node ~= nil and node.name ~= "air" and node.name ~= 'homedecor:expansion_placeholder') then
          return
       end
       return minetest.item_place(itemstack, placer, pointed_thing);
    end,

    on_rightclick = function(pos, node, sender)
        local meta = minetest.get_meta(pos)
        if on then
            if vector.distance(sender:get_pos(), pos) > 1 or minetest.get_node(sender:get_pos()).name ~= nodename then
                minetest.chat_send_player(sender:get_player_name(), "You are not inside the booth.")
                return
            end
            formspecs[sender:get_player_name()] = pos
            minetest.show_formspec(sender:get_player_name(), "elevator:elevator", meta:get_string("elevator_formspec"))
        elseif not elevator.motors[meta:get_string("motor")] then
            minetest.chat_send_player(sender:get_player_name(), "This elevator is inactive.")
        elseif boxes[meta:get_string("motor")] then
            minetest.chat_send_player(sender:get_player_name(), "This elevator is in use.")
        end
    end,

    on_destruct = function(pos)
        local p = {x=pos.x, y=pos.y+1, z=pos.z}
        minetest.remove_node(p)
    end,
})
end

minetest.register_on_player_receive_fields(function(sender, formname, fields)
    if formname ~= "elevator:elevator" then
        return
    end
    local pos = formspecs[sender:get_player_name()]
    if not pos then
        return
    end
    local meta = minetest.get_meta(pos)
    if vector.distance(sender:get_pos(), pos) > 1 or boxes[meta:get_string("motor")] then
        return
    end
    if fields.go then
        local motorhash = meta:get_string("motor")
        local motor = elevator.motors[motorhash]
        if not motor then
            motorhash = locate_motor(pos)
            motor = elevator.motors[motorhash]
            if motor then
                meta:set_string("motor", "")
                build_motor(motorhash)
                minetest.chat_send_player(sender:get_player_name(), "Recalibrated to a new motor, please try again.")
                return true
            end
        end
        if not motor then
            minetest.chat_send_player(sender:get_player_name(), "This elevator is not attached to a motor.")
            return true
        end
        local target = nil
        for i,v in ipairs(motor.pnames) do
            if v == fields.target then
                target = minetest.string_to_pos(motor.elevators[i])
            end
        end
        if target then
            if boxes[motorhash] then
                minetest.chat_send_player(sender:get_player_name(), "This elevator is in use.")
                return true
            end
            local obj = minetest.add_entity(pos, "elevator:box")
            obj:set_pos(pos)
            sender:set_pos(pos)
            sender:set_attach(obj, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
            sender:set_eye_offset({x=0, y=-9, z=0},{x=0, y=-9, z=0})
            obj:get_luaentity().motor = motorhash
            obj:get_luaentity().attached = sender:get_player_name()
            obj:get_luaentity().start = pos
            obj:get_luaentity().target = target
            obj:get_luaentity().halfway = {x=pos.x, y=(pos.y+target.y)/2, z=pos.z}
            obj:get_luaentity().vmult = (target.y < pos.y) and -1 or 1
            obj:setvelocity({x=0, y=SPEED*obj:get_luaentity().vmult, z=0})
            obj:setacceleration({x=0, y=ACCEL*obj:get_luaentity().vmult, z=0})
            boxes[motorhash] = obj

            for _,p in ipairs(motor.elevators) do
                local p = minetest.string_to_pos(p)
                for _,object in ipairs(minetest.get_objects_inside_radius(p, 2)) do
                    if object.is_player and object:is_player() and minetest.get_node(object:getpos()).name == "elevator:elevator_on" then
                        if object:get_player_name() ~= obj:get_luaentity().attached then
                            object:setpos(lastpp[sender:get_player_name()])
                        end
                    end
                end
            end
        else
            minetest.chat_send_player(sender:get_player_name(), "This target is invalid.")
            return true
        end
        return true
    end
    return true
end)

minetest.register_alias("elevator:elevator", "elevator:elevator_off")

local offabm = function(pos, node)
    local meta = minetest.get_meta(pos)
    if meta:get_int("version") ~= VERSION then
        minetest.log("action", "[elevator] Updating elevator with old version at "..minetest.pos_to_string(pos))
        minetest.after(0, function(pos) build_motor(locate_motor(pos)) end, pos)
        meta:set_int("version", VERSION)
        meta:set_string("formspec", "")
    end
    if not boxes[meta:get_string("motor")] and elevator.motors[meta:get_string("motor")] then
        node.name = "elevator:elevator_on"
        minetest.swap_node(pos, node)
    end
end

minetest.register_abm({
    nodenames = {"elevator:elevator_off"},
    interval = 1,
    chance = 1,
    action = offabm,
})

minetest.register_abm({
    nodenames = {"elevator:elevator_on"},
    interval = 1,
    chance = 1,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        if meta:get_int("version") ~= VERSION then
            minetest.log("action", "[elevator] Updating elevator with old version at "..minetest.pos_to_string(pos))
            minetest.after(0, function(pos) build_motor(locate_motor(pos)) end, pos)
            meta:set_int("version", VERSION)
            meta:set_string("formspec", "")
        end
        if boxes[meta:get_string("motor")] or not elevator.motors[meta:get_string("motor")] then
            node.name = "elevator:elevator_off"
            minetest.swap_node(pos, node)
        end
    end,
})

minetest.register_node("elevator:shaft", {
    description = "Elevator Shaft",
    tiles = { "elevator_shaft.png" },
    drawtype = "nodebox",
    paramtype = "light",
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
        build_motor(locate_motor(pos))
    end,
    on_destruct = function(pos)
        unbuild(pos, 1)
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

minetest.register_node("elevator:elevator_box", {
    description = "Elevator",
    drawtype = ("nodebox"),
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

local box_entity = {
    physical = false,
    collisionbox = {0,0,0,0,0,0},
    visual = "wielditem",
    mesh = "carts_cart.b3d",
    visual_size = {x=1, y=1},
    textures = {"elevator:elevator_box"},

    attached = "",
    motor = false,
    target = false,

    start = false,
    lastpos = false,
    halfway = false,
    vmult = 0,

    on_activate = function(self)
        self.object:set_armor_groups({immortal=1})
    end,

    on_step = function(self, dtime)
        if not minetest.get_player_by_name(self.attached) then
            self.object:remove()
            boxes[self.motor] = nil
            return
        end
        if not boxes[self.motor] then
            minetest.get_player_by_name(self.attached):set_eye_offset({x=0, y=0, z=0},{x=0, y=0, z=0})
            self.object:remove()
            return
        end
        local pos = self.object:getpos()
        self.lastpos = self.lastpos or pos
        for y=self.lastpos.y,pos.y,((self.lastpos.y > pos.y) and -1 or 1) do
            local p = vector.round({x=pos.x, y=y, z=pos.z})
            --local above = vector.add(p, {x=0,y=1,z=0})
            local below = vector.add(p, {x=0,y=-1,z=0})
            local node = technic.get_or_load_node(p) or technic.get_or_load_node(p)
            if node.name == "elevator:shaft" then
                -- Nothing
            elseif node.name == "elevator:elevator_on" or node.name == "elevator:elevator_off" then
                if vector.distance(p, self.target) < 1 then
                    self.object:remove()
                    minetest.get_player_by_name(self.attached):set_detach()
                    minetest.get_player_by_name(self.attached):set_pos(vector.add(self.target, {x=0, y=-0.4, z=0}))
                    minetest.get_player_by_name(self.attached):set_eye_offset({x=0, y=0, z=0},{x=0, y=0, z=0})
                    boxes[self.motor] = nil
                    offabm(self.target, node)
                    return
                end
            else
                --local abovenode = technic.get_or_load_node(above) or technic.get_or_load_node(above)
                local belownode = technic.get_or_load_node(below) or technic.get_or_load_node(below)
                if belownode.name ~= "elevator:elevator_on" and belownode.name ~= "elevator:elevator_off" then
                    boxes[self.motor] = nil
                    self.object:remove()
                    minetest.get_player_by_name(self.attached):set_eye_offset({x=0, y=0, z=0},{x=0, y=0, z=0})
                    return
                end
            end
        end
        self.lastpos = pos
        if vector.distance(pos, self.target) < 32 and self.object:getvelocity().y > SPEED/2 then
            self.object:setacceleration({x=0, y=((SPEED)*self.vmult*-1), z=0})
        elseif self.object:getvelocity().y > SPEED and vector.distance(pos, self.target) < math.min(100, vector.distance(pos, self.start)) then
            self.object:setacceleration({x=0, y=((SPEED/10)*self.vmult*-1), z=0})
        elseif self.object:getvelocity().y <= SPEED/1.5 then
            self.object:setacceleration({x=0, y=((SPEED/10)*self.vmult), z=0})
        end
    end,
}

minetest.register_entity("elevator:box", box_entity)

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
        {"default:glass", "homedecor:chainlink_steel"},
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
