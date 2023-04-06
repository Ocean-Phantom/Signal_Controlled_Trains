local function on_train_changed_state(event)
	if settings.global.SCT_enable_control.value == false then return end
	if not (event.train and event.train.valid) then return end
	local train_id = event.train.id
	local Train = global.Trains[train_id]
	--reset any delivery stuff if player changed the train schedule
	if event.train.state == defines.train_state.manual_control then
		if not Train then return end
		deactivate_delivery(Train.Delivery_ID)
	end
	if event.train.state == defines.train_state.wait_station then
		on_train_arrived(event)
	end
	if event.old_state == defines.train_state.wait_station then
		on_train_depart(event)
	end
end


local function setup_globals()
	global.Surfaces = global.Surfaces or {}
	global.Deliveries = global.Deliveries or {}
	global.Trains = global.Trains or {}
	global.Train_Stops = global.Train_Stops or {}
	global.Poll = global.Poll or {Tick = 1}
	global.Settings = {
		delivery_timeout_ticks = settings.global.SCT_delivery_timeout_time.value * 60,
		delivery_removal_ticks = settings.global.SCT_delivery_removal_time.value * 60,
		Trains_per_poll = settings.global.SCT_Trains_per_poll.value,
		Train_Stops_per_poll = settings.global.SCT_Train_Stops_per_poll.value
	}
	if not next(global.Surfaces) then
		update_surface_list()
	end
	-- global.GamePrototypes = {items={},fluids={}}
	-- for item, _ in pairs(game.item_prototypes) do
	-- 	global.GamePrototypes.items[item] = -1
	-- end
	-- for fluid, _ in pairs(game.fluid_prototypes) do
	-- 	global.GamePrototypes.fluids[fluid] = -1
	-- end
end

local function on_train_schedule_changed(event)
	--reset any delivery stuff if player changed the train schedule
	if event.player_index ~= nil then
		local train_id = event.train.id
		local Train = global.Trains[train_id]
		if event.train.state == defines.train_state.manual_control then
			if not Train then return end
			deactivate_delivery(Train.Delivery_ID)
		end
	end
end

---@param event any
local function on_train_created(event)
	if event.train then
		add_train(event.train)
	end
end


local function on_built(event)
	if event.created_entity and event.created_entity.type == "train-stop" then
		add_train_stop(event.created_entity)
	elseif event.entity and event.entity.type == "train-stop" then
		add_train_stop(event.entity)
	elseif event.destination and event.destination.type == "train-stop" then
		add_train_stop(event.destination)
	end
end

local function on_entity_renamed(event)
	if event.entity.type == "train-stop" then
		local train_stop = event.entity
		if train_stop.backer_name:find("%[virtual%-signal=refuel%-signal]") then
            if not global.Surfaces[train_stop.surface_index].Refuel_Stops[train_stop.unit_number] then
                global.Surfaces[train_stop.surface_index].Refuel_Stops[train_stop.unit_number] = train_stop
            end
        elseif event.old_name:find("%[virtual%-signal=refuel%-signal]") then
            global.Surfaces[train_stop.surface_index].Refuel_Stops[train_stop.unit_number] = nil
        end
	end
end

local function on_nth_tick()
	if global.Settings.Trains_per_poll > 0 and global.Poll.Tick % 2 == 1 then
		poll_trains()
	end
	if global.Settings.Trains_per_poll == 0 or global.Poll.Tick % 2 == 0 then
		poll_train_stops()
	end
    global.Poll.Tick = global.Poll.Tick + 1
end

local function on_tick(event)
	poll_deliveries()
end

local function on_setting_changed(event)
	global.Settings = {
		delivery_timeout_ticks = settings.global.SCT_delivery_timeout_time.value * 60,
		delivery_removal_ticks = settings.global.SCT_delivery_removal_time.value * 60,
		Trains_per_poll = settings.global.SCT_Trains_per_poll.value,
		Train_Stops_per_poll = settings.global.SCT_Train_Stops_per_poll.value
	}

	--ensure delivery can't be removed before it times out
	if settings.global.SCT_delivery_timeout_time.value >= settings.global.SCT_delivery_removal_time.value then
		local new_setting = settings.global.SCT_delivery_removal_time
		new_setting.value = settings.global.SCT_delivery_timeout_time.value + 1
		settings.global.SCT_delivery_removal_time = new_setting
	end
end

local function on_surface_created(event)
	add_surface(event.surface)
end
local function on_surface_deleted(event)
	delete_surface(event.surface_index)
end

script.on_init(setup_globals)
script.on_configuration_changed(setup_globals)
-- script.on_load(function()
-- end)

script.on_event(defines.events.on_tick, on_tick)
script.on_nth_tick(settings.global.SCT_ticks_between_polls.value, on_nth_tick)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_setting_changed)

script.on_event(defines.events.on_surface_created, on_surface_created)
script.on_event(defines.events.on_surface_imported, on_surface_created)
script.on_event(defines.events.on_surface_deleted, on_surface_deleted)
script.on_event(defines.events.on_surface_cleared, on_surface_deleted)

script.on_event(defines.events.on_train_created, on_train_created)
script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
script.on_event(defines.events.on_train_schedule_changed, on_train_schedule_changed)
local train_stop_filter = {{filter = "type", type = "train-stop"}}
script.on_event(defines.events.on_built_entity, on_built, train_stop_filter)
script.on_event(defines.events.on_entity_cloned, on_built, train_stop_filter)
script.on_event(defines.events.script_raised_built, on_built, train_stop_filter)
script.on_event(defines.events.script_raised_revive, on_built, train_stop_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, train_stop_filter)
-- script.on_event(defines.events.on_cancelled_deconstruction, on_cancel_deconstruction, train_stop_filter)
-- script.on_event(defines.events.on_marked_for_deconstruction, on_marked_deconstruction, train_stop_filter)
script.on_event(defines.events.on_entity_renamed, on_entity_renamed)
-- script.on_event(defines.events.on_settings_pasted, on_entity_settings_pasted)

local function on_cancel_deconstruction()
end

local function on_marked_deconstruction()
end