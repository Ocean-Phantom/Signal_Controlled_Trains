function update_surface_list()
	local sur = game.surfaces
	for _, surface in pairs(game.surfaces) do
		add_surface(surface, nil)
	end
end

---@param surface? LuaSurface
---@param surface_index? uint
function add_surface(surface, surface_index)
	if surface ~= nil and surface_index == nil then
		surface_index = surface.index
	elseif surface == nil and surface_index ~= nil then
		surface = game.surfaces[surface_index]
	end
	if surface == nil or surface_index == nil then return end

	if not global.Surfaces[surface_index] then
		global.Surfaces[surface_index] = {
			Surface = surface or {},
			Train_Stops = surface.get_train_stops() or {},
			Demand_Stops = {},
			Supply_Stops = {},
			Demand_Stops_by_Signal = {item = {}, fluid = {}},
			Supply_Stops_by_Signal = {item = {}, fluid = {}},
			Refuel_Stops = {},
			Deliveries = {}
		}
		for _, stop in pairs(global.Surfaces[surface_index].Train_Stops) do
			add_train_stop(stop)
		end
		for item, _ in pairs(game.item_prototypes) do
			global.Surfaces[surface_index].Demand_Stops_by_Signal.item[item] = {}
			global.Surfaces[surface_index].Supply_Stops_by_Signal.item[item] = {}
		end
		for fluid, _ in pairs(game.fluid_prototypes) do
			global.Surfaces[surface_index].Demand_Stops_by_Signal.fluid[fluid] = {}
			global.Surfaces[surface_index].Supply_Stops_by_Signal.fluid[fluid] = {}
		end
	end
end

---@param index uint
function delete_surface(index)
	for id, train_stop in pairs(global.Surfaces[index].Train_Stops) do
		global.Train_Stops[id] = nil
	end
	global.Surfaces[index] = nil
end