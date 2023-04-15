---@param train LuaTrain
---does not check if train exists
function add_train(train)
	local id = train.id
	if not global.Trains[id] then
		global.Trains[id] = {
			Train = train or {},
            ID = id,
			Last_Station_Visited = nil,
            Last_Station_ID = nil,
			Cargo = {},
			Fluid_Cargo = {},
			Has_Delivery = false,
			Network_Supply = 0,
			Registered_For_Delivery = false,
			Exclusive_Delivery_Mode = false,
            -- Tick_Last_Checked = game.tick,
            Registered_For_Refueling = false,
            Refueling = false,
            Network_Refuel = 0,
            Registered_For_Pickup = false,
            Has_Pickup = false,
            Network_Pickup = 0,
            Imaginary_Cargo = {},
            Imaginary_Fluid_Cargo = {}
		}
	end
    local wagon_capacity = 0
    local fluid_capacity = 0
    for _, wagon in pairs(train.cargo_wagons) do
        local c = wagon.prototype.get_inventory_size(defines.inventory.cargo_wagon)
        if c then
            wagon_capacity = wagon_capacity + c
        end
    end
    for _, fluid_wagon in pairs(train.fluid_wagons) do
        fluid_capacity = fluid_capacity + fluid_wagon.prototype.fluid_capacity
    end
    global.Trains[id].Cargo_Capacity = {item = wagon_capacity, fluid = fluid_capacity}
end

---@param train_id uint
---@param stop LuaEntity
local function update_last_stop(train_id, stop)
	if stop ~= nil and global.Trains[train_id] then
		if stop.type == "train-stop" and stop.valid then
			global.Trains[train_id].Last_Station_Visited = stop
            global.Trains[train_id].Last_Station_ID = stop.unit_number
		end
	end
end

---@param train_id uint
function update_train_cargo(train_id)
    local Train = global.Trains[train_id]
	if Train then
		Train.Cargo = Train.Train.get_contents()
		Train.Fluid_Cargo = Train.Train.get_fluid_contents()
	end
end

---insert schedule at specified index
---@param train LuaTrain
---@param stop LuaEntity
---@param conditions {wait-conditions}
---@param position uint
---@param immediately (boolean) - for if called by poll function
---@return boolean
function add_stop_to_schedule(train, stop, conditions, position, immediately)
    if train.valid == false or train.schedule == nil or stop.valid == false or stop.type ~= "train-stop" then
        return false
    end
    if conditions == nil then
        conditions = {{
            compare_type = "or",
            type = "inactivity",
            ticks = 300
        }}
    end
    local new_schedule = train.schedule
    if immediately then new_schedule.current = position end
    
    --don't do anything when attempting to insert into position 0
    if position == 0 then
        return false

    --insert at position if position <= length of schedule
    elseif position <= #train.schedule.records then
        table.insert(new_schedule.records, position, {
            rail = stop.connected_rail,
            wait_conditions = {{
                type = "inactivity",
                ticks = 0,
                compare_type = "or"
            },},
            temporary = true
        })
        position = position + 1

        table.insert(new_schedule.records, position, {
            station = stop.backer_name,
            wait_conditions = conditions
        })

    --insert at end
    else
        table.insert(new_schedule.records, {
            rail = stop.connected_rail,
            wait_conditions = {{
                type = "inactivity",
                ticks = 0,
                compare_type = "or"
            },},
            temporary = true
        })
        position = position + 1

        table.insert(new_schedule.records, {
            station = stop.backer_name,
            wait_conditions = conditions
        })
    end

    train.schedule = new_schedule
    return true
end

---@param train LuaTrain
---@param position int
---@return boolean
function remove_stop_from_schedule(train, position)
    local new_schedule = train.schedule
    if new_schedule.records[position] == nil or new_schedule.records[position].temporary == true then return end
    -- if new_schedule.records[position].station:find("%[virtual%-signal=refuel%-signal]") or new_schedule.records[position].station:find("%[virtual%-signal=depot%-signal]") then
    --     position = position - 1
    -- end

    --if we're at the last stop in the schedule, wanting to go to the first
    if position == 0 then
        position = #new_schedule.records
    end
    table.remove(new_schedule.records, position)

    if new_schedule.current == 1 then
        --do nothing
    elseif new_schedule.current <= (#new_schedule.records + 1) then
        new_schedule.current = new_schedule.current - 1
    elseif new_schedule.current > (#new_schedule.records + 1) then
        --loop back to beginning of schedule
        new_schedule.current = 1
    end

    train.schedule = new_schedule
    return true
end

---@param train_id uint
function reset_delivery_flags(train_id)
    local Train = global.Trains[train_id]
    if Train then
        Train.Has_Delivery = false
        Train.Delivery_ID = nil
        Train.Registered_For_Delivery = false
        Train.Exclusive_Delivery_Mode = false
        Train.Intended_Insert_Position = nil
    end
end

---@param train_id uint
function reset_pickup_flags(train_id)
    local Train = global.Trains[train_id]
    if Train then
        Train.Has_Pickup = false
        Train.Delivery_ID = nil
        Train.Registered_For_Pickup = false
        Train.Network_Pickup = 0
        Train.Intended_Insert_Position = nil
    end
end

---@param train_id uint
function reset_refuel_flags(train_id)
    local Train = global.Trains[train_id]
    if Train then
        Train.Refueling = false
        Train.Delivery_ID = nil
        Train.Registered_For_Refueling = false
        Train.Network_Refuel = 0
    end
end

---@param train_id uint
---@return boolean
local function needs_refueling(train_id)
    local train = global.Trains[train_id].Train
    if train == nil then return false end

    ---taken directly from Train Control Signals
    local locomotives = train.locomotives
    for k, movers in pairs (locomotives) do
      for k, locomotive in pairs (movers) do
        local fuel_inventory = locomotive.get_fuel_inventory()
        if not fuel_inventory then return false end
        if #fuel_inventory == 0 then return false end
        fuel_inventory.sort_and_merge()
        if #fuel_inventory > 1 then
          if not fuel_inventory[2].valid_for_read then
            return true
          end
        else
          --Locomotive with only 1 fuel stack... idk, lets just guess
          local stack = fuel_inventory[1]
          if not stack.valid_for_read then
            --Nothing in the stack, needs refueling.
            return true
          end
          if stack.count < math.ceil(stack.prototype.stack_size / 4) then
            return true
          end
        end
      end
    end
    return false
end

---@param train LuaTrain
function skip_dot(train)
    ---DOT SIGNAL in station name means the train will always skip over to the next stop in its schedule. Does not stack: two dot stations, one immediately following the other in schedule will result in train going to second dot station
    local schedule = train.schedule

    --in case of temp stops
    if schedule.records[schedule.current].station == nil then return end

    if schedule.records[schedule.current].station:find("%[virtual%-signal=signal%-dot]") then
        local length = #schedule.records
        if length <= 1 then return end
        if length == schedule.current then
            schedule.current = 1
        else
            schedule.current = schedule.current + 1
        end
        train.go_to_station(schedule.current)
    end
end

---@param train LuaTrain
function reverse_info(train)
    ---INFO SIGNAL in station name means the train will always go back to the previous stop over to the next stop in its schedule. Does not stack: two info stations, one immediately following the other in schedule will result in train going to first info station
    local schedule = train.schedule

    --in case of temp stops
    if schedule.records[schedule.current].station == nil then return end

    if schedule.records[schedule.current].station:find("%[virtual%-signal=signal%-info]") then
        local length = #schedule.records
        if length <= 1 then return end
        if schedule.current == 1 then
            schedule.current = length
        else
            schedule.current = schedule.current - 1
        end
        train.go_to_station(schedule.current)
    end
end

function on_train_arrived(event)
    --add if they don't exist
	if not global.Trains[event.train.id] then
		add_train(event.train)
	end
    local Train = global.Trains[event.train.id]
    local train_lua = event.train
    ---ignore temp stops
    if train_lua.schedule.records[train_lua.schedule.current].temporary then
        Train.Last_Stop_Temp = true
        return
    end

    if train_lua.station == nil or train_lua.station.valid == false then return end
    local station_id = train_lua.station.unit_number
    if not global.Train_Stops[station_id] then
		add_train_stop(train_lua.station)
	end
	update_last_stop(train_lua.id, train_lua.station)

    --complete delivery
    if Train.Has_Delivery == true or Train.Has_Pickup == true or Train.Refueling == true then
        for _, delivery in pairs(global.Train_Stops[station_id].Active_Deliveries) do
            if delivery.Train_ID == train_lua.id then
                delivery.On_Way = false --it's already arrived :)
            end
        end
        if Train.Has_Delivery == true then
            Train.Cargo = {}
            Train.Fluid_Cargo = {}
        elseif Train.Has_Pickup == true then
            Train.Imaginary_Cargo = {}
            Train.Imaginary_Fluid_Cargo = {}
        end
    -- Train.Tick_Last_Checked = game.tick
    end
end

function on_train_depart(event)
    ---ignore player events
    if event.train.state == defines.train_state.manual_control or event.train.state == defines.train_state.manual_control_stop then return end
    if event.train.schedule == nil then return end

    --add train if it doesn't exist - add to existing game failsafe
	if not global.Trains[event.train.id] then
		add_train(event.train)
        return
	end

	local train_id = event.train.id
    local train = global.Trains[train_id]
    if train.Last_Stop_Temp == true then
        train.Last_Stop_Temp = nil
        return
    end

    if train.Has_Delivery == true or train.Has_Pickup == true or train.Refueling == true then
        --remove delivery from train & train station
        local delivery = global.Deliveries[train.Delivery_ID]
        --failsafe for if a train is given delivery via poll while at a station
        if delivery.On_Way == true then goto SKIP end
        deactivate_delivery(delivery.Delivery_ID)
        remove_stop_from_schedule(train.Train, train.Train.schedule.current-1)
    end

    if train.Last_Station_Visited ~= nil and train.Last_Station_Visited.valid ~= false then
        update_train_cargo(train_id)
        -- update_train_stop_signals(train.Last_Station_ID, train.Last_Station_Visited)
        local last_stop_signals = global.Train_Stops[train.Last_Station_ID].Signals

        local depot_signal = last_stop_signals.Virtual_Signals[DEPOT_SIGNAL]
        if depot_signal ~= nil then
            train.Registered_For_Delivery = true
            train.Network_Supply = depot_signal
        end

        local refuel = last_stop_signals.Virtual_Signals[FUEL_SIGNAL]
        if refuel ~= nil then
            if needs_refueling(train_id) then
                train.Registered_For_Refueling = true
                train.Network_Refuel = refuel
            end
        end

        local dot = last_stop_signals.Virtual_Signals[DOT_SIGNAL]
        if dot ~= nil then -- if it has the dot override, insert there, otherwise just do current position
            train.Intended_Insert_Position = math.abs(dot)
        else
            train.Intended_Insert_Position = train.Train.schedule.current
        end

        local exclusive_signal = last_stop_signals.Virtual_Signals[CHECK_SIGNAL]
        if exclusive_signal ~= nil then
            train.Exclusive_Delivery_Mode = true
        end

        local info = last_stop_signals.Virtual_Signals[INFO_SIGNAL]
        if info ~= nil then
            if train.Cargo_Capacity["item"] > 0 then
                for item_signal, s in pairs(last_stop_signals.Item_Signals) do
                    if s < 0 then
                        train.Imaginary_Cargo[item_signal] = s
                    end
                end
            end
            if train.Cargo_Capacity["fluid"] > 0 then
                for fluid_signal, s in pairs(last_stop_signals.Fluid_Signals) do
                    if s < 0 then
                        train.Imaginary_Fluid_Cargo[fluid_signal] = s
                    end
                end
            end
            --add every item/fluid to the train if sent the signal without any valid item/fluid signal
            -- if not next(train.Imaginary_Cargo) and not next(train.Imaginary_Fluid_Cargo) then
            --     if train.Cargo_Capacity["item"] > 0 then
            --         train.Imaginary_Cargo = table.deepcopy(global.GamePrototypes.items)
            --     end
            --     if train.Cargo_Capacity["fluid"] > 0 then
            --         train.Imaginary_Fluid_Cargo = table.deepcopy(global.GamePrototypes.fluids)
            --     end
            --     if not train.Registered_For_Delivery and not train.Registered_For_Pickup then
            --         train.Exclusive_Delivery_Mode = false
            --     end
            -- end
            train.Network_Pickup = info
            train.Registered_For_Pickup = true
            
        end
    end

    if settings.global.SCT_enable_control.value == false then return end
    if settings.global.SCT_poll_trains_only.value == true then goto SKIP end

    -- priority is refuel, then deliver, then pickup
    if train.Registered_For_Refueling == true and train.Has_Delivery == false and train.Has_Pickup == false then
        attempt_delivery(train_id, train.Intended_Insert_Position, 3)
    elseif train.Registered_For_Delivery == true and train.Registered_For_Refueling == false and train.Refueling == false and train.Has_Pickup == false then
        update_train_cargo(train_id)
        if not next(train.Cargo) and not next(train.Fluid_Cargo) then
            train.Registered_For_Delivery = false
            goto SKIP
        end
        attempt_delivery(train_id, train.Intended_Insert_Position, 1)
    elseif train.Registered_For_Pickup == true and train.Registered_For_Refueling == false and train.Refueling == false and train.Registered_For_Delivery == false and train.Has_Delivery == false then
        attempt_delivery(train_id, train.Intended_Insert_Position, 2)
    end
    
    ::SKIP::
    skip_dot(event.train)
    reverse_info(event.train)
    -- train.Tick_Last_Checked = game.tick
end