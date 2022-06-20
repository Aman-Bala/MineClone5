--MCmobs v0.4
--maikerumine
--made for MC like Survival game
--License for code WTFPL and otherwise stated in readmes

local S = minetest.get_translator("extra_mobs")

mobs:register_mob("extra_mobs:glow_squid",{
    type = "animal",
    spawn_class = "water",
    can_despawn = true,
    passive = true,
    hp_min = 10,
    hp_max = 10,
    xp_min = 1,
    xp_max = 3,
    armor = 100,
    rotate = 270,
    tilt_swim = true,
    -- FIXME: If the qlow squid is near the floor, it turns black
    collisionbox = {-0.4, 0.0, -0.4, 0.4, 0.9, 0.4},
    visual = "mesh",
    mesh = "extra_mobs_glow_squid.b3d",
    textures = {
        {"extra_mobs_glow_squid.png"}
    },
    sounds = {
	damage = {name="mobs_mc_squid_hurt", gain=0.3},
	death = {name="mobs_mc_squid_death", gain=0.4},
	flop = "mobs_mc_squid_flop",
	distance = 16,
    },
    animation = {
	    stand_start = 1,
	    stand_end = 60,
	    walk_start = 1,
	    walk_end = 60,
	    run_start = 1,
	    run_end = 60,
	},
    drops = {
	    {name = "extra_mobs:glow_ink_sac",
	    chance = 1,
	    min = 1,
	    max = 3,
	    looting = "common",},
	},
    visual_size = {x=3, y=3},
    makes_footstep_sound = false,
    swim = true,
    breathes_in_water = true,
    jump = false,
    view_range = 16,
    runaway = true,
    fear_height = 4,
    glow = minetest.LIGHT_MAX,
    do_custom = function(self, dtime)
        local glowSquidPos = self.object:get_pos()
        local chanceOfParticle = math.random(0, 2)
        if chanceOfParticle >= 1 then
            minetest.add_particle({
                pos = {x=glowSquidPos.x+math.random(-2,2)*math.random()/2,y=glowSquidPos.y+math.random(-1,2),z=glowSquidPos.z+math.random(-2,2)*math.random()/2},
                velocity = {x=math.random(-0.25,0.25), y=math.random(-0.25,0.25), z=math.random(-0.25,0.25)},
                acceleration = {x=math.random(-0.5,0.5), y=math.random(-0.5,0.5), z=math.random(-0.5,0.5)},
                expirationtime = math.random(),
                size = 1.5 + math.random(),
                collisiondetection = true,
                vertical = false,
                texture = "glint"..math.random(1, 4)..".png",
                glow = minetest.LIGHT_MAX,
            })
        end
    end
})

-- spawning

local water = mobs_mc.spawn_height.water + 1
mobs:spawn_specific(
"extra_mobs:glow_squid", 
"overworld", 
"water",
{
"Mesa",
"FlowerForest",
"Swampland",
"Taiga",
"ExtremeHills",
"Jungle",
"Savanna",
"BirchForest",
"MegaSpruceTaiga",
"MegaTaiga",
"ExtremeHills+",
"Forest",
"Plains",
"Desert",
"ColdTaiga",
"MushroomIsland",
"IcePlainsSpikes",
"SunflowerPlains",
"IcePlains",
"RoofedForest",
"ExtremeHills+_snowtop",
"MesaPlateauFM_grasstop",
"JungleEdgeM",
"ExtremeHillsM",
"JungleM",
"BirchForestM",
"MesaPlateauF",
"MesaPlateauFM",
"MesaPlateauF_grasstop",
"MesaBryce",
"JungleEdge",
"SavannaM",
"FlowerForest_beach",
"Forest_beach",
"StoneBeach",
"ColdTaiga_beach_water",
"Taiga_beach",
"Savanna_beach",
"Plains_beach",
"ExtremeHills_beach",
"ColdTaiga_beach",
"Swampland_shore",
"MushroomIslandShore",
"JungleM_shore",
"Jungle_shore",
"MesaPlateauFM_sandlevel",
"MesaPlateauF_sandlevel",
"MesaBryce_sandlevel",
"Mesa_sandlevel",
"RoofedForest_ocean",
"JungleEdgeM_ocean",
"BirchForestM_ocean",
"BirchForest_ocean",
"IcePlains_deep_ocean",
"Jungle_deep_ocean",
"Savanna_ocean",
"MesaPlateauF_ocean",
"ExtremeHillsM_deep_ocean",
"Savanna_deep_ocean",
"SunflowerPlains_ocean",
"Swampland_deep_ocean",
"Swampland_ocean",
"MegaSpruceTaiga_deep_ocean",
"ExtremeHillsM_ocean",
"JungleEdgeM_deep_ocean",
"SunflowerPlains_deep_ocean",
"BirchForest_deep_ocean",
"IcePlainsSpikes_ocean",
"Mesa_ocean",
"StoneBeach_ocean",
"Plains_deep_ocean",
"JungleEdge_deep_ocean",
"SavannaM_deep_ocean",
"Desert_deep_ocean",
"Mesa_deep_ocean",
"ColdTaiga_deep_ocean",
"Plains_ocean",
"MesaPlateauFM_ocean",
"Forest_deep_ocean",
"JungleM_deep_ocean",
"FlowerForest_deep_ocean",
"MushroomIsland_ocean",
"MegaTaiga_ocean",
"StoneBeach_deep_ocean",
"IcePlainsSpikes_deep_ocean",
"ColdTaiga_ocean",
"SavannaM_ocean",
"MesaPlateauF_deep_ocean",
"MesaBryce_deep_ocean",
"ExtremeHills+_deep_ocean",
"ExtremeHills_ocean",
"MushroomIsland_deep_ocean",
"Forest_ocean",
"MegaTaiga_deep_ocean",
"JungleEdge_ocean",
"MesaBryce_ocean",
"MegaSpruceTaiga_ocean",
"ExtremeHills+_ocean",
"Jungle_ocean",
"RoofedForest_deep_ocean",
"IcePlains_ocean",
"FlowerForest_ocean",
"ExtremeHills_deep_ocean",
"MesaPlateauFM_deep_ocean",
"Desert_ocean",
"Taiga_ocean",
"BirchForestM_deep_ocean",
"Taiga_deep_ocean",
"JungleM_ocean",
"FlowerForest_underground",
"JungleEdge_underground",
"StoneBeach_underground",
"MesaBryce_underground",
"Mesa_underground",
"RoofedForest_underground",
"Jungle_underground",
"Swampland_underground",
"MushroomIsland_underground",
"BirchForest_underground",
"Plains_underground",
"MesaPlateauF_underground",
"ExtremeHills_underground",
"MegaSpruceTaiga_underground",
"BirchForestM_underground",
"SavannaM_underground",
"MesaPlateauFM_underground",
"Desert_underground",
"Savanna_underground",
"Forest_underground",
"SunflowerPlains_underground",
"ColdTaiga_underground",
"IcePlains_underground",
"IcePlainsSpikes_underground",
"MegaTaiga_underground",
"Taiga_underground",
"ExtremeHills+_underground",
"JungleM_underground",
"ExtremeHillsM_underground",
"JungleEdgeM_underground",
},
0, 
minetest.LIGHT_MAX+1, 
30, 
10000, 
3, 
water-16, 
water)

-- spawn egg
mobs:register_egg("extra_mobs:glow_squid", S("Glow Squid"), "extra_mobs_spawn_icon_glow_squid.png", 0)

-- dropped item (used to craft glowing itemframe)

minetest.register_craftitem("extra_mobs:glow_ink_sac", {
	description = S("Glow Ink Sac"),
	_doc_items_longdesc = S("Use it to craft the Glow Item Frame."),
	_doc_items_usagehelp = S("Use the Glow Ink Sac and the normal Item Frame to craft the Glow Item Frame."),
	inventory_image = "extra_mobs_glow_ink_sac.png",
	groups = { craftitem = 1 },
})
