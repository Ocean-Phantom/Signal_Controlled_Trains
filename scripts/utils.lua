local get_distance = require("__flib__.position").distance

---@param entity0 LuaEntity
---@param entity1 LuaEntity
---return distance(int) or false if entities are on different surfaces
local function get_dist(entity0, entity1)
	local surface0 = entity0.surface.index
	local surface1 = entity1.surface.index
	return (surface0 == surface1 and get_distance(entity0.position, entity1.position))
end

---@param Network0 int
---@param Network1 int
---@return boolean
function same_network(Network0, Network1)
	if bit32.band(Network0,Network1) ~= 0 then return true
	else return false end
end

---@param front_stock (LuaEntity)
---@param eligible_stops {int}
---@return LuaEntity or nil
---get stop closest to the train
function get_closest_distance(front_stock, eligible_stops)
		local best_stop = eligible_stops[1]
		local best_distance = get_dist(front_stock, best_stop.Train_Stop)
		local test
		for _, stop in ipairs(eligible_stops) do
			if best_stop ~= stop then
				test = get_dist(front_stock, stop.Train_Stop)
				if test ~= false and test < best_distance then
					best_distance = test
					best_stop = stop
				end
			end
		end
		return best_stop
end

---comment
---@param table any
---@return table
function new_set(table)
	local set = {}
	for key in pairs(table) do set[key] = true end
	return set
end

---comment
---@param set1 any
---@param set2 any
---@return table
function set_union(set1,set2)
	local union = {}
	for k, v in pairs(set1) do
		union[k] = v
	end
	for k, v in pairs(set2) do
		union[k] = v
	end
	return union
end

---will keep the values of set 2
---@param set1 any
---@param set2 any
---@return table
function set_intersection(set1,set2)
	local intersection = {}
	for k in pairs(set1) do
		intersection[k] = set2[k]
	end
	return intersection
end