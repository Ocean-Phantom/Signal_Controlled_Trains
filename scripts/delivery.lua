---@param same_net {Train_Stops}
---@param train Trains
---@return eligibile_stops? {Train_Stops}
local function standard_delivery(same_net, train)
	local eligible_stops = {} -- stops that look for at least one cargo
	local non_exclusive_stops = {} --stops that only have some matches (array of tables, arranged by how many items that stop does not handle)
	local exclusive_stops = {} --stops that have all matches
	for _, stop_lua in pairs(same_net) do
		local num_matches = 0
		local train_stop = global.Train_Stops[stop_lua.unit_number]
		if stop_lua.valid ~= true then
			goto SKIP
		end
		--generally cheaper to do liquid cargo first, as there are fewer elements
		for fluid_cargo, v in pairs(train.Fluid_Cargo) do
			local signal = train_stop.Signals.Fluid_Signals[fluid_cargo]
			if signal then
				local test = signal.amount
				if test >= 0 then
					local s_index = train.Train.front_stock.surface_index
					global.Surfaces[s_index].Demand_Stops_by_Signal.fluid[fluid_cargo][train_stop.ID] = nil
					goto SKIP
				end
				if train_stop.Cargo_In_Transit.Fluid_Cargo[fluid_cargo] then
					test = signal.amount + train_stop.Cargo_In_Transit.Fluid_Cargo[fluid_cargo]
				end

				if test < 0 and math.abs(test) >= v then
					num_matches = num_matches + 1
				elseif train.Exclusive_Delivery_Mode == true then
					--skip checking more
					goto SKIP
				end
			else -- signal not found
				local s_index = train.Train.front_stock.surface_index
				global.Surfaces[s_index].Demand_Stops_by_Signal.fluid[fluid_cargo][train_stop.ID] = nil
			end
		end

		for cargo, v in pairs(train.Cargo) do
			local signal = train_stop.Signals.Item_Signals[cargo]
			if signal then
				local test = signal.amount
				if test >= 0 then
					local s_index = train.Train.front_stock.surface_index
					global.Surfaces[s_index].Demand_Stops_by_Signal.item[cargo][train_stop.ID] = nil
					goto SKIP
				end
				if train_stop.Cargo_In_Transit.Cargo[cargo] then
					test = signal.amount + train_stop.Cargo_In_Transit.Cargo[cargo]
				end

				if test < 0 and math.abs(test) >= v then
					num_matches = num_matches + 1
				elseif train.Exclusive_Delivery_Mode == true then
					--skip checking more
					goto SKIP
				end
			else -- signal not found
				local s_index = train.Train.front_stock.surface_index
				global.Surfaces[s_index].Demand_Stops_by_Signal.item[cargo][train_stop.ID] = nil
			end
		end
		::SKIP::
		local cargo_size = table_size(train.Fluid_Cargo) + table_size(train.Cargo)
		if num_matches == cargo_size then
			table.insert(exclusive_stops, train_stop)
			-- game.print("exclusive stop found")
		elseif num_matches > 1 then
			local index = cargo_size - num_matches
			if not non_exclusive_stops[index] then
				non_exclusive_stops[index] = {}
			end
			table.insert(non_exclusive_stops[index], train_stop)
			-- game.print("non exclusive stop found")
		elseif num_matches == 1 then
			table.insert(eligible_stops, train_stop)
			-- game.print("eligibile stop found")
		end
	end

	local key,value = next(non_exclusive_stops) ---get lowest value in non_exclusive_stops, if it exists
	---prioritize exclusive stops if they are present, even for trains without Exclusive_Delivery_Mode
	if next(exclusive_stops) then return exclusive_stops
	elseif not next(exclusive_stops) and train.Exclusive_Delivery_Mode == true then return nil
	---prioritize stations that handle the most items it has
	elseif value then return value
	elseif next(eligible_stops) then return eligible_stops
    else return nil
	end
end


---@param same_net {Train_Stops}
---@param train Trains
---@return eligibile_stops? {Train_Stops}
---@return imaginary_cargo_per_stop? {}
local function pickup(same_net, train)
	local imaginary_cargo_per_stop = {}
	local eligible_stops = {} -- stops that look for at least one cargo
	local non_exclusive_stops = {} --stops that only have some matches (array of tables, arranged by how many items that stop does not handle)
	local exclusive_stops = {} --stops that have all matches
	for _, stop_lua in pairs(same_net) do
		local num_matches = 0
		local train_stop = global.Train_Stops[stop_lua.unit_number]
		imaginary_cargo_per_stop[train_stop.ID] = {Cargo = {},Fluid_Cargo={}}
		if stop_lua.valid ~= true then
			goto SKIP
		end
		--generally cheaper to do liquid cargo first, as there are fewer elements
		for fluid_cargo, v in pairs(train.Imaginary_Fluid_Cargo) do
			local signal = train_stop.Signals.Fluid_Signals[fluid_cargo]
			if signal then
				local test = signal.amount
				if test <= 0 then
					local s_index = train.Train.front_stock.surface_index
					global.Surfaces[s_index].Supply_Stops_by_Signal.fluid[fluid_cargo][train_stop.ID] = nil
					goto SKIP
				end
				if train_stop.Imaginary_Cargo_In_Transit.Fluid_Cargo[fluid_cargo] then
					test = signal.amount + train_stop.Imaginary_Cargo_In_Transit.Fluid_Cargo[fluid_cargo]
				end

				if test > 0 and test >= math.abs(v) then
					num_matches = num_matches + 1
					imaginary_cargo_per_stop[train_stop.ID].Fluid_Cargo[fluid_cargo] = -1
				elseif train.Exclusive_Delivery_Mode == true then
					--skip checking more
					goto SKIP
				end
			else -- signal not found
				local s_index = train.Train.front_stock.surface_index
				global.Surfaces[s_index].Supply_Stops_by_Signal.fluid[fluid_cargo][train_stop.ID] = nil
			end
		end

		for cargo, v in pairs(train.Imaginary_Cargo) do
			local signal = train_stop.Signals.Item_Signals[cargo]
			if signal then
				local test = signal.amount
				if test <= 0 then
					local s_index = train.Train.front_stock.surface_index
					global.Surfaces[s_index].Supply_Stops_by_Signal.item[cargo][train_stop.ID] = nil
					goto SKIP
				end
				if train_stop.Imaginary_Cargo_In_Transit.Cargo[cargo] then
					test = signal.amount + train_stop.Imaginary_Cargo_In_Transit.Cargo[cargo]
				end

				if test > 0 and test >= math.abs(v) then
					num_matches = num_matches + 1
					imaginary_cargo_per_stop[train_stop.ID].Cargo[cargo] = -1
				elseif train.Exclusive_Delivery_Mode == true then
					--skip checking more
					goto SKIP
				end
			else -- signal not found
				local s_index = train.Train.front_stock.surface_index
				global.Surfaces[s_index].Supply_Stops_by_Signal.item[cargo][train_stop.ID] = nil
			end
		end
		::SKIP::
		local cargo_size = table_size(train.Imaginary_Fluid_Cargo) + table_size(train.Imaginary_Cargo)
		if num_matches == cargo_size then
			table.insert(exclusive_stops, train_stop)
			-- game.print("exclusive stop found")
		end
		if num_matches > 1 then
			local index = cargo_size - num_matches
			if not non_exclusive_stops[index] then
				non_exclusive_stops[index] = {}
			end
			table.insert(non_exclusive_stops[index], train_stop)
			-- game.print("non exclusive stop found")
		end
		if num_matches == 1 then
			table.insert(eligible_stops, train_stop)
			-- game.print("eligibile stop found")
		end
	end

	local key,value = next(non_exclusive_stops) ---get lowest value in non_exclusive_stops, if it exists
	---prioritize exclusive stops if they are present, even for trains without Exclusive_Delivery_Mode
	if next(exclusive_stops) then return exclusive_stops, imaginary_cargo_per_stop
	elseif not next(exclusive_stops) and train.Exclusive_Delivery_Mode == true then return nil, nil
	---prioritize stations that handle the most items it has
	elseif value then return value, imaginary_cargo_per_stop
	elseif next(eligible_stops) then return eligible_stops, imaginary_cargo_per_stop
    else return nil, nil
	end
end


---@param same_net {Train_Stops}
---@return eligibile_stops? {Train_Stops}
local function refuel_delivery(same_net)
	local stops = {}
	for _, stop_lua in pairs(same_net) do
		if stop_lua.valid == true then
			local train_station = global.Train_Stops[stop_lua.unit_number]
			table.insert(stops, train_station)
		end
	end
	return stops
end

---@param stop Train_Stop
---@return boolean
-- chech if stop still has space available
local function not_limited(stop)
	--a delivery is still active while train is at the stop
	local trains_at_stop = stop.trains_count + global.Train_Stops[stop.unit_number].Trains_On_Way
	local st = stop.get_stopped_train()
	if st ~= nil then
		local stopped_train = global.Trains[st.id]
		if stopped_train.Has_Delivery or stopped_train.Has_Pickup or stopped_train.Refueling then
			--don't double count trains with a delivery that are stopped at the station
			trains_at_stop = trains_at_stop - 1
		end
	end
	if trains_at_stop < stop.trains_limit then
		return true
	else
		return false
	end
end


---@param train_id uint
---@param type int
---@return eligibile_stops? {Train_Stops}
---@return imaginary_cargo_per_stop? {} - only for type == 2 (pickup)
---DOES NOT CONSIDER DISABLED STOPS
local function get_eligibile_stops(train_id, type)
	local train = global.Trains[train_id]
	local train_lua = train.Train
	if train_lua.valid == nil then return nil end

	--train & stop in same surface
	local same_surface = {}
	if type == 1 then
		local search_space = {}
		for key in pairs(train.Fluid_Cargo) do
			search_space = set_union(search_space, global.Surfaces[train_lua.front_stock.surface_index].Demand_Stops_by_Signal.fluid[key])
		end
		for key in pairs(train.Cargo) do
			search_space = set_union(search_space, global.Surfaces[train_lua.front_stock.surface_index].Demand_Stops_by_Signal.item[key])
		end
		same_surface = set_intersection(search_space, global.Surfaces[train_lua.front_stock.surface_index].Demand_Stops)
	elseif type == 2 then
		local search_space = {}
		for key in pairs(train.Imaginary_Fluid_Cargo) do
			search_space = set_union(search_space, global.Surfaces[train_lua.front_stock.surface_index].Supply_Stops_by_Signal.fluid[key])
		end
		for key in pairs(train.Imaginary_Cargo) do
			search_space = set_union(search_space, global.Surfaces[train_lua.front_stock.surface_index].Supply_Stops_by_Signal.item[key])
		end
		same_surface = set_intersection(search_space, global.Surfaces[train_lua.front_stock.surface_index].Supply_Stops)
	elseif type == 3 then
		same_surface = global.Surfaces[train_lua.front_stock.surface_index].Refuel_Stops
	else --failsafe
		same_surface = global.Surfaces[train_lua.front_stock.surface_index].Train_Stops
	end
	if not next(same_surface) then return nil end

	local same_net = {} --train & stop in same network
	for id, stop in pairs(same_surface) do
		if stop.valid == true and train.Last_Station_ID ~= stop.unit_number then
			if type == 1 and same_network(train.Network_Supply, global.Train_Stops[stop.unit_number].Network_Demand) == true then
				if not_limited(stop) == true then
					same_net[id] = stop
				end
			elseif type == 2 and same_network(train.Network_Pickup, global.Train_Stops[stop.unit_number].Network_Supply) == true then
				if not_limited(stop) == true then
					same_net[id] = stop
				end
			elseif type == 3 and same_network(train.Network_Refuel, global.Train_Stops[stop.unit_number].Network_Refuel) == true then
				if not_limited(stop) == true then
					same_net[id] = stop
				end
			end
		end
	end
	if not next(same_net) then return nil end

	if type == 1 then
		return standard_delivery(same_net, train)
	elseif type == 2 then
		return pickup(same_net, train)
	elseif type == 3 then
		return refuel_delivery(same_net)
	end
end

---@param train_id uint
---@param position? uint
---@param type? int
function attempt_delivery(train_id, position, type)
	if not global.Trains[train_id] then return end
	local train_lua = global.Trains[train_id].Train
	if train_lua.valid ~= true then return end
	type = type or 1
	if type == 1 and not next(global.Trains[train_id].Cargo) and not next(global.Trains[train_id].Fluid_Cargo) then return end
	local eligible_stops
	local imaginary_cargo_per_stop
	eligible_stops, imaginary_cargo_per_stop = get_eligibile_stops(train_id, type)

	--- no eligible stops
	if eligible_stops == nil then return false end

	--- 1 eligible stop
	local best_stop = eligible_stops[1]
	if #eligible_stops > 1 then
		if train_lua.front_stock.valid == true then
			best_stop = get_closest_distance(train_lua.front_stock, eligible_stops)
			-- game.print("the best stop is: "..best_stop.Train_Stop.backer_name)
		end
	end

	position = position or train_lua.schedule.current
	local immediately = true
	local check = false
	if type == 3 then
		check = add_stop_to_schedule(train_lua, best_stop.Train_Stop, nil, position, immediately)
	elseif position > #train_lua.schedule.records then
		check = add_stop_to_schedule(train_lua, best_stop.Train_Stop, train_lua.schedule.records[1].wait_conditions, position, immediately)
	else
		check = add_stop_to_schedule(train_lua, best_stop.Train_Stop, train_lua.schedule.records[position].wait_conditions, position, immediately)
	end
	if check == true then
		new_delivery(train_id, best_stop.Train_Stop.unit_number, type, imaginary_cargo_per_stop)
	end
	return check
end


---@param train_id uint
---@param stop_id uint
---@param type int
---@param imaginary_cargo_per_stop? {}
function new_delivery(train_id, stop_id, type, imaginary_cargo_per_stop)
	local delivery_id = game.tick
	--anti id collision
	while global.Deliveries[delivery_id] do
		delivery_id = delivery_id + 1
	end

	global.Deliveries[delivery_id] = {
		Delivery_ID = delivery_id,
		Surface_Index = global.Train_Stops[stop_id].Train_Stop.surface_index,
		Train_ID = train_id,
		Destination_Train_Stop_ID = stop_id,
		Tick_Started = game.tick,
		Tick_Ended = nil,
		Type = type,
		On_Way = true,
		Active = true
	}
	local delivery = global.Deliveries[delivery_id]
	local train = global.Trains[train_id]
	local train_stop = global.Train_Stops[stop_id]

	if type == 1 then
		global.Deliveries[delivery_id].Cargo_In_Transit = {Cargo = global.Trains[train_id].Cargo, Fluid_Cargo = global.Trains[train_id].Fluid_Cargo}

		for cargo, v in pairs(train.Cargo) do
			if not train_stop.Cargo_In_Transit.Cargo[cargo] then
				train_stop.Cargo_In_Transit.Cargo[cargo] = 0
			end
			train_stop.Cargo_In_Transit.Cargo[cargo] = train_stop.Cargo_In_Transit.Cargo[cargo] + v
		end

		for fluid_cargo, v in pairs(train.Fluid_Cargo) do
			if not train_stop.Cargo_In_Transit.Fluid_Cargo[fluid_cargo] then
				train_stop.Cargo_In_Transit.Fluid_Cargo[fluid_cargo] = 0
			end
			train_stop.Cargo_In_Transit.Fluid_Cargo[fluid_cargo] = train_stop.Cargo_In_Transit.Fluid_Cargo[fluid_cargo] + v
		end
		-- no longer registered once it has an active delivery
		train.Registered_For_Delivery = false
		train.Has_Delivery = true
		train.Delivery_ID = delivery_id
		global.Surfaces[train_stop.Train_Stop.surface_index].Deliveries[delivery_id] = delivery
		global.Train_Stops[train_stop.Train_Stop.unit_number].Active_Deliveries[delivery_id] = delivery
		global.Train_Stops[train_stop.Train_Stop.unit_number].Trains_On_Way = global.Train_Stops[train_stop.Train_Stop.unit_number].Trains_On_Way + 1

	elseif type == 2 then
		for cargo, v in pairs(imaginary_cargo_per_stop[stop_id].Cargo) do
			if not train_stop.Imaginary_Cargo_In_Transit.Cargo[cargo] then
				train_stop.Imaginary_Cargo_In_Transit.Cargo[cargo] = 0
			end
			train_stop.Imaginary_Cargo_In_Transit.Cargo[cargo] = train_stop.Imaginary_Cargo_In_Transit.Cargo[cargo] + v
		end

		for fluid_cargo, v in pairs(imaginary_cargo_per_stop[stop_id].Fluid_Cargo) do
			if not train_stop.Imaginary_Cargo_In_Transit.Fluid_Cargo[fluid_cargo] then
				train_stop.Imaginary_Cargo_In_Transit.Fluid_Cargo[fluid_cargo] = 0
			end
			train_stop.Imaginary_Cargo_In_Transit.Fluid_Cargo[fluid_cargo] = train_stop.Imaginary_Cargo_In_Transit.Fluid_Cargo[fluid_cargo] + v
		end
		global.Deliveries[delivery_id].Cargo_In_Transit = {Cargo = train_stop.Imaginary_Cargo_In_Transit.Cargo, Fluid_Cargo = train_stop.Imaginary_Cargo_In_Transit.Fluid_Cargo}

		-- no longer registered once it has an active delivery
		train.Registered_For_Pickup = false
		train.Has_Pickup = true
		train.Delivery_ID = delivery_id
		global.Surfaces[train_stop.Train_Stop.surface_index].Deliveries[delivery_id] = delivery
		global.Train_Stops[train_stop.Train_Stop.unit_number].Active_Deliveries[delivery_id] = delivery
		global.Train_Stops[train_stop.Train_Stop.unit_number].Trains_On_Way = global.Train_Stops[train_stop.Train_Stop.unit_number].Trains_On_Way + 1

	elseif type == 3 then
		-- no longer registered once it has an active delivery
		train.Registered_For_Refueling = false
		train.Refueling = true
		train.Delivery_ID = delivery_id
		global.Surfaces[train_stop.Train_Stop.surface_index].Deliveries[delivery_id] = delivery
		global.Train_Stops[train_stop.Train_Stop.unit_number].Active_Deliveries[delivery_id] = delivery
		global.Train_Stops[train_stop.Train_Stop.unit_number].Trains_On_Way = global.Train_Stops[train_stop.Train_Stop.unit_number].Trains_On_Way + 1
	end

	return delivery_id
end


---@param Delivery_ID uint
---@param type int
function deactivate_delivery(Delivery_ID)
	local delivery = global.Deliveries[Delivery_ID]
	if not delivery then return end
	local train_stop = global.Train_Stops[delivery.Destination_Train_Stop_ID]
	local train = global.Trains[delivery.Train_ID]
	local type = delivery.Type

	delivery.On_Way = false
	delivery.Active = false
	delivery.Tick_Ended = game.tick

	if train_stop then
		if type == 1 then
			for cargo, amount in pairs(delivery.Cargo_In_Transit.Cargo) do
				train_stop.Cargo_In_Transit.Cargo[cargo] = train_stop.Cargo_In_Transit.Cargo[cargo] - amount
			end
			for fluid_cargo, amount in pairs(delivery.Cargo_In_Transit.Fluid_Cargo) do
				train_stop.Cargo_In_Transit.Fluid_Cargo[fluid_cargo] = train_stop.Cargo_In_Transit.Fluid_Cargo[fluid_cargo] - amount
			end
		elseif type == 2 then
			for cargo, amount in pairs(delivery.Cargo_In_Transit.Cargo) do
				train_stop.Imaginary_Cargo_In_Transit.Cargo[cargo] = train_stop.Imaginary_Cargo_In_Transit.Cargo[cargo] - amount
			end
			for fluid_cargo, amount in pairs(delivery.Cargo_In_Transit.Fluid_Cargo) do
				train_stop.Imaginary_Cargo_In_Transit.Fluid_Cargo[fluid_cargo] = train_stop.Imaginary_Cargo_In_Transit.Fluid_Cargo[fluid_cargo] - amount
			end
		end
		train_stop.Active_Deliveries[delivery.Delivery_ID] = nil
		train_stop.Trains_On_Way = train_stop.Trains_On_Way - 1
	end
	if train and train.Delivery_ID ~= nil and train.Delivery_ID == Delivery_ID then
		if type == 1 then
			reset_delivery_flags(train.ID)
		elseif type == 2 then
			reset_pickup_flags(train.ID)
		elseif type == 3 then
			reset_refuel_flags(train.ID)
		end
	end
end