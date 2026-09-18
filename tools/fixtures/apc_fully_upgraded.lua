-- The user's own fully-upgraded Combine APC layout, exported from the in-game 3D
-- editor on 2026-09-18 16:18. Ground truth for the apc config branch.
--
-- Note the roof sits forward of centre here (y = +75.9) while the buggy's is at
-- y = -49.2 and the jalopy's at y = -17.8: the three verified roofs share no
-- pattern, which is why the remaining branches are not derived from them.
return {
    vehicle_model = "models/combine_apc.mdl",
    components = {
        { id = "comp_1",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector( 35.00,  90.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_2",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector(-35.00,  90.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_3",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector( 35.00,  10.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_4",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector(-35.00,  10.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_5",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector( 35.00,-110.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_6",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector(-35.00,-110.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_7",  type = "armor_side",     name = "Armor_side",    group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(-56.40,  -6.20, 49.20), ang = Angle(-90.00,  90.00,  90.00), scale = Vector(1,1,1) },
        { id = "comp_8",  type = "armor_side",     name = "Armor_side",    group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector( 56.40,  -6.20, 49.20), ang = Angle(-90.00,  90.00,  90.00), scale = Vector(1,1,1) },
        { id = "comp_9",  type = "armor_front",    name = "Armor_front",   group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(  0.00, 106.70, 61.70), ang = Angle(-120.00, 90.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_10", type = "radar_screen",   name = "Radar_screen",  group = "imported", model = "models/kobilica/wiremonitorsmall.mdl",          pos = Vector( -8.00,  -0.10, 80.00), ang = Angle(-10.00, -75.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_11", type = "hydraulic_ram",  name = "Hydraulic_ram", group = "imported", model = "models/props_c17/TrapPropeller_Lever.mdl",      pos = Vector( 35.00,   0.00, 30.00), ang = Angle( 90.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_12", type = "armor_roof",     name = "Armor_roof",    group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(  0.00,  75.90, 80.00), ang = Angle(166.20, -90.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_13", type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector( 25.00, -20.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_14", type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector(-25.00, -20.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
    }
}
