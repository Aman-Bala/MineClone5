mcl_worlds = {}

-- For a given position, returns a 2-tuple:
-- 1st return value: true if pos is in void
-- 2nd return value: true if it is in the deadly part of the void
function mcl_worlds.is_in_void(pos)
	local void =
		not ((pos.y < mcl_vars.mg_overworld_max and pos.y > mcl_vars.mg_overworld_min) or
		(pos.y < mcl_vars.mg_nether_max and pos.y > mcl_vars.mg_nether_min) or
		(pos.y < mcl_vars.mg_end_max and pos.y > mcl_vars.mg_end_min))

	local void_deadly = false
	local deadly_tolerance = 64 -- the player must be this many nodes “deep” into the void to be damaged
	if void then
		-- Overworld → Void → End → Void → Nether → Void
		if pos.y < mcl_vars.mg_overworld_min and pos.y > mcl_vars.mg_end_max then
			void_deadly = pos.y < mcl_vars.mg_overworld_min - deadly_tolerance
		elseif pos.y < mcl_vars.mg_end_min and pos.y > mcl_vars.mg_nether_max then
			-- The void between End and Nether. Like usual, but here, the void
			-- *above* the Nether also has a small tolerance area, so player
			-- can fly above the Nether without getting hurt instantly.
			void_deadly = (pos.y < mcl_vars.mg_end_min - deadly_tolerance) and (pos.y > mcl_vars.mg_nether_max + deadly_tolerance)
		elseif pos.y < mcl_vars.mg_nether_min then
			void_deadly = pos.y < mcl_vars.mg_nether_min - deadly_tolerance
		end
	end
	return void, void_deadly
end

-- Takes an Y coordinate as input and returns:
-- 1) The corresponding Minecraft layer (can be nil if void)
-- 2) The corresponding Minecraft dimension ("overworld", "nether" or "end") or "void" if it is in the void
-- If the Y coordinate is not located in any dimension, it will return:
--     nil, "void"
function mcl_worlds.y_to_layer(y)
       if y >= mcl_vars.mg_overworld_min then
               return y - mcl_vars.mg_overworld_min, "overworld"
       elseif y >= mcl_vars.mg_nether_min and y <= mcl_vars.mg_nether_max then
               return y - mcl_vars.mg_nether_min, "nether"
       elseif y >= mcl_vars.mg_end_min and y <= mcl_vars.mg_end_max then
               return y - mcl_vars.mg_end_min, "end"
       else
               return nil, "void"
       end
end

-- Takes a pos and returns the dimension it belongs to (same as above)
function mcl_worlds.pos_to_dimension(pos)
	local _, dim = mcl_worlds.y_to_layer(pos.y)
	return dim
end

-- Takes a Minecraft layer and a “dimension” name
-- and returns the corresponding Y coordinate for
-- MineClone 2.
-- mc_dimension is one of "overworld", "nether", "end" (default: "overworld").
function mcl_worlds.layer_to_y(layer, mc_dimension)
       if mc_dimension == "overworld" or mc_dimension == nil then
               return layer + mcl_vars.mg_overworld_min
       elseif mc_dimension == "nether" then
               return layer + mcl_vars.mg_nether_min
       elseif mc_dimension == "end" then
               return layer + mcl_vars.mg_end_min
       end
end

-- Takes a position and returns true if this position can have weather
function mcl_worlds.has_weather(pos)
       -- Weather in the Overworld and the high part of the void below
       return pos.y <= mcl_vars.mg_overworld_max and pos.y >= mcl_vars.mg_overworld_min - 64
end

-- Takes a position (pos) and returns true if compasses are working here
function mcl_worlds.compass_works(pos)
       -- It doesn't work in Nether and the End, but it works in the Overworld and in the high part of the void below
       local _, dim = mcl_worlds.y_to_layer(pos.y)
       if dim == "nether" or dim == "end" then
               return false
       elseif dim == "void" then
               return pos.y <= mcl_vars.mg_overworld_max and pos.y >= mcl_vars.mg_overworld_min - 64
       else
               return true
       end
end

-- Takes a position (pos) and returns true if clocks are working here
mcl_worlds.clock_works = mcl_worlds.compass_works

function mcl_worlds.nether_to_overworld(x)
    return 30912 - math.abs((x * 8 + 30912) % 123648 - 61824)
end

--------------- CALLBACKS ------------------
mcl_worlds.registered_on_dimension_change = {}

-- Register a callback function func(player, dimension).
-- It will be called whenever a player changes between dimensions.
-- The void counts as dimension.
-- * player: The player who changed the dimension
-- * dimension: The new dimension of the player ("overworld", "nether", "end", "void").
function mcl_worlds.register_on_dimension_change(func)
	table.insert(mcl_worlds.registered_on_dimension_change, func)
end

-- Playername-indexed table containig the name of the last known dimension the
-- player was in.
local last_dimension = {}

-- Notifies this mod about a dimension change of a player.
-- * player: Player who changed the dimension
-- * dimension: New dimension ("overworld", "nether", "end", "void")
function mcl_worlds.dimension_change(player, dimension)
	for i=1, #mcl_worlds.registered_on_dimension_change do
		mcl_worlds.registered_on_dimension_change[i](player, dimension)
		last_dimension[player:get_player_name()] = dimension
	end
end

----------------------- INTERNAL STUFF ----------------------

-- Update the dimension callbacks every DIM_UPDATE seconds
local DIM_UPDATE = 1
local dimtimer = 0

minetest.register_on_joinplayer(function(player)
	last_dimension[player:get_player_name()] = mcl_worlds.pos_to_dimension(player:get_pos())
end)

minetest.register_globalstep(function(dtime)
	-- regular updates based on iterval
	dimtimer = dimtimer + dtime;
	if dimtimer >= DIM_UPDATE then
		local players = minetest.get_connected_players()
		for p=1, #players do
			local dim = mcl_worlds.pos_to_dimension(players[p]:get_pos())
			local name = players[p]:get_player_name()
			if dim ~= last_dimension[name] then
				mcl_worlds.dimension_change(players[p], dim)
			end
		end
		dimtimer = 0
	end
end)

