---@param train_stop LuaEntity
function add_train_stop(train_stop)
	if train_stop.valid == false then return end
	local id = train_stop.unit_number
	if not global.Train_Stops[id] then
		global.Train_Stops[id] = {
			Train_Stop = train_stop or {},
			ID = id,
			Trains_On_Way = 0,
			Network_Demand = 0,
			Network_Refuel = 0,
			Network_Supply = 0,
			Signals = {
				Item_Signals = {},
				Fluid_Signals = {},
				Virtual_Signals = {}
			},
			Cargo_In_Transit = {
				Cargo = {},
				Fluid_Cargo = {}
			},
			Imaginary_Cargo_In_Transit = {
				Cargo = {},
				Fluid_Cargo = {}
			},
			Active_Deliveries = {}
		}
		global.Surfaces[train_stop.surface_index].Train_Stops[id] = train_stop
		if train_stop.backer_name:find("%[virtual%-signal=refuel%-signal]") then
            if not global.Surfaces[train_stop.surface_index].Refuel_Stops[id] then
                global.Surfaces[train_stop.surface_index].Refuel_Stops[id] = train_stop
            end
		end
	end
end


---@param stop_id uint
local function update_train_stop_networks(stop_id)
	local train_stop = global.Train_Stops[stop_id]
	if train_stop.Signals.Virtual_Signals[SKIP_SIGNAL] then
		train_stop.Network_Demand = train_stop.Signals.Virtual_Signals[SKIP_SIGNAL]
	else --signal not found or equal 0
		train_stop.Network_Demand = 0
	end

	if train_stop.Signals.Virtual_Signals[DEPOT_SIGNAL] then
		train_stop.Network_Supply = train_stop.Signals.Virtual_Signals[DEPOT_SIGNAL]
	else --signal not found or equal 0
		train_stop.Network_Supply = 0
	end

	if train_stop.Signals.Virtual_Signals[FUEL_SIGNAL] then
		train_stop.Network_Refuel = train_stop.Signals.Virtual_Signals[FUEL_SIGNAL]
	else --signal not found or equal 0
		train_stop.Network_Refuel = 0
	end
	-- update_global_network(train_stop)
end


---@param stop_id? uint
---@param train_stop? LuaEntity
---one parameter must be valid. updates list of signals stored in train stop table, later updates the network
function update_train_stop_signals(stop_id, train_stop)
	if not stop_id and train_stop then
		stop_id = train_stop.unit_number
	end
	if stop_id and not train_stop then
		train_stop = global.Train_Stops[stop_id]
	end
	if not stop_id or not train_stop then return end

	if train_stop ~= nil and global.Train_Stops[stop_id] then
		---clear old signals
		global.Train_Stops[stop_id].Signals = {
			Item_Signals = {},
			Fluid_Signals = {},
			Virtual_Signals = {}
		}
		local signal_list = train_stop.get_merged_signals()
		if signal_list ~= nil then
			for _, s in pairs(signal_list) do
				if s.signal.type == 'item' then
					global.Train_Stops[stop_id].Signals.Item_Signals[s.signal.name] = s.count
				elseif s.signal.type == 'fluid' then
					global.Train_Stops[stop_id].Signals.Fluid_Signals[s.signal.name] = s.count
				elseif s.signal.type == 'virtual' then
					global.Train_Stops[stop_id].Signals.Virtual_Signals[s.signal.name] = s.count
				end
			end
		end

		update_train_stop_networks(stop_id)
		-- global.Train_Stops[stop_id].Tick_Last_Checked = game.tick
	end
end
