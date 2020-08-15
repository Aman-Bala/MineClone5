local S = minetest.get_translator("mcl_portals")

-- Parameters

-- Portal frame sizes
local FRAME_SIZE_X_MIN = 4
local FRAME_SIZE_Y_MIN = 5
local FRAME_SIZE_X_MAX = 23
local FRAME_SIZE_Y_MAX = 23

local TELEPORT_DELAY = 4 -- seconds before teleporting in Nether portal
local TELEPORT_COOLOFF = 4 -- after object was teleported, for this many seconds it won't teleported again
local DESTINATION_EXPIRES = 60 * 1000000 -- cached destination expires after this number of microseconds have passed without using the same origin portal

local mg_name = minetest.get_mapgen_setting("mg_name")
local superflat = mg_name == "flat" and minetest.get_mapgen_setting("mcl_superflat_classic") == "true"
local overworld_ground_level
if superflat then
	overworld_ground_level = mcl_vars.mg_bedrock_overworld_max + 5
elseif mg_name == "flat" then
	overworld_ground_level = 2 + (minetest.get_mapgen_setting("mgflat_ground_level") or 8)
else
	overworld_ground_level = nil
end

-- Table of objects (including players) which recently teleported by a
-- Nether portal. Those objects have a brief cooloff period before they
-- can teleport again. This prevents annoying back-and-forth teleportation.
local portal_cooloff = {}
local teleporting_objects={}

-- Functions

-- Destroy portal if pos (portal frame or portal node) got destroyed
function mcl_portals.destroy_nether_portal(pos)
	-- Deactivate Nether portal
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local nn, orientation = node.name, node.param2
	minetest.log("action", "[mcl_portal] Destroying Nether portal at " .. minetest.pos_to_string(pos) .. "(" .. nn .. ")")
	local obsidian = nn == "mcl_core:obsidian" 
	local has_meta = minetest.string_to_pos(meta:get_string("portal_frame1"))
	meta:set_string("portal_frame1", "")
	meta:set_string("portal_frame2", "")
	meta:set_string("portal_target", "")
	meta:set_string("portal_time", "")
	if obsidian then
		if minetest.get_node({x = pos.x - 1, y = pos.y, z = pos.z}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x - 1, y = pos.y, z = pos.z})
		end
		if minetest.get_node({x = pos.x + 1, y = pos.y, z = pos.z}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x + 1, y = pos.y, z = pos.z})
		end
		if minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x, y = pos.y - 1, z = pos.z})
		end
		if minetest.get_node({x = pos.x, y = pos.y + 1, z = pos.z}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x, y = pos.y + 1, z = pos.z})
		end
		if minetest.get_node({x = pos.x, y = pos.y, z = pos.z - 1}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x, y = pos.y, z = pos.z - 1})
		end
		if minetest.get_node({x = pos.x, y = pos.y, z = pos.z + 1}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x, y = pos.y, z = pos.z + 1})
		end
		return
	end
	if not has_meta then
		return
	end
	if orientation == 1 then
		if minetest.get_node({x = pos.x, y = pos.y, z = pos.z - 1}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x, y = pos.y, z = pos.z - 1})
		end
		if minetest.get_node({x = pos.x, y = pos.y, z = pos.z + 1}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x, y = pos.y, z = pos.z + 1})
		end
	else
		if minetest.get_node({x = pos.x - 1, y = pos.y, z = pos.z}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x - 1, y = pos.y, z = pos.z})
		end
		if minetest.get_node({x = pos.x + 1, y = pos.y, z = pos.z}).name == "mcl_portals:portal" then
			minetest.remove_node({x = pos.x + 1, y = pos.y, z = pos.z})
		end
	end
	if minetest.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name == "mcl_portals:portal" then
		minetest.remove_node({x = pos.x, y = pos.y - 1, z = pos.z})
	end
	if minetest.get_node({x = pos.x, y = pos.y + 1, z = pos.z}).name == "mcl_portals:portal" then
		minetest.remove_node({x = pos.x, y = pos.y + 1, z = pos.z})
	end
end

minetest.register_node("mcl_portals:portal", {
	description = S("Nether Portal"),
	_doc_items_longdesc = S("A Nether portal teleports creatures and objects to the hot and dangerous Nether dimension (and back!). Enter at your own risk!"),
	_doc_items_usagehelp = S("Stand in the portal for a moment to activate the teleportation. Entering a Nether portal for the first time will also create a new portal in the other dimension. If a Nether portal has been built in the Nether, it will lead to the Overworld. A Nether portal is destroyed if the any of the obsidian which surrounds it is destroyed, or if it was caught in an explosion."),

	tiles = {
		"blank.png",
		"blank.png",
		"blank.png",
		"blank.png",
		{
			name = "mcl_portals_portal.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 0.5,
			},
		},
		{
			name = "mcl_portals_portal.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 0.5,
			},
		},
	},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	use_texture_alpha = true,
	walkable = false,
	diggable = false,
	pointable = false,
	buildable_to = false,
	is_ground_content = false,
	drop = "",
	light_source = 11,
	post_effect_color = {a = 180, r = 51, g = 7, b = 89},
	alpha = 192,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.1,  0.5, 0.5, 0.1},
		},
	},
	groups = {portal=1, not_in_creative_inventory = 1},
	on_destruct = mcl_portals.destroy_nether_portal,

	_mcl_hardness = -1,
	_mcl_blast_resistance = 0,
})

local function find_target_y(x, y, z, y_min, y_max)
	local y_org = y
	local node = minetest.get_node_or_nil({x = x, y = y, z = z})
	-- minetest.chat_send_all("fty x="..tostring(x).." y=" .. tostring(y).." z=" .. tostring(z) .. "node.name="..node.name )
	
	if node == nil then
		-- minetest.chat_send_all("node=nil, y ret")
		return y
	end
	-- minetest.chat_send_all("1) y=" .. tostring(y).. "node.name="..node.name )
	while node.name ~= "air" and y < y_max do
		-- minetest.chat_send_all(" y=" .. tostring(y).. "node.name="..node.name )
		y = y + 1
		node = minetest.get_node_or_nil({x = x, y = y, z = z})
		if node == nil then
			-- minetest.chat_send_all("node=nil, y ret")
			return y_org
		end
	end
	if y == y_max then -- try reverse direction who knows what they built there...
		while node.name ~= "air" and y > y_min do
			-- minetest.chat_send_all(" y=" .. tostring(y).. "node.name="..node.name )
			y = y - 1
			node = minetest.get_node_or_nil({x = x, y = y, z = z})
			if node == nil then
				-- minetest.chat_send_all("node=nil, y ret")
				return y_org
			end
		end
	end
	-- minetest.chat_send_all("2) y=" .. tostring(y).. "node.name="..node.name )
	while node.name == "air" and y > y_min do
		-- minetest.chat_send_all(" y=" .. tostring(y).. "node.name="..node.name )
		y = y - 1
		node = minetest.get_node_or_nil({x = x, y = y, z = z})
		if node == nil then
			-- minetest.chat_send_all("node=nil, y ret")
			return y_org
		end
	end
	if y == y_min then
		return y_org
	end
	return y
end

local function find_nether_target_y(x, z)
	local y = math.random(mcl_vars.mg_lava_nether_max + 1, mcl_vars.mg_bedrock_nether_top_min - 26) -- Search start
	if mg_name == "flat" then
		y = mcl_vars.mg_flat_nether_floor + 1
	end
	return find_target_y(x, y, z, mcl_vars.mg_nether_min+25, mcl_vars.mg_nether_max-25) + 2
end

local function find_overworld_target_y(x, z)
	local y = overworld_ground_level or math.random(mcl_vars.mg_overworld_min + 40, mcl_vars.mg_overworld_min + 96)
	return find_target_y(x, y, z, mcl_vars.mg_overworld_min+25, mcl_vars.mg_overworld_max_official-25) + 2
end

local function ecb_setup_target_portal(blockpos, action, calls_remaining, param)
-- param.: srcx, srcy, srcz, dstx, dsty, dstz, srcdim, ax1, ay1, az1, ax2, ay2, az2
	-- minetest.chat_send_all("ecb bp="..minetest.pos_to_string(blockpos).."; action="..tostring(action).."; calls_rem="..tostring(calls_remaining))
	if calls_remaining <= 0 and action ~= minetest.EMERGE_CANCELLED and action ~= minetest.EMERGE_ERRORED then
		minetest.log("verbose", "[mcl_portal] Area for destination Nether portal emerged!")
		-- minetest.chat_send_all(tostring(param.ax1) .. "," .. tostring(param.ay1) .. "," .. tostring(param.az1) .. ") - (" .. tostring(param.ax2) .. "," .. tostring(param.ay2) .. "," .. tostring(param.az2) .. ")")
		-- return
		local portal_nodes = minetest.find_nodes_in_area({x = param.ax1, y = param.ay1, z = param.az1}, {x = param.ax2, y = param.ay2, z = param.az2}, "mcl_portals:portal")
		-- local portal_nodes = {}
		local src_pos = {x = param.srcx, y = param.srcy, z = param.srcz}
		local dst_pos = {x = param.dstx, y = param.dsty, z = param.dstz}
		local meta = minetest.get_meta(src_pos)
		local p1 = minetest.string_to_pos(meta:get_string("portal_frame1"))
		local p2 = minetest.string_to_pos(meta:get_string("portal_frame2"))
		local portal_pos = {}
		if portal_nodes and #portal_nodes > 0 then
			-- Found some portal(s), use nearest:
			portal_pos = {x = portal_nodes[1].x, y = portal_nodes[1].y, z = portal_nodes[1].z}
			local nearest_distance = vector.distance(dst_pos, portal_pos)
			if #portal_nodes > 1 then
				for n = 2, #portal_nodes do
					local distance = vector.distance(dst_pos, portal_nodes[n])
					if distance < nearest_distance then
						portal_pos = {x = portal_nodes[n].x, y = portal_nodes[n].y, z = portal_nodes[n].z}
						nearest_distance = distance
					end
				end
			end
			-- now we have portal_pos
		else
			-- Need to build arrival portal:
			local orientation = 0
			local width = math.abs(p2.z - p1.z) + math.abs(p2.x - p1.x) + 1
			local height = math.abs(p2.y - p1.y) + 1
			if p1.x == p2.x then
				orinetation = 1
			end
			if param.srcdim == "overworld" then
				dst_pos.y = find_nether_target_y(dst_pos.x, dst_pos.z)
			else
				dst_pos.y = find_overworld_target_y(dst_pos.x, dst_pos.z)
			end
			portal_pos = mcl_portals.build_nether_portal(dst_pos, width, height, orientation)
		end

		local time_str = tostring(minetest.get_us_time())
		local target = minetest.pos_to_string(portal_pos)

		for x = p1.x, p2.x do
			for y = p1.y, p2.y do
				for z = p1.z, p2.z do
					meta = minetest.get_meta({x = x, y = y, z = z})
					meta:set_string("portal_target", target)
					meta:set_string("portal_time", time_str)
				end
			end
		end
	end
end

local function find_or_create_portal(src_pos)
	local current_dimension = mcl_worlds.pos_to_dimension(src_pos)
	local x, y, z, y_min, y_max = 0, 0, 0, 0, 0
	if current_dimension == "nether" then
		x = mcl_worlds.nether_to_overworld(src_pos.x)
		z = mcl_worlds.nether_to_overworld(src_pos.z)
		y = math.max(math.min(y - mcl_vars.mg_nether_min + mcl_vars.mg_overworld_min, mcl_vars.mg_overworld_max_official), mcl_vars.mg_overworld_min)
		y_min = mcl_vars.mg_overworld_min
		y_max = mcl_vars.mg_overworld_max_official
	else -- overworld:
		x = src_pos.x / 8
		z = src_pos.z / 8
		y = math.max(math.min(y - mcl_vars.mg_overworld_min + mcl_vars.mg_nether_min, mcl_vars.mg_nether_max), mcl_vars.mg_nether_min)
		y_min = mcl_vars.mg_bedrock_nether_bottom_min
		y_max = mcl_vars.mg_bedrock_nether_top_max
	end
	local pos1 = {x = x - 32, y = y_min + 2, z = z - 32}
	local pos2 = {x = x + 32, y = y_max - 2, z = z + 32}
	minetest.emerge_area(pos1, pos2, ecb_setup_target_portal, {srcx=src_pos.x, srcy=src_pos.y, srcz=src_pos.z, dstx=x, dsty=y, dstz=z, srcdim=current_dimension, ax1=pos1.x, ay1=pos1.y, az1=pos1.z, ax2=pos2.x, ay2=pos2.y, az2=pos2.z})
end

local function available_for_nether_portal(p)
	local nn = minetest.get_node(p).name
	local obsidian = nn == "mcl_core:obsidian"
	if nn ~= "air" and nn ~= "mcl_portals:portal" and minetest.get_item_group(nn, "fire") ~= 1 then
		return false, obsidian
	end
	return true, obsidian
end

local function light_frame(x1, y1, z1, x2, y2, z2, build_frame)
	local build_frame = build_frame or false
	local orientation = 0
	if x1 == x2 then
		orientation = 1
	end
	local disperse = 50
	local pass = 1
	while true do
		local protection = false

		for x = x1 - 1 + orientation, x2 + 1 - orientation do
			for z = z1 - orientation, z2 + orientation do
				for y = y1 - 1, y2 + 1 do
					local set_meta = true
					local frame = (x < x1) or (x > x2) or (y < y1) or (y > y2) or (z < z1) or (z > z2)
					if frame then
						if build_frame then
							if pass == 1 then
								if minetest.is_protected({x = x, y = y, z = z}, "") then
									protection = true
									x1 = x1 + math.random(0, disperse) - math.random(0, disperse)
									z1 = z1 + math.random(0, disperse) - math.random(0, disperse)
									disperse = disperse + math.random(25, 177)
									if disperse > 5000 then
										return nil
									end
									break
								end
							else
								minetest.set_node({x = x, y = y, z = z}, {name = "mcl_core:obsidian"})
							end
						else
							set_meta = minetest.get_node({x = x, y = y, z = z}).name == "mcl_core:obsidian"
						end
					else
						if not build_frame or pass == 2 then
							minetest.set_node({x = x, y = y, z = z}, {name = "mcl_portals:portal", param2 = orientation})
						end
					end
					if set_meta and not build_frame or pass == 2 then
						local meta = minetest.get_meta({x = x, y = y, z = z})
						-- Portal frame corners
						meta:set_string("portal_frame1", minetest.pos_to_string({x = x1, y = y1, z = z1}))
						meta:set_string("portal_frame2", minetest.pos_to_string({x = x2, y = y2, z = z2}))
						-- Portal target coordinates
						meta:set_string("portal_target", "")
						-- meta:set_string("portal_time", tostring(minetest.get_us_time()))
						meta:set_string("portal_time", tostring(0))
					end
				end
				if protection then
					break
				end
			end
			if protection then
				break
			end
		end
		if build_frame == false or pass == 2 then
			break
		end
		if build_frame and not protection and pass == 1 then
			pass = 2
		end
	end
	return {x = x1, y = y1, z = z1}
end

--Build arrival portal
function mcl_portals.build_nether_portal(pos, width, height, orientation)
	local height = height or FRAME_SIZE_Y_MIN - 2
	local width = width or FRAME_SIZE_X_MIN - 2
	local orientation = orientation or math.random(0, 1)

	if orientation == 0 then
		minetest.load_area({x = pos.x - 3, y = pos.y - 1, z = pos.z - width * 2}, {x = pos.x + width + 2, y = pos.y + height + 2, z = pos.z + width * 2})
	else
		minetest.load_area({x = pos.x - width * 2, y = pos.y - 1, z = pos.z - 3}, {x = pos.x + width * 2, y = pos.y + height + 2, z = pos.z + width + 2})
	end

	pos = light_frame(pos.x, pos.y, pos.z, pos.x + (1 - orientation) * (width - 1), pos.y + height - 1, pos.z + orientation * (width - 1), true)

	if orientation == 0 then
		for z = pos.z - width * 2, pos.z + width * 2 do
			if z ~= pos.z then
				for x = pos.x - 3, pos.x + width + 2 do
					for y = pos.y - 1, pos.y + height + 2 do
						if minetest.is_protected({x = x, y = y, z = z}, "") then
							if minetest.registered_nodes[minetest.get_node({x = x, y = y, z = z}).name].is_ground_content and not minetest.is_protected({x = x, y = y, z = z}, "") then
								minetest.remove_node({x = x, y = y, z = z})
							end
						end
					end
				end
			end
		end
	else
		for x = pos.x - width * 2, pos.x + width * 2 do
			if x ~= pos.x then
				for z = pos.z - 3, pos.z + width + 2 do
					for y = pos.y - 1, pos.y + height + 2 do
						if minetest.registered_nodes[minetest.get_node({x = x, y = y, z = z}).name].is_ground_content and not minetest.is_protected({x = x, y = y, z = z}, "") then
							minetest.remove_node({x = x, y = y, z = z})
						end
					end
				end
			end
		end
	end

	minetest.log("action", "[mcl_portal] Destination Nether portal generated at "..minetest.pos_to_string(pos).."!")

	return pos
end

-- Attempts to light a Nether portal at pos
-- Pos can be any of the inner part.
-- The frame MUST be filled only with air or any fire, which will be replaced with Nether portal blocks.
-- If no Nether portal can be lit, nothing happens.
-- Returns number of portals created (0, 1 or 2)
function mcl_portals.light_nether_portal(pos)
	-- Only allow to make portals in Overworld and Nether
	local dim = mcl_worlds.pos_to_dimension(pos)
	if dim ~= "overworld" and dim ~= "nether" then
		return 0
	end
	if not available_for_nether_portal(pos) then
		return 0
	end
	local y1 = pos.y
	local height = 1
	-- Decrease y1 to portal bottom:
	while true do
		y1 = y1 - 1
		local available, obsidian = available_for_nether_portal({x = pos.x, y = y1, z = pos.z})
		if available then
			height = height + 1
			if height > FRAME_SIZE_Y_MAX - 2 then
				return 0
			end
		elseif not obsidian then
			return 0
		else
			y1 = y1 + 1
			break
		end
	end
	local y2 = pos.y
	-- Increase y2 to portal top:
	while true do
		y2 = y2 + 1
		local available, obsidian = available_for_nether_portal({x = pos.x, y = y2, z = pos.z})
		if available then
			height = height + 1
			if height > FRAME_SIZE_Y_MAX - 2 then
				return 0
			end
		elseif not obsidian then
			return 0
		else
			if height < FRAME_SIZE_Y_MIN - 2 then
				return 0
			end
			y2 = y2 - 1
			break
		end
	end

	-- In some cases there might be 2 crossing frames and I have strong desire to light them both, so this is a counter for returning:
	local lit_portals = 0

	-- We have y1, y2 and height, check horizontal parts:

	-- Orientation 0:

	local okay_x = true
	local width = 1
	local x1 = pos.x
	local x2 = pos.x
	-- Decrease x1 to left side of the portal:
	while okay_x do
		x1 = x1 - 1
		local available, obsidian = available_for_nether_portal({x = x1, y = pos.y, z = pos.z})
		if available then
			width = width + 1
			if width > FRAME_SIZE_X_MAX - 2 then
				okay_x = false
				break
			end
		elseif not obsidian then
			okay_x = false
			break
		else
			x1 = x1 + 1
			break
		end
	end
	while okay_x do
		x2 = x2 + 1
		local available, obsidian = available_for_nether_portal({x = x2, y = pos.y, z = pos.z})
		if available then
			width = width + 1
			if width > FRAME_SIZE_X_MAX - 2 then
				okay_x = false
				break
			end
		elseif not obsidian then
			okay_x = false
			break
		else
			if width < FRAME_SIZE_X_MIN - 2 then
				okay_x = false
			end
			x2 = x2 - 1
			break
		end
	end
	-- We found some frame but in fact only a cross, need to check it all:
	if okay_x then
		for x = x1, x2 do
			if x ~= pos.x then
				for y = y1, y2 do
					if y ~= pos.y then
						local available, obsidian = available_for_nether_portal({x = x, y = y, z = pos.z})
						if not available then
							okay_x = false
							break
						end
					end
				end
			end
		end
	end
	-- Check horizontal parts of obsidian frame:
	if okay_x then
		for x = x1, x2 do
			if x ~= pos.x then
				if minetest.get_node({x = x, y = y1 - 1, z = pos.z}).name ~= "mcl_core:obsidian" or minetest.get_node({x = x, y = y2 + 1, z = pos.z}).name ~= "mcl_core:obsidian" then
					okay_x = false
					break
				end
			end
		end
	end
	-- Check vertical parts of obsidian frame:
	if okay_x then
		for y = y1, y2 do
			if y ~= pos.y then
				if minetest.get_node({x = x1 - 1, y = y, z = pos.z}).name ~= "mcl_core:obsidian" or minetest.get_node({x = x2 + 1, y = y, z = pos.z}).name ~= "mcl_core:obsidian" then
					okay_x = false
					break
				end
			end
		end
	end
	if okay_x then
		light_frame(x1, y1, pos.z, x2, y2, pos.z, false, false, dim)
		lit_portals = lit_portals + 1
	end

	-- Orientation 1:

	local width = 1
	local z1 = pos.z
	local z2 = pos.z
	-- Decrease z1 to left side of the portal:
	while true do
		z1 = z1 - 1
		local available, obsidian = available_for_nether_portal({x = pos.x, y = pos.y, z = z1})
		if available then
			width = width + 1
			if width > FRAME_SIZE_X_MAX - 2 then
				return lit_portals
			end
		elseif not obsidian then
			return lit_portals
		else
			z1 = z1 + 1
			break
		end
	end
	while true do
		z2 = z2 + 1
		local available, obsidian = available_for_nether_portal({x = pos.x, y = pos.y, z = z2})
		if available then
			width = width + 1
			if width > FRAME_SIZE_X_MAX - 2 then
				return lit_portals
			end
		elseif not obsidian then
				return lit_portals
		else
			if width < FRAME_SIZE_X_MIN - 2 then
				return lit_portals
			end
			z2 = z2 - 1
			break
		end
	end
	-- We found some frame but in fact only a cross, need to check it all:
	for z = z1, z2 do
		if z ~= pos.z then
			for y = y1, y2 do
				if y ~= pos.y then
					local available, obsidian = available_for_nether_portal({x = pos.x, y = y, z = z})
					if not available then
						return lit_portals
					end
				end
			end
		end
	end
	-- Check horizontal parts of obsidian frame:
	for z = z1, z2 do
		if z ~= pos.z then
			if minetest.get_node({x = pos.x, y = y1 - 1, z = z}).name ~= "mcl_core:obsidian" or minetest.get_node({x = pos.x, y = y2 + 1, z = z}).name ~= "mcl_core:obsidian" then
				return lit_portals
			end
		end
	end
	-- Check vertical parts of obsidian frame:
	for y = y1, y2 do
		if y ~= pos.y then
			if minetest.get_node({x = pos.x, y = y, z = z1 - 1}).name ~= "mcl_core:obsidian" or minetest.get_node({x = pos.x, y = y, z = z2 + 1}).name ~= "mcl_core:obsidian" then
				return lit_portals
			end
		end
	end
	light_frame(pos.x, y1, z1, pos.x, y2, z2, false, false, dim)

	lit_portals = lit_portals + 1

	return lit_portals
end

-- teleportation cooloff for some seconds, to prevent back-and-forth teleportation
local function teleport_cooloff(obj)
	minetest.after(TELEPORT_COOLOFF, function(o)
		portal_cooloff[o] = false
	end, obj)
end

-- teleport function
local function teleport(obj, pos)
	if (not obj:get_luaentity()) and  (not obj:is_player()) then
		return
	end

	local objpos = obj:get_pos()
	if objpos == nil then
		return
	end

	if portal_cooloff[obj] then
		return
	end
	-- If player stands, player is at ca. something+0.5
	-- which might cause precision problems, so we used ceil.
	objpos.y = math.ceil(objpos.y)

	if minetest.get_node(objpos).name ~= "mcl_portals:portal" then
		return
	end

	local meta = minetest.get_meta(pos)
	local delta_time = minetest.get_us_time() - tonumber(meta:get_string("portal_time"))
	local target = minetest.string_to_pos(meta:get_string("portal_target"))
	if delta_time > DESTINATION_EXPIRES or target == nil then
		-- ares still not emerged - retry after a second
		return minetest.after(1, teleport, obj, pos)
	end

	-- Teleport
	obj:set_pos(target)
	if obj:is_player() then
		mcl_worlds.dimension_change(obj, mcl_worlds.pos_to_dimension(target))
		minetest.sound_play("mcl_portals_teleport", {pos=target, gain=0.5, max_hear_distance = 16}, true)
	end

	-- Enable teleportation cooloff for some seconds, to prevent back-and-forth teleportation
	teleport_cooloff(obj)
	portal_cooloff[obj] = true
	if obj:is_player() then
		local name = obj:get_player_name()
		minetest.log("action", "[mcl_portal] "..name.." teleported to Nether portal at "..minetest.pos_to_string(target)..".")
	end
end


local function prepare_target(pos)
	local meta, us_time = minetest.get_meta(pos), minetest.get_us_time()
	local portal_time = tonumber(meta:get_string("portal_time")) or 0
	local delta_time_us = us_time - portal_time
	local pos1, pos2 = minetest.string_to_pos(meta:get_string("portal_frame1")), minetest.string_to_pos(meta:get_string("portal_frame2"))
	if delta_time_us <= DESTINATION_EXPIRES then
		-- destination point must be still cached according to https://minecraft.gamepedia.com/Nether_portal
		for x = pos1.x, pos2.x do
			for y = pos1.y, pos2.y do
				for z = pos1.z, pos2.z do
					minetest.get_meta({x = x, y = y, z = z}):set_string("portal_time", tostring(us_time))
				end
			end
		end
		return
	end

	-- No cached destination point.
	find_or_create_portal(pos)
end

function mcl_portals.teleport_through_nether_portal(obj, portal_pos)
	-- Prevent quick back-and-forth teleportation
	if portal_cooloff[obj] then
		return
	end
	prepare_target(portal_pos)
	minetest.after(TELEPORT_DELAY, teleport, obj, portal_pos)
end

minetest.register_abm({
	label = "Nether portal teleportation and particles",
	nodenames = {"mcl_portals:portal"},
	interval = 2,
	chance = 1,
	action = function(pos, node)
		minetest.add_particlespawner({
			amount = 32,
			time = 3,
			minpos = {x = pos.x - 0.25, y = pos.y - 0.25, z = pos.z - 0.25},
			maxpos = {x = pos.x + 0.25, y = pos.y + 0.25, z = pos.z + 0.25},
			minvel = {x = -0.8, y = -0.8, z = -0.8},
			maxvel = {x = 0.8, y = 0.8, z = 0.8},
			minacc = {x = 0, y = 0, z = 0},
			maxacc = {x = 0, y = 0, z = 0},
			minexptime = 0.5,
			maxexptime = 1,
			minsize = 1,
			maxsize = 2,
			collisiondetection = false,
			texture = "mcl_particles_teleport.png",
		})
		for _,obj in ipairs(minetest.get_objects_inside_radius(pos,1)) do		--maikerumine added for objects to travel
			local lua_entity = obj:get_luaentity() --maikerumine added for objects to travel
			if (obj:is_player() or lua_entity) and (not teleporting_objects[obj] or minetest.get_us_time()-teleporting_objects[obj] > 10000000) then
				teleporting_objects[obj]=minetest.get_us_time()
				mcl_portals.teleport_through_nether_portal(obj, pos)
			end
		end
	end,
})


--[[ ITEM OVERRIDES ]]

local longdesc = minetest.registered_nodes["mcl_core:obsidian"]._doc_items_longdesc
longdesc = longdesc .. "\n" .. S("Obsidian is also used as the frame of Nether portals.")
local usagehelp = S("To open a Nether portal, place an upright frame of obsidian with a width of 4 blocks and a height of 5 blocks, leaving only air in the center. After placing this frame, light a fire in the obsidian frame. Nether portals only work in the Overworld and the Nether.")

minetest.override_item("mcl_core:obsidian", {
	_doc_items_longdesc = longdesc,
	_doc_items_usagehelp = usagehelp,
	on_destruct = mcl_portals.destroy_nether_portal,
	_on_ignite = function(user, pointed_thing)
		local pos = {x = pointed_thing.under.x, y = pointed_thing.under.y, z = pointed_thing.under.z}
		local portals_counter = 0
		-- Check empty spaces around obsidian and light all frames found:
		for x = pos.x-1, pos.x+1 do
			for y = pos.y-1, pos.y+1 do
				for z = pos.z-1, pos.z+1 do
					local portals_placed = mcl_portals.light_nether_portal({x = x, y = y, z = z})
					if portals_placed > 0 then
						minetest.log("action", "[mcl_portal] Nether portal activated at "..minetest.pos_to_string(pos)..".")
						portals_counter = portals_counter + portals_placed
						break
					end
				end
				if portals_counter > 0 then
					break
				end
			end
			if portals_counter > 0 then
				break
			end
		end
		if portals_counter > 0 then
			if minetest.get_modpath("doc") then
				doc.mark_entry_as_revealed(user:get_player_name(), "nodes", "mcl_portals:portal")

				-- Achievement for finishing a Nether portal TO the Nether
				local dim = mcl_worlds.pos_to_dimension(pos)
				if minetest.get_modpath("awards") and dim ~= "nether" and user:is_player() then
					awards.unlock(user:get_player_name(), "mcl:buildNetherPortal")
				end
			end
			return true
		else
			return false
		end
	end,
})

