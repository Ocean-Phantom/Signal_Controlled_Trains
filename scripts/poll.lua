local for_n_of = require('__flib__.table').for_n_of

local function poll_train_stop(Stop, ID)
    local T_Stop = Stop.Train_Stop
    -- remove stops if invalid
    if T_Stop.valid == false then
        for k,v in pairs(global.Surfaces) do
            if v.Train_Stops[ID] then
                v.Train_Stops[ID] = nil
                v.Demand_Stops[ID] = nil
                v.Supply_Stops[ID] = nil
                v.Refuel_Stops[ID] = nil
            end
            global.Train_Stops[ID] = nil
        end

    -- cache stops that based on whether the depot or skip signals are found
    else
        local s_index = T_Stop.surface_index
        update_train_stop_signals(ID, T_Stop)
        if Stop.Network_Supply ~= 0 then
            global.Surfaces[s_index].Supply_Stops[ID] = T_Stop
            -- add stops to cache
            for signal, v in pairs(Stop.Signals.Item_Signals) do
                if v > 0 then
                    global.Surfaces[s_index].Supply_Stops_by_Signal.item[signal][ID] = true
                end
            end
            for signal, v in pairs(Stop.Signals.Fluid_Signals) do
                if v > 0 then
                    global.Surfaces[s_index].Supply_Stops_by_Signal.fluid[signal][ID] = true
                end
            end
        else
            global.Surfaces[s_index].Supply_Stops[ID] = nil
        end

        if Stop.Network_Demand ~= 0 then
            global.Surfaces[s_index].Demand_Stops[ID] = T_Stop
            -- add stops to cache
            for signal, v in pairs(Stop.Signals.Item_Signals) do
                if v < 0 then
                    global.Surfaces[s_index].Demand_Stops_by_Signal.item[signal][ID] = true
                end
            end
            for signal, v in pairs(Stop.Signals.Fluid_Signals) do
                if v < 0 then
                    global.Surfaces[s_index].Demand_Stops_by_Signal.fluid[signal][ID] = true
                end
            end
        else
            global.Surfaces[s_index].Demand_Stops[ID] = nil
        end
    end
    return nil,false,false
end


function poll_train_stops()
    if not next(global.Train_Stops) then return end
    --dummy variables we don't do anything with
    local result
    local reached_end

    global.Poll.Last_Train_Stop, result, reached_end = for_n_of(global.Train_Stops, global.Poll.Last_Train_Stop, settings.global.SCT_Train_Stops_per_poll.value, poll_train_stop)
end


local function poll_train(Train, ID)
    local LTrain = Train.Train
    if LTrain.valid == false then
        deactivate_delivery(Train.Delivery_ID)
        deactivate_delivery(Train.Refuel_ID)
        deactivate_delivery(Train.Pickup_ID)
        global.Trains[ID] = nil
        return nil, false, false
    elseif Train.Registered_For_Delivery == false and Train.Registered_For_Pickup == false and Train.Registered_For_Refueling == false then
        return nil, false, false
    end

    local schedule = LTrain.schedule
    if schedule ~= nil then
        -- use Intended_Insert_Position if present, otherwise try to insert in the spot after current
        local next_stop = Train.Intended_Insert_Position
        if next_stop == nil then
            next_stop = schedule.current
            local length = #schedule.records
            if length <= 1 then return end
            if length == next_stop then
                next_stop = 1
            else
                next_stop = next_stop + 1
            end
        end

        --in case of temp stops. something's probably gone wrong/player did something for this to occur
        if next_stop <= #schedule.records then
            if schedule.records[next_stop].station == nil then return nil, false, false end
        end


        -- priority is refuel, then deliver, then pickup
        if Train.Registered_For_Refueling == true and Train.Has_Delivery == false and Train.Has_Pickup == false then
            attempt_delivery(ID, next_stop, 3)

        elseif Train.Registered_For_Delivery == true and Train.Registered_For_Refueling == false and Train.Refueling == false and Train.Has_Pickup == false then
            if settings.global.SCT_update_cargo_during_polls.value == true then
                update_train_cargo(ID)
                if not next(Train.Cargo) and not next(Train.Fluid_Cargo) then
                    Train.Registered_For_Delivery = false
                    return nil,false,false
                end
            end
            attempt_delivery(ID, next_stop, 1)

        elseif Train.Registered_For_Pickup == true and Train.Registered_For_Refueling == false and Train.Refueling == false and Train.Registered_For_Delivery == false and Train.Has_Delivery == false then

            -- update signals if it is still at a station with the info signal
            if LTrain.state == defines.train_state.wait_station then
                local station_lua = LTrain.station
                if station_lua.valid == true then
                    local stop_signals = global.Train_Stops[station_lua.unit_number].Signals
                    local info = stop_signals.Virtual_Signals[INFO_SIGNAL]
                    if info ~= nil then
                        if Train.Cargo_Capacity["item"] > 0 then
                            for item_signal, s in pairs(stop_signals.Item_Signals) do
                                if s < 0 then
                                    Train.Imaginary_Cargo[item_signal] = s
                                end
                            end
                        end

                        if Train.Cargo_Capacity["fluid"] > 0 then
                            for fluid_signal, s in pairs(stop_signals.Fluid_Signals) do
                                if s < 0 then
                                    Train.Imaginary_Fluid_Cargo[fluid_signal] = s
                                end
                            end
                        end
                        Train.Network_Pickup = info
                    end
                end
            end
            attempt_delivery(ID, next_stop, 2)

        end
    end
    return nil,false,false
end


function poll_trains()
    if settings.global.SCT_enable_control.value == false or not next(global.Trains) then return end
    --dummy variables we don't do anything with
    local result
    local reached_end

    global.Poll.Last_Train, result, reached_end = for_n_of(global.Trains, global.Poll.Last_Train, settings.global.SCT_Trains_per_poll.value, poll_train)
end


function poll_deliveries()
    --deactivate deliveries
    local index = game.tick - global.Settings.delivery_timeout_ticks
    if index < 0 then return end --no idea how uint - int will come out, so this is just insurance.

    local Delivery = global.Deliveries[index]
    if Delivery and (game.tick - Delivery.Tick_Started) >= global.Settings.delivery_timeout_ticks then
        if Delivery.On_Way == true then
            local type = nil
            if Delivery.Type == 1 then
                type = "delivery"
            elseif Delivery.Type == 2 then
                type = "pickup"
            elseif Delivery.Type == 3 then
                type = "refueling attempt"
            end
            local loco_id = 0
            if global.Trains[Delivery.Train_ID] and global.Trains[Delivery.Train_ID].Train.valid == true then
                local locomotives = global.Trains[Delivery.Train_ID].Train.locomotives
                if next(locomotives) and next(locomotives.front_movers) then
                    loco_id = locomotives.front_movers[1].unit_number
                elseif next(locomotives) and next(locomotives.back_movers) then
                    loco_id = locomotives.back_movers[1].unit_number
                end
            end

            game.print({"mod-messages.SCT_Delivery_Timeout_Message", type, loco_id, Delivery.Destination_Train_Stop_ID})
            if global.Trains[Delivery.Train_ID].Train.valid == true then
                deactivate_delivery(Delivery.Delivery_ID)
                reset_delivery_flags(Delivery.Train_ID)
                reset_pickup_flags(Delivery.Train_ID)
                reset_refuel_flags(Delivery.Train_ID)
            end
        end
    end

    --remove older deliveries
    index = game.tick - global.Settings.delivery_removal_ticks
    if index < 0 then return end
    local Delivery = global.Deliveries[index]
    if Delivery then
        if Delivery.Active == true then
            deactivate_delivery(Delivery.Delivery_ID)
        end
        Delivery = nil
    end
end