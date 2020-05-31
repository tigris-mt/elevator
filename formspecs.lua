
local punhash = elevator.punhash

minetest.register_on_player_receive_fields(function(sender, formname, fields)
    if formname ~= "elevator:elevator" then
        return
    end
    local pos = elevator.formspecs[sender:get_player_name()] and elevator.formspecs[sender:get_player_name()][1] or nil
    if not pos then
        return true
    end
    local meta = minetest.get_meta(pos)
    if fields.setlabel then
        if minetest.is_protected(pos, sender:get_player_name()) then
            return true
        end
        meta:set_string("label", fields.label)
        meta:set_string("infotext", fields.label)
        -- Rebuild the elevator shaft so the other elevators can read this label.
        local motorhash = meta:get_string("motor")
        elevator.build_motor(elevator.motors[motorhash] and motorhash or elevator.locate_motor(pos))
        return true
    end
    -- Double check if it's ok to go.
    if vector.distance(sender:get_pos(), pos) > 1 then
        return true
    end
    if fields.target then
        local closeformspec = ""
        -- HACK: With player information extensions enabled, we can check if closing formspecs are now allowed. This is specifically used on Survival in Ethereal.
        local pi = minetest.get_player_information(sender:get_player_name())
        if (not (pi.major == 0 and pi.minor == 4 and pi.patch == 15)) and (pi.protocol_version or 29) < 29 then
            closeformspec = "size[4,2] label[0,0;You are now using the elevator.\nUpgrade Minetest to avoid this dialog.] button_exit[0,1;4,1;close;Close]"
        end
        -- End hacky HACK.
        minetest.after(0.2, minetest.show_formspec, sender:get_player_name(), "elevator:elevator", closeformspec)
        -- Ensure we're connected to a motor.
        local motorhash = meta:get_string("motor")
        local motor = elevator.motors[motorhash]
        if not motor then
            motorhash = elevator.locate_motor(pos)
            motor = elevator.motors[motorhash]
            if motor then
                meta:set_string("motor", "")
                elevator.build_motor(motorhash)
                minetest.chat_send_player(sender:get_player_name(), "Recalibrated to a new motor, please try again.")
                return true
            end
        end
        if not motor then
            minetest.chat_send_player(sender:get_player_name(), "This elevator is not attached to a motor.")
            return true
        end
        if not elevator.formspecs[sender:get_player_name()][2] or not elevator.formspecs[sender:get_player_name()][2][minetest.explode_textlist_event(fields.target).index] then
            return true
        end
        -- Locate our target elevator.
        local target = nil
        local selected_target = elevator.formspecs[sender:get_player_name()][2][minetest.explode_textlist_event(fields.target).index]
        for i,v in ipairs(motor.pnames) do
            if v == selected_target then
                target = punhash(motor.elevators[i])
            end
        end
        -- Found the elevator? Then go!
        if target then
            -- Final check.
            if elevator.boxes[motorhash] then
                minetest.chat_send_player(sender:get_player_name(), "This elevator is in use.")
                return true
            end
            local obj = elevator.create_box(motorhash, pos, target, sender)
            -- Teleport anyone standing within an on elevator out, or they'd fall through the off elevators.
            for _,p in ipairs(motor.elevators) do
                for _,object in ipairs(minetest.get_objects_inside_radius(punhash(p), 0.6)) do
                    if object.is_player and object:is_player() then
                        if object:get_player_name() ~= obj:get_luaentity().attached then
                            elevator.teleport_player_from_elevator(object)
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
