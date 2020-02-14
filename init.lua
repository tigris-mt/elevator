-- Detect optional mods.
local armor_path = minetest.get_modpath("3d_armor")

-- global runtime storage for data and references
-- contains .motors loaded from mod storage
-- runtime variables and api functions
elevator = {
	SPEED		= 10,	-- Initial speed of a box.
	ACCEL		= 0.1,	-- Acceleration of a box.
	VISUAL_INCREASE = 1.75,
	VERSION		= 8,	-- Elevator interface/database version.
	PTIMEOUT	= 120,	-- Maximum time a box can go without players nearby.

	boxes		= {}, -- Elevator boxes in action.
	lastboxes	= {}, -- Player near box timeout.
	riding		= {}, -- Players riding boxes.
	formspecs	= {}, -- Player formspecs.
}

local MP = minetest.get_modpath(minetest.get_current_modname())
dofile(MP .. "/helpers.lua")
dofile(MP .. "/storage.lua")
dofile(MP .. "/crafts.lua")
dofile(MP .. "/components.lua")
dofile(MP .. "/hooks.lua")
dofile(MP .. "/formspecs.lua")

local phash = elevator.phash
local punhash = elevator.punhash
local get_node = elevator.get_node

-- Cause <sender> to ride <motorhash> beginning at <pos> and targetting <target>.
elevator.create_box = function(motorhash, pos, target, sender)
    -- First create the box.
    local obj = minetest.add_entity(pos, "elevator:box")
    obj:setpos(pos)
    -- Attach the player.
    sender:setpos(pos)
    sender:set_attach(obj, "", {x=0, y=9, z=0}, {x=0, y=0, z=0})
    sender:set_eye_offset({x=0, y=-9, z=0},{x=0, y=-9, z=0})
    sender:set_properties({visual_size = {x=elevator.VISUAL_INCREASE, y=elevator.VISUAL_INCREASE}})
    if armor_path then
        armor:update_player_visuals(sender)
    end
    -- Set the box properties.
    obj:get_luaentity().motor = motorhash
    obj:get_luaentity().uid = math.floor(math.random() * 1000000)
    obj:get_luaentity().attached = sender:get_player_name()
    obj:get_luaentity().start = pos
    obj:get_luaentity().target = target
    obj:get_luaentity().halfway = {x=pos.x, y=(pos.y+target.y)/2, z=pos.z}
    obj:get_luaentity().vmult = (target.y < pos.y) and -1 or 1
    -- Set the speed.
    obj:setvelocity({x=0, y=elevator.SPEED*obj:get_luaentity().vmult, z=0})
    obj:setacceleration({x=0, y=elevator.ACCEL*obj:get_luaentity().vmult, z=0})
    -- Set the tables.
    elevator.boxes[motorhash] = obj
    elevator.riding[sender:get_player_name()] = {
        motor = motorhash,
        pos = pos,
        target = target,
        box = obj,
    }
    return obj
end

-- Starting from <pos>, locate a motor hash.
elevator.locate_motor = function(pos)
    local p = vector.new(pos)
    while true do
        local node = get_node(p)
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

elevator.build_motor = function(hash)
    local need_saving = false
    local motor = elevator.motors[hash]
    -- Just ignore motors that don't exist.
    if not motor then
        return
    end
    local p = punhash(hash)
    local node = get_node(p)
    -- And ignore motors that aren't motors.
    if node.name ~= "elevator:motor" then
        return
    end
    p.y = p.y - 1
    motor.elevators = {}
    motor.pnames = {}
    motor.labels = {}
    -- Run down through the shaft, storing information about elevators.
    while true do
        local node = get_node(p)
        if node.name == "elevator:shaft" then
            p.y = p.y - 1
        else
            p.y = p.y - 1
            local node = get_node(p)
            if node.name == "elevator:elevator_on" or node.name == "elevator:elevator_off" then
                table.insert(motor.elevators, phash(p))
                table.insert(motor.pnames, tostring(p.y))
                table.insert(motor.labels, "")
                p.y = p.y - 1
                need_saving = true
            else
                break
            end
        end
    end
    -- Set the elevators fully.
    for i,m in ipairs(motor.elevators) do
        local pos = punhash(m)
        local meta = minetest.get_meta(pos)
        meta:set_int("version", elevator.VERSION)
        if meta:get_string("motor") ~= hash then
            elevator.build_motor(meta:get_string("motor"))
        end
        motor.labels[i] = meta:get_string("label")
        meta:set_string("motor", hash)
        if motor.labels[i] ~= meta:get_string("infotext") then
            meta:set_string("infotext", motor.labels[i])
        end
    end
    if need_saving then
        elevator.save_elevator()
    end
end

elevator.unbuild = function(pos, add)
    local need_saving = false
    local p = table.copy(pos)
    p.y = p.y - 1
    -- Loop down through the network, set any elevators below this to the off position.
    while true do
        local node = get_node(p)
        if node.name == "elevator:shaft" then
            p.y = p.y - 1
        else
            p.y = p.y - 1
            local node = get_node(p)
            if node.name == "elevator:elevator_on" or node.name == "elevator:elevator_off" then
                local meta = minetest.get_meta(p)
                meta:set_string("motor", "")
                p.y = p.y - 1
            else
                break
            end
        end
    end
    -- After a short delay, build the motor and handle box removal.
    minetest.after(0.01, function(p2, add)
        if not p2 or not add then
            return
        end
        p2.y = p2.y + add
        local motorhash = elevator.locate_motor(p2)
        elevator.build_motor(motorhash)
        -- If there's a box below this point, break it.
        if elevator.boxes[motorhash] and elevator.boxes[motorhash]:getpos() and p2.y >= elevator.boxes[motorhash]:getpos().y then
            elevator.boxes[motorhash] = nil
        end
        -- If the box does not exist, just clear it.
        if elevator.boxes[motorhash] and not elevator.boxes[motorhash]:getpos() then
            elevator.boxes[motorhash] = nil
        end
    end, table.copy(pos), add)
end

-- Ensure an elevator is up to the latest version.
local function upgrade_elevator(pos, meta)
    if meta:get_int("version") ~= elevator.VERSION then
        minetest.log("action", "[elevator] Updating elevator with old version at "..minetest.pos_to_string(pos))
        minetest.after(0, function(pos) elevator.build_motor(elevator.locate_motor(pos)) end, pos)
        meta:set_int("version", elevator.VERSION)
        meta:set_string("formspec", "")
        meta:set_string("infotext", meta:get_string("label"))
    end
end

-- Convert off to on when applicable.
local offabm = function(pos, node)
    local meta = minetest.get_meta(pos)
    upgrade_elevator(pos, meta)
    if not elevator.boxes[meta:get_string("motor")] and elevator.motors[meta:get_string("motor")] then
        node.name = "elevator:elevator_on"
        minetest.swap_node(pos, node)
    end
end

minetest.register_abm({
    nodenames = {"elevator:elevator_off"},
    interval = 1,
    chance = 1,
    action = offabm,
    label = "Elevator (Off)",
})

-- Convert on to off when applicable.
minetest.register_abm({
    nodenames = {"elevator:elevator_on"},
    interval = 1,
    chance = 1,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        upgrade_elevator(pos, meta)
        if elevator.boxes[meta:get_string("motor")] or not elevator.motors[meta:get_string("motor")] then
            node.name = "elevator:elevator_off"
            minetest.swap_node(pos, node)
        end
    end,
    label = "Elevator (On)",
})

-- Remove the player from self, and teleport them to pos if specified.
local function detach(self, pos)
    local player = minetest.get_player_by_name(self.attached)
    local attached = player:get_attach()
    if not attached or attached:get_luaentity().uid ~= self.uid then
        return
    end
    player:set_detach()
    player:set_eye_offset({x=0, y=0, z=0},{x=0, y=0, z=0})
    player:set_properties({visual_size = {x=1, y=1}})
    if armor_path then
        armor:update_player_visuals(player)
    end
    if pos then
        player:setpos(pos)
	minetest.after(0.1, function(pl, p)
		pl:setpos(p)
	end, player, pos)
    end
    elevator.riding[self.attached] = nil
end

local box_entity = {
    physical = false,
    collisionbox = {0,0,0,0,0,0},
    visual = "wielditem",
    visual_size = {x=1, y=1},
    textures = {"elevator:elevator_box"},

    attached = "",
    motor = false,
    target = false,

    start = false,
    lastpos = false,
    halfway = false,
    vmult = 0,

    on_activate = function(self, staticdata)
        -- Don't want the box being destroyed by anything except the elevator system.
        self.object:set_armor_groups({immortal=1})
    end,

    on_step = function(self, dtime)
        local pos = self.object:getpos()
        -- First, check if this box needs removed.
        -- If the motor has a box and it isn't this box.
        if elevator.boxes[self.motor] and elevator.boxes[self.motor] ~= self.object then
            minetest.log("action", "[elevator] "..minetest.pos_to_string(pos).." broke due to duplication.")
            self.object:remove()
            return
        end
        -- If our attached player can't be found.
        if not minetest.get_player_by_name(self.attached) then
            minetest.log("action", "[elevator] "..minetest.pos_to_string(pos).." broke due to lack of attachee logged in.")
            self.object:remove()
            elevator.boxes[self.motor] = nil
            return
        end
        -- If our attached player is no longer with us.
        if not minetest.get_player_by_name(self.attached):get_attach() or minetest.get_player_by_name(self.attached):get_attach():get_luaentity().uid ~= self.uid then
            minetest.log("action", "[elevator] "..minetest.pos_to_string(pos).." broke due to lack of attachee.")
            self.object:remove()
            elevator.boxes[self.motor] = nil
            return
        end
        -- If our motor's box is nil, we should self-destruct.
        if not elevator.boxes[self.motor] then
            minetest.log("action", "[elevator] "..minetest.pos_to_string(pos).." broke due to nil entry in boxes.")
            detach(self)
            self.object:remove()
            elevator.boxes[self.motor] = nil
            return
        end

        minetest.get_player_by_name(self.attached):setpos(pos)
        -- Ensure lastpos is set to something.
        self.lastpos = self.lastpos or pos

        -- Loop through all travelled nodes.
        for y=self.lastpos.y,pos.y,((self.lastpos.y > pos.y) and -0.3 or 0.3) do
            local p = vector.round({x=pos.x, y=y, z=pos.z})
            local node = get_node(p)
            if node.name == "elevator:shaft" then
                -- Nothing, just continue on our way.
            elseif node.name == "elevator:elevator_on" or node.name == "elevator:elevator_off" then
                -- If this is our target, detach the player here, destroy this box, and update the target elevator without waiting for the abm.
                if vector.distance(p, self.target) < 1 then
                    minetest.log("action", "[elevator] "..minetest.pos_to_string(p).." broke due to arrival.")
                    detach(self, vector.add(self.target, {x=0, y=-0.4, z=0}))
                    self.object:remove()
                    elevator.boxes[self.motor] = nil
                    offabm(self.target, node)
                    return
                end
            else
                -- Check if we're in the top part of an elevator, if so it's fine.
                local below = vector.add(p, {x=0,y=-1,z=0})
                local belownode = get_node(below)
                if belownode.name ~= "elevator:elevator_on" and belownode.name ~= "elevator:elevator_off" then
                    -- If we aren't, then break the box.
                    minetest.log("action", "[elevator] "..minetest.pos_to_string(p).." broke on "..node.name)
                    elevator.boxes[self.motor] = nil
                    detach(self, p)
                    self.object:remove()
                    return
                end
            end
        end
        self.lastpos = pos
    end,
}

minetest.register_entity("elevator:box", box_entity)
