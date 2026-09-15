if SERVER then return end

include("autorun/gstorms_api.lua")

local defaultResourcePack = {
	pack_name = "GStorms: Default Resource Pack",

	lighting_and_environment = {

		legacy_lighting = false,
	
		controls = {
			exposure_strength = 5.5,
			exposure_exponent = 0.35,
			contrast_strength = 0.1,
			tint_strength = 1.5,
			tint_control = 0.7,
			volumetric_strength = 0.1,
			night_darkness = 0.55,
			night_desaturate = 0.375
		},
	
		sunrise = {
			sky_colors = {default = {top = Color(168, 204, 241), bottom = Color(255, 192, 122)}, rain = {top = Color(39, 49, 56), bottom = Color(145, 138, 124)}},
			sun_colors = {default = Color(255, 229, 200), rain = Color(244, 255, 193)},
			fog = {
				default = {density = 0.75, fog_start = 1, fog_end = 45000},
				rain = {density = 0.75, fog_start = 1, fog_end = 45000},
				rain_clientside = {density = 0.85, fog_start = -1, fog_end = 7500}
			}
		},
	
		day = {
			sky_colors = {default = {top = Color(70, 146, 232), bottom = Color(206, 223, 227)}, rain = {top = Color(174, 180, 175), bottom = Color(124, 130, 134)}},
			sun_colors = {default = Color(255, 248, 235), rain = Color(246, 255, 232)},
			fog = {
				default = {density = 0.75, fog_start = 1, fog_end = 45000},
				rain = {density = 0.75, fog_start = 1, fog_end = 45000},
				rain_clientside = {density = 0.85, fog_start = -1, fog_end = 7500}
			}
		},
	
		sunset = {
			sky_colors = {default = {top = Color(92, 116, 198), bottom = Color(255, 160, 108)}, rain = {top = Color(177, 172, 168), bottom = Color(134, 122, 111)}},
			sun_colors = {default = Color(255, 225, 210), rain = Color(252, 224, 209)},
			fog = {
				default = {density = 0.75, fog_start = 1, fog_end = 45000},
				rain = {density = 0.75, fog_start = 1, fog_end = 45000},
				rain_clientside = {density = 0.85, fog_start = -1, fog_end = 7500}
			}
		},
	
		night = {
			sky_colors = {default = {top = Color(14, 16, 23), bottom = Color(31, 36, 45)}, rain = {top = Color(11, 13, 18), bottom = Color(20, 24, 30)}},
			sun_colors = {default = Color(197, 197, 197), rain = Color(180, 180, 180)},
			fog = {
				default = {density = 0.75, fog_start = 1, fog_end = 45000},
				rain = {density = 0.75, fog_start = 1, fog_end = 45000},
				rain_clientside = {density = 0.85, fog_start = -1, fog_end = 7500}
			}
		}
	
	},

	{
		key = "hurricane",
		material = "clouds_and_weather/cloud_3", material_flags = "smooth",
		shaded_color = {bright = Color(210, 215, 220), dark = Color(78, 80, 82)},
		rotation = {min = 255, max = 255},

		alpha_controls = {alpha_min = 225, alpha_max = 255, fade_in = 0.20, fade_out = 0.20},

		particle_parameters = {size_multiplier = 2, count_multiplier = 0.75, lifetime = 9},

		height = 0,
		fall_speed = 0,

		lifetime_override = true,
		blend_angle = false
	},

	{
		key = "mesocyclone",
		material = "clouds_and_weather/tornado_condensation_2", material_flags = "smooth",
		shaded_color = {bright = {min = Color(145, 148, 150), max = Color(172, 177, 182)}, dark = Color(83, 85, 87)},
		rotation = {min = 180, max = 180},

		alpha_controls = {alpha_min = 225, alpha_max = 255, fade_in = 0.20, fade_out = 0.20},

		particle_parameters = {size_multiplier = 2, count_multiplier = 1, lifetime = 9, size_random_multiplier = 2},

		height = -250,
		fall_speed = 0,

		lifetime_override = true,
		blend_angle = true
	},

	{
		key = "mesocyclone",
		material = "clouds_and_weather/wispy_smoke5", material_flags = "smooth",
		shaded_color = {bright = {min = Color(136, 139, 142), max = Color(146, 149, 154)}, dark = Color(107, 109, 109)},
		rotation = {min = 0, max = 360},
		requirements = {rmw_size = {min = 0, max = 600}},

		alpha_controls = {alpha_min = 175, alpha_max = 200, fade_in = 0.20, fade_out = 0.20},

		particle_parameters = {size_multiplier = 2.25, count_multiplier = 1, lifetime = 9, size_random_multiplier = 1.25},

		height = 500,
		fall_speed = 0,

		lifetime_override = true,
		blend_angle = true,
	},

	{
		key = "mesocyclone",
		material = "clouds_and_weather/tornado_condensation_1", material_flags = "smooth",
		shaded_color = {bright = {min = Color(172, 176, 181), max = Color(184, 188, 195)}, dark = Color(69, 70, 72)},
		rotation = {min = 180, max = 180},

		alpha_controls = {alpha_min = 255, alpha_max = 255, fade_in = 0.20, fade_out = 0.20},

		particle_parameters = {size_multiplier = 2.25, count_multiplier = 1, lifetime = 9},

		height = -1100,
		fall_speed = 0,

		lifetime_override = true,
		blend_angle = true
	},

	{
		key = "condensation",
		material = "clouds_and_weather/wispy_smoke4", material_flags = "smooth",
		shaded_color = {bright = Color(191, 196, 201), dark = Color(60, 61, 63)},
		rotation = {min = 0, max = 360},

		alpha_controls = {alpha_min = 200, alpha_max = 200, fade_in = 0.10, fade_out = 0.10},
		alpha_condensation = {windspeed = {min = 80, max = 110}, range = {min = 15, max = 35}, height = {min = 0.5, max = 1}, alpha_min_multiplier = 0, exponent = 1.5},

		particle_parameters = {size_multiplier = 2, count_multiplier = 1, lifetime = 0, max_size = 3000},

		offsets = {orbit_radius = 0, size = 100, orbit_radius_size_multiplier = 0.5},

		height = 0,
		fall_speed = 0,

		blend_angle = true,
	},
	
	{
		key = "condensation",
		material = "clouds_and_weather/tornado_condensation_3", material_flags = "smooth",
		shaded_color = {bright = Color(186, 190, 196), dark = Color(42, 42, 43)},
		rotation = {min = 0, max = 360},

		alpha_controls = {alpha_min = 120, alpha_max = 120, fade_in = 0.10, fade_out = 0.10},
		alpha_condensation = {windspeed = {min = 80, max = 110}, range = {min = 15, max = 35}, height = {min = 0.5, max = 1}, alpha_min_multiplier = 0, exponent = 1.5},

		particle_parameters = {size_multiplier = 2, count_multiplier = 1, lifetime = 0, max_size = 3000},

		offsets = {orbit_radius = 0, size = 100, orbit_radius_size_multiplier = 0.5},

		height = 0,
		fall_speed = 0,

		blend_angle = true,
	},

	{
		key = "subvortexCondensation",
		material = "clouds_and_weather/wispy_smoke4", material_flags = "smooth",
		shaded_color = {bright = Color(191, 196, 201), dark = Color(81, 83, 85)}, -- shaded_color or color here
		rotation = {min = 0, max = 360},

		alpha_controls = {alpha_min = 180, alpha_max = 180, fade_in = 0.10, fade_out = 0.10},
		alpha_windspeed = {windspeed_min = 80, windspeed_max = 160, alpha_min_multiplier = 0, alpha_max_multiplier = 1},

		particle_parameters = {size_multiplier = 2, count_multiplier = 1, lifetime = 0, max_size = 3000},

		offsets = {orbit_radius = 0, size = 100, orbit_radius_size_multiplier = 0.5},

		height = 0,
		fall_speed = 0,

		blend_angle = true,
	},

	{
		key = "subvortexCondensation",
		material = "clouds_and_weather/tornado_condensation_3", material_flags = "smooth",
		shaded_color = {bright = Color(186, 190, 196), dark = Color(67, 68, 70)},
		rotation = {min = 0, max = 360},

		alpha_controls = {alpha_min = 120, alpha_max = 120, fade_in = 0.10, fade_out = 0.10},
		alpha_windspeed = {windspeed_min = 80, windspeed_max = 160, alpha_min_multiplier = 0, alpha_max_multiplier = 1},

		particle_parameters = {size_multiplier = 2, count_multiplier = 1, lifetime = 0, max_size = 3000},

		offsets = {orbit_radius = 0, size = 100, orbit_radius_size_multiplier = 0.5},

		height = 0,
		fall_speed = 0,

		blend_angle = true,
	},

	{
		key = "dustdevil",
		material = "clouds_and_weather/gstorms_dust_devil_1", material_flags = "smooth",
		shaded_color = {bright = Color(90, 79, 72), dark = Color(73, 63, 56)},
		rotation = {min = 0, max = 0},

		alpha_controls = {alpha_min = 40, alpha_max = 50, fade_in = 0.05, fade_out = 0.10},

		particle_parameters = {size_multiplier = 4, count_multiplier = 1, lifetime = 0},

		offsets = {orbit_radius = 0, size = 100, orbit_radius_size_multiplier = 0.5},

		height = -100,
		fall_speed = 0,

		blend_top = true,
		blend_angle = true,
		centered = true,
	},

	{
		key = "landspoutlayer",
		material = "clouds_and_weather/gstorms_dust_devil_1", material_flags = "smooth",
		shaded_color = {bright = Color(90, 79, 72), dark = Color(73, 63, 56)},
		rotation = {min = 0, max = 0},

		alpha_controls = {alpha_min = 40, alpha_max = 50, fade_in = 0.05, fade_out = 0.10},

		particle_parameters = {size_multiplier = 4, count_multiplier = 1, lifetime = 0},

		offsets = {orbit_radius = 0, size = 100, orbit_radius_size_multiplier = 0.5},

		height = -100,
		fall_speed = 0,
	
		blend_top = true,
		blend_angle = true,
		centered = true,
	},

	{
		key = "debris",
		material = "clouds_and_weather/gstorms_debris_mat_3", material_flags = "smooth",
		shaded_color = {bright = {min = Color(68, 63, 61), max = Color(134, 105, 93)}, dark = Color(71, 71, 71)},
		rotation = {min = 0, max = 360},

		alpha_controls = {alpha_min = 80, alpha_max = 140, fade_in = 0.05, fade_out = 0.95},
		alpha_windspeed = {windspeed_min = 40, windspeed_max = 145, alpha_min_multiplier = 0, alpha_max_multiplier = 1},

		particle_parameters = {size_multiplier = 0.85, count_multiplier = 1, lifetime = 4, size_random_multiplier = 2},

		height = -150,
		fall_speed = 0,

		physics = {x = 14, y = 14, z = 9},

		color_over_water = {
			alpha_multiplier = 0.4,
			shaded_color = {bright = Color(245, 255, 255), dark = Color(75, 79, 83)},
		},

		entity_overrides = {
			IsDestroying = {
				alpha_controls = {alpha_min = 120, alpha_max = 210, fade_in = 0.025},
				particle_parameters = {lifetime = 8},
			},
		
			Spout = {
				alpha_controls = {fade_in = 0.025},
				alpha_windspeed = {windspeed_min = 30, windspeed_max = 135},
				particle_parameters = {lifetime = 8},
			},
		
			DustDevil = {
				alpha_windspeed = {alpha_min_multiplier = 0.25},
			},
		}
	},

	{
		key = "debris",
		material = "clouds_and_weather/gstorms_debris_mat_4", material_flags = "smooth",
		shaded_color = {bright = {min = Color(68, 63, 61), max = Color(134, 105, 93)}, dark = Color(71, 71, 71)},
		rotation = {min = 0, max = 360},

		alpha_controls = {alpha_min = 80, alpha_max = 140, fade_in = 0.05, fade_out = 0.95},
		alpha_windspeed = {windspeed_min = 40, windspeed_max = 145, alpha_min_multiplier = 0, alpha_max_multiplier = 1},

		particle_parameters = {size_multiplier = 1, count_multiplier = 0.85, lifetime = 4, size_random_multiplier = 2},

		height = -150,
		fall_speed = 0,

		physics = {x = 14, y = 14, z = 9},
		
		color_over_water = {
			alpha_multiplier = 0.4,
			shaded_color = {bright = Color(245, 255, 255), dark = Color(75, 79, 83)},
		},

		entity_overrides = {
			IsDestroying = {
				alpha_controls = {alpha_min = 120, alpha_max = 210, fade_in = 0.025},
				particle_parameters = {lifetime = 8},
			},
		
			Spout = {
				alpha_controls = {fade_in = 0.025},
				alpha_windspeed = {windspeed_min = 30, windspeed_max = 135},
				particle_parameters = {lifetime = 8},
			},
		
			DustDevil = {
				alpha_windspeed = {alpha_min_multiplier = 0.25},
			},
		}
	},

	{
		key = "curtains",
		material = "clouds_and_weather/gstorms_curtain_mat_1", material_flags = "smooth",
		shaded_color = {bright = Color(94, 94, 94), dark = Color(35, 35, 35)},
		rotation = {min = -5, max = 5},

		alpha_controls = {alpha_min = 110, alpha_max = 135, fade_in = 0.2, fade_out = 0.8},
		alpha_windspeed = {windspeed_min = 135, windspeed_max = 200, alpha_min_multiplier = 0.1, alpha_max_multiplier = 1},

		particle_parameters = {size_multiplier = 3500, count_multiplier = 0.3, lifetime = 5, size_random_multiplier = 3},

		height = 0,
		fall_speed = 350,

		physics = {x = 9, y = 9, z = 0}
	},

	{
		key = "rainSheet",
		material = "clouds_and_weather/downfall_sheet_2", material_flags = "smooth",
		static_color = Color(107, 114, 120),
		rotation = {min = 0, max = 0},

		alpha_controls = {alpha_min = 255, alpha_max = 255, fade_in = 0.10, fade_out = 0.10},

		particle_parameters = {size_multiplier = 22500, count_multiplier = 1, lifetime = 4},

		height = 0,
		fall_speed = 2000,
		spawn_radius = 40000,

		reflectivity = {
			min_reflectivity = 10,
			max_reflectivity = 100,
			reflectivity_alpha_multiplier = 2,
			require_rain = true,
		},
	},

	{
		key = "sandstorm",
		material = "clouds_and_weather/fas_dust_thick_static", material_flags = "smooth",
		static_color = {min = Color(145,98,64), max = Color(255,203,147)},
		rotation = {min = 0, max = 360},

		alpha_controls = {alpha_min = 75, alpha_max = 255, fade_in = 0.1, fade_out = 0.9},

		particle_parameters = {size_multiplier = 0.9, count_multiplier = 0.25, lifetime = 20, size_random_multiplier = 3},

		height = 0,
		fall_speed = 0,

		flow_particle_end_size_mult = 3,
	},

	{
		key = "pyroclasticFlow",
		material = "clouds_and_weather/fas_dust_d_static", material_flags = "smooth",
		static_color = {min = Color(66, 55, 47), max = Color(87, 73, 69)},
		rotation = {min = 0, max = 360},

		alpha_controls = {alpha_min = 175, alpha_max = 255, fade_in = 0.05, fade_out = 0.75},

		particle_parameters = {size_multiplier = 0.25, count_multiplier = 0.35, lifetime = 14, size_random_multiplier = 3},

		height = 0,
		fall_speed = 0,

		flow_particle_end_size_mult = 6,
	},

	{
		key = "stormCloud",
		material = "clouds_and_weather/cloud_3", material_flags = "smooth",
		shaded_color = {bright = Color(142, 146, 149), dark = Color(55, 56, 57)},
		rotation = {min = 0, max = 0},

		alpha_controls = {alpha_min = 140, alpha_max = 175, fade_in = 0.25, fade_out = 0.25},

		particle_parameters = {size_multiplier = 16000, count_multiplier = 1, lifetime = 10},

		height = 6500,
		fall_speed = 0,
		spawn_radius = 40000,

		reflectivity = {
			min_reflectivity = 0,
			max_reflectivity = 80,
			no_alpha_reflectivity = true
		}
	},

	{
		key = "cloud",
		material = "clouds_and_weather/fas_dust_a_static", material_flags = "smooth",
		shaded_color = {bright = Color(190, 195, 200), dark = Color(194, 198, 204)},
		rotation = {min = 160, max = 200},

		alpha_controls = {alpha_min = 225, alpha_max = 255, fade_in = 0.20, fade_out = 0.20},

		particle_parameters = {size_multiplier = 4, count_multiplier = 2, lifetime = 12},

		height = 14000,
		fall_speed = 0,
		spawn_radius = 40000,

		cloud = {min_cloud_size = 2000, max_cloud_size = 6000, count_multiplier = 1},
	},

	{
		key = "rain",
		material = "clouds_and_weather/rain_1", material_flags = "smooth",
		static_color = Color(152, 162, 168),
		rotation = {min = 0, max = 0},

		alpha_controls = {alpha_min = 255, alpha_max = 255, fade_in = 0.10, fade_out = 0.10},

		particle_parameters = {size_multiplier = 937.5, count_multiplier = 1.5, lifetime = 2.5, size_random_multiplier = 2},

		height = 1000,
		fall_speed = 2000,
		spawn_radius = 1500,

		reflectivity = {
			min_reflectivity = 0,
			max_reflectivity = 100,
			reflectivity_alpha_multiplier = 1,
		},
	},

	{
		key = "snow",
		material = "clouds_and_weather/gstorms_snow", material_flags = "smooth",
		static_color = Color(224, 230, 237),
		rotation = {min = 0, max = 0},

		alpha_controls = {alpha_min = 200, alpha_max = 255, fade_in = 0.10, fade_out = 0.10},

		particle_parameters = {size_multiplier = 875, count_multiplier = 2, lifetime = 5, size_random_multiplier = 1.5},

		height = 500,
		fall_speed = 400,
		spawn_radius = 2000,

		reflectivity = {
			min_reflectivity = 0,
			max_reflectivity = 100,
			reflectivity_alpha_multiplier = 1,
		},
	},
}

GSSetDefaultResourcePack(defaultResourcePack)
GSAddResourcePack(defaultResourcePack)