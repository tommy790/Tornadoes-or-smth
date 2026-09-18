-- The user's own fully-upgraded jalopy layout, exported from the in-game 3D
-- editor on 2026-09-18 (models/vehicle.mdl, which shares the addon's jalopy
-- config branch). Ground truth for component placement on that branch.
--
-- Unlike the buggy export this one already defines eight spike mounts, so it is
-- also the case the migration must leave alone.
return {
    vehicle_model = "models/vehicle.mdl",
    components = {
        { id = "comp_1",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector( 25.00,  45.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_2",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector(-25.00,  45.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_3",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector( 25.00,   0.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_4",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector(-25.00,   0.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_5",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector( 25.00,-100.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_6",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector(-25.00,-100.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_7",  type = "armor_side",     name = "Armor_side",    group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(-48.00, -39.00, 40.80), ang = Angle(-90.00,  90.00,  90.00), scale = Vector(1,1,1) },
        { id = "comp_8",  type = "armor_side",     name = "Armor_side",    group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector( 44.00, -39.00, 40.80), ang = Angle(-90.00,  90.00,  90.00), scale = Vector(1,1,1) },
        { id = "comp_9",  type = "armor_front",    name = "Armor_front",   group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(  0.00,  57.40, 45.00), ang = Angle(-165.00, 90.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_10", type = "radar_screen",   name = "Radar_screen",  group = "imported", model = "models/kobilica/wiremonitorsmall.mdl",          pos = Vector( 14.00,  14.00, 42.00), ang = Angle( 10.00,-125.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_11", type = "armor_roof",     name = "Armor_roof",    group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl", pos = Vector(  0.00, -17.80, 67.50), ang = Angle(  6.90,  90.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_12", type = "hydraulic_ram",  name = "Hydraulic_ram", group = "imported", model = "models/props_c17/TrapPropeller_Lever.mdl",      pos = Vector( 35.00,   0.00, 30.00), ang = Angle( 90.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_13", type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector( 44.90,-135.00, 10.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_14", type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",             pos = Vector(-44.90,-135.00, 10.00), ang = Angle( 80.00, 180.00,   0.00), scale = Vector(1,1,1) },
    }
}
