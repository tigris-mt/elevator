
-- Try to teleport player away from any closed (on) elevator node.
elevator.teleport_player_from_elevator = function(player)
    local function solid(pos)
        if not minetest.registered_nodes[minetest.get_node(pos).name] then
            return true
        end
        return minetest.registered_nodes[minetest.get_node(pos).name].walkable
    end
    local pos = vector.round(player:getpos())
    local node = minetest.get_node(pos)
    -- elevator_off is like a shaft, so the player would already be falling.
    if node.name == "elevator:elevator_on" then
        local front = vector.subtract(pos, minetest.facedir_to_dir(node.param2))
        local front_above = vector.add(front, {x=0, y=1, z=0})
        local front_below = vector.subtract(front, {x=0, y=1, z=0})
        -- If the front isn't solid, it's ok to teleport the player.
        if not solid(front) and not solid(front_above) then
            player:setpos(front)
        end
    end
end

elevator.phash = function(pos)
    return minetest.pos_to_string(pos)
end

elevator.punhash = function(pos)
    return minetest.string_to_pos(pos)
end

-- Helper function to read unloaded nodes.
elevator.get_node = function(pos)
    local node = minetest.get_node_or_nil(pos)
    if node then return node end
    local _,_ = VoxelManip():read_from_map(pos, pos)
    return minetest.get_node_or_nil(pos)
end
