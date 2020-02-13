
local elevator_file = minetest.get_worldpath() .. "/elevator"

local str = minetest.get_mod_storage and minetest.get_mod_storage()

-- Central "network" table.
elevator.motors = {}

local function load_elevator()
	local data = nil
    if str and ((str.contains and str:contains("data")) or (str:get_string("data") and str:get_string("data") ~= "")) then
        data = minetest.deserialize(str:get_string("data"))
	else
		local file = io.open(elevator_file)
		if file then
			data = minetest.deserialize(file:read("*all")) or {}
			file:close()
		end
	end
	elevator.motors = data.motors and data.motors or {}
end

local function save_elevator()
    if str then
        str:set_string("data", minetest.serialize({motors = elevator.motors}))
        return
    end
    local f = io.open(elevator_file, "w")
    f:write(minetest.serialize({motors = elevator.motors}))
    f:close()
end

load_elevator()
