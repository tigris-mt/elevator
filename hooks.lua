
-- Globalstep timer.
local time = 0

minetest.register_globalstep(function(dtime)
    -- Don't want to run this too often.
    time = time + dtime
    if time < 0.5 then
        return
    end
    time = 0
    -- Only count riders who are still logged in.
    local newriding = {}
    for _,p in ipairs(minetest.get_connected_players()) do
        local pos = p:getpos()
        local name = p:get_player_name()
        newriding[name] = elevator.riding[name]
        -- If the player is indeed riding, update their position.
        if newriding[name] then
            newriding[name].pos = pos
        end
    end
    elevator.riding = newriding
    for name,r in pairs(elevator.riding) do
        -- If the box is no longer loaded or existent, create another.
        local ok = r.box and r.box.getpos and r.box:getpos() and r.box:get_luaentity() and r.box:get_luaentity().attached == name
        if not ok then
            minetest.log("action", "[elevator] "..minetest.pos_to_string(r.pos).." created due to lost rider.")
            minetest.after(0, elevator.create_box, r.motor, r.pos, r.target, minetest.get_player_by_name(name))
        end
    end
    -- Ensure boxes are deleted after <PTIMEOUT> seconds if there are no players nearby.
    for motor,obj in pairs(elevator.boxes) do
        if type(obj) ~= "table" then
            return
        end
        elevator.lastboxes[motor] = elevator.lastboxes[motor] and math.min(elevator.lastboxes[motor], elevator.PTIMEOUT) or elevator.PTIMEOUT
        elevator.lastboxes[motor] = math.max(elevator.lastboxes[motor] - 1, 0)
        local pos = obj:getpos()
        if pos then
            for _,object in ipairs(minetest.get_objects_inside_radius(pos, 5)) do
                if object.is_player and object:is_player() then
                    elevator.lastboxes[motor] = elevator.PTIMEOUT
                    break
                end
            end
            if elevator.lastboxes[motor] < 1 then
                minetest.log("action", "[elevator] "..minetest.pos_to_string(pos).." broke due to lack of players.")
                elevator.boxes[motor] = false
            end
        else
            minetest.log("action", "[elevator] "..minetest.pos_to_string(pos).." broke due to lack of position during player check.")
            elevator.boxes[motor] = false
        end
    end
end)

minetest.register_on_leaveplayer(function(player)
    -- We don't want players potentially logging into open elevators.
    elevator.teleport_player_from_elevator(player)
end)
