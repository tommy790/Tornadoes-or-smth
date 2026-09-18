-- The user's own fully-upgraded buggy layout, exported from the in-game 3D
-- editor on 2026-09-18. Ground truth for component placement. Note it defines
-- only SIX spike mounts: it was saved before the Heavy Anchor Array had mounts
-- to save, which is exactly the case the migration has to handle.
return {
    vehicle_model = "models/buggy.mdl",
    components = {
        { id = "comp_1",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",                 pos = Vector( 25.00,  50.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_2",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",                 pos = Vector(-25.00,  50.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_3",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",                 pos = Vector( 30.00, -20.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_4",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",                 pos = Vector(-30.00, -20.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_5",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",                 pos = Vector( 20.00,-100.00,  0.00), ang = Angle( 80.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_6",  type = "spike",          name = "Spike",         group = "imported", model = "models/props_junk/harpoon002a.mdl",                 pos = Vector(-20.00,-100.00,  0.00), ang = Angle(100.00,   0.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_7",  type = "armor_side",     name = "Armor_side",    group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl",     pos = Vector(-43.50, -24.50, 31.80), ang = Angle(-90.00,  90.00,  90.00), scale = Vector(1,1,1) },
        { id = "comp_8",  type = "armor_side",     name = "Armor_side",    group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl",     pos = Vector( 43.50, -24.50, 31.80), ang = Angle(-90.00,  90.00,  90.00), scale = Vector(1,1,1) },
        { id = "comp_9",  type = "armor_front",    name = "Armor_front",   group = "imported", model = "models/props_phx/construct/metal_plate1x2.mdl",     pos = Vector(  0.00,  64.00, 31.80), ang = Angle(-95.30,  90.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_10", type = "radar_screen",   name = "Radar_screen",  group = "imported", model = "models/kobilica/wiremonitorsmall.mdl",              pos = Vector( 19.20,  -9.20, 37.30), ang = Angle( -6.90,-125.00,   0.00), scale = Vector(1,1,1) },
        { id = "comp_11", type = "armor_roof",     name = "Armor_roof",    group = "imported", model = "models/props_phx/construct/metal_plate1.mdl",       pos = Vector(  0.00, -49.20, 79.00), ang = Angle(  0.00,   0.00, 168.50), scale = Vector(1,1,1) },
        { id = "comp_12", type = "hydraulic_ram",  name = "Hydraulic_ram", group = "imported", model = "models/props_c17/TrapPropeller_Lever.mdl",          pos = Vector( 35.90, -24.60, 30.00), ang = Angle( 90.00,   0.00,   0.00), scale = Vector(1,1,1) },
    }
}
