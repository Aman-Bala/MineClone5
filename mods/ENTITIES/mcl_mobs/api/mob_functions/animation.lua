local math_pi     = math.pi
local math_floor  = math.floor
local HALF_PI     = math_pi/2



local vector_distance = vector.distance
local vector_new      = vector.new

local minetest_dir_to_yaw = minetest.dir_to_yaw


-- simple degrees calculation
local degrees = function(yaw)
    return(yaw*180.0/math_pi)
end

-- set defined animation
mobs.set_mob_animation = function(self, anim, fixed_frame)

	if not self.animation or not anim then
		return
	end

	if self.state == "die" and anim ~= "die" and anim ~= "stand" then
		return
	end


	if (not self.animation[anim .. "_start"] or not self.animation[anim .. "_end"]) then		
		return
	end

	--animations break if they are constantly set
	--so we put this return gate to check if it is
	--already at the animation we are trying to implement
	if self.current_animation == anim then
		return
	end

	local a_start = self.animation[anim .. "_start"]
	local a_end

	if fixed_frame then
		a_end = a_start
	else
		a_end = self.animation[anim .. "_end"]
	end

	self.object:set_animation({
		x = a_start,
		y = a_end},
		self.animation[anim .. "_speed"] or self.animation.speed_normal or 15,
		0, self.animation[anim .. "_loop"] ~= false)


	self.current_animation = anim	
end




mobs.death_effect = function(pos, yaw, collisionbox, rotate)
	local min, max
	if collisionbox then
		min = {x=collisionbox[1], y=collisionbox[2], z=collisionbox[3]}
		max = {x=collisionbox[4], y=collisionbox[5], z=collisionbox[6]}
	else
		min = { x = -0.5, y = 0, z = -0.5 }
		max = { x = 0.5, y = 0.5, z = 0.5 }
	end
	if rotate then
		min = vector.rotate(min, {x=0, y=yaw, z=math_pi/2})
		max = vector.rotate(max, {x=0, y=yaw, z=math_pi/2})
		min, max = vector.sort(min, max)
		min = vector.multiply(min, 0.5)
		max = vector.multiply(max, 0.5)
	end

	minetest_add_particlespawner({
		amount = 50,
		time = 0.001,
		minpos = vector.add(pos, min),
		maxpos = vector.add(pos, max),
		minvel = vector_new(-5,-5,-5),
		maxvel = vector_new(5,5,5),
		minexptime = 1.1,
		maxexptime = 1.5,
		minsize = 1,
		maxsize = 2,
		collisiondetection = false,
		vertical = false,
		texture = "mcl_particles_mob_death.png^[colorize:#000000:255",
	})

	minetest_sound_play("mcl_mobs_mob_poof", {
		pos = pos,
		gain = 1.0,
		max_hear_distance = 8,
	}, true)
end


--this allows auto facedir rotation while making it so mobs
--don't look like wet noodles flopping around
mobs.movement_rotation_lock = function(self)
	
	local current_engine_yaw = self.object:get_yaw()
	local current_lua_yaw = self.yaw

	if current_engine_yaw > math.pi * 2 then
		current_engine_yaw = current_engine_yaw - (math.pi * 2)
	end

	if math.abs(current_engine_yaw - current_lua_yaw) <= 0.05 and self.object:get_properties().automatic_face_movement_dir then
		self.object:set_properties{automatic_face_movement_dir = false}
	elseif math.abs(current_engine_yaw - current_lua_yaw) > 0.05 and self.object:get_properties().automatic_face_movement_dir == false then
		self.object:set_properties{automatic_face_movement_dir = self.rotate}
	end
end


local calculate_pitch = function(self)
	local pos  = self.object:get_pos()
	local pos2 = self.old_pos

	if pos == nil or pos2 == nil then
		return false
	end

    return(minetest_dir_to_yaw(vector_new(vector_distance(vector_new(pos.x,0,pos.z),vector_new(pos2.x,0,pos2.z)),0,pos.y - pos2.y)) + HALF_PI)
end

--this is a helper function used to make mobs pitch rotation dynamically flow when flying/swimming
mobs.set_dynamic_pitch = function(self)
	local pitch = calculate_pitch(self)

	if not pitch then
		return
	end

	local current_rotation = self.object:get_rotation()

	current_rotation.x = pitch

	self.object:set_rotation(current_rotation)

	self.pitch_switch = "dynamic"
end

--this is a helper function used to make mobs pitch rotation reset when flying/swimming
mobs.set_static_pitch = function(self)

	if self.pitch_switch == "static" then
		return
	end

	local current_rotation = self.object:get_rotation()

	current_rotation.x = 0
	current_rotation.z = 0

	self.object:set_rotation(current_rotation)
	self.pitch_switchfdas = "static"
end