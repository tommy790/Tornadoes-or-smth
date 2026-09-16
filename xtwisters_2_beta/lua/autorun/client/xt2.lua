AddCSLuaFile() 

-- Receive tip to display on clients for when data is required to be printed as a tip

net.Receive("DisplayTip", function()
	local message = net.ReadString()
	GAMEMODE:AddNotify(message, NOTIFY_GENERIC, 5)
	surface.PlaySound("buttons/lightswitch2.wav") -- Play a notification sound
end)

if GetConVar("xt2_updatethermosrate"):GetInt() < 2 or GetConVar("xt2_updatethermosrate"):GetInt() > 8 then -- Out of range for convar, reset
	RunConsoleCommand("xt2_updatethermosrate", "5")
end

print("hhh - (Rainbow)      lol why did bro say this xDDD - (FORTYFOUR.)")

hook.Add( "AddToolMenuCategories", "XTwisters2load", function()
	spawnmenu.AddToolCategory( "XTwisters2", "XTwisters2", "#XTwisters2 Settings" )
end )

hook.Add( "PopulateToolMenu", "XTwistersload3", function()

	spawnmenu.AddToolMenuOption( "XTwisters2", "XTwisters2", "Custom_Menu2", "#XTwisters2 General Options", "", "", function( panel )

		panel:Help( "(DEFAULT: 600.0)" )

		panel:NumSlider( "Tornado Lifetime (In Seconds)", "xt2_tlifetime", 5, 600, 0 )

		panel:Help( "(DEFAULT: 1.0)" )

		panel:NumSlider( "Tornado Speed Multiplier", "xt2_xspeed", 0.1, 15.0, 1 )

		panel:Help( " " )
		panel:Help( "(DEFAULT: 0.0)" )
		panel:Help( " Experimental Tornado Sounds? " )
		panel:CheckBox( "Enable Arcade Tornado Sounds?", "xt2_arcadesounds")
		panel:Help( " " )

	end )

	spawnmenu.AddToolMenuOption( "XTwisters2", "XTwisters2", "Custom_Menu3", "#XTwisters2 Simulation Options", "", "", function( panel )

		panel:Help( " Anti-Lag Primarily Affects Weather Physics Sim (Turn It Off For Less Jankiness But Lag) " )

		panel:CheckBox( "Anti-Lag", "xt2_antilag")

		panel:Help( "[EXPERIMENTAL] Wind Blocked By Objects May Cause Issues or Performance Issues In Some Cases" )

		panel:CheckBox( "Wind Blocked by Objects", "xt2_windblockedbyobjects")

		panel:CheckBox( "Lightning in Tornadoes", "xt2_lightningintornadoes")

		panel:CheckBox("Damage Props", "xt2_hurtprops")

		panel:CheckBox("Unweld Props", "xt2_unweldprops")

		panel:Help( "[EXPERIMENTAL] RFD Simulation May Cause Issues or Performance Issues In Some Cases" )

		panel:CheckBox( "RFD Simulation", "xt2_rfdsimulation")

		panel:CheckBox("Subvortex Simulation", "xt2_subvorts")

		panel:Help( " " )

	end )

	spawnmenu.AddToolMenuOption( "XTwisters2", "XTwisters2", "Custom_Menu4", "#XTwisters2 Visual Options", "", "", function( panel )

		panel:CheckBox("''Ground Scouring''", "xt2_subscour")

		panel:CheckBox( "Windfield Debris Effect", "xt2_debriseffect", 0, 1, 0 )

		panel:CheckBox( "Screenshake", "xt2_screenshake", 0, 1, 0 )

		panel:Help( " " )

	end )

	spawnmenu.AddToolMenuOption( "XTwisters2", "XTwisters2 Autospawn", "Custom_Menu5", "#XTwisters2 Autospawn Options", "", "", function( panel )

		panel:Help( " Enable Autospawn: " )
		panel:CheckBox( "Autospawn Weather", "xt2_autospawnweather", 0, 1)
		panel:CheckBox( "Autospawn Tornadoes", "xt2_autospawntornadoes", 0, 1)
		panel:CheckBox( "Autospawn Sharknadoes", "xt2_autospawnsharknadoes", 0, 1)
		panel:CheckBox( "Autospawn F12s", "xt2_autospawnf12s", 0, 1)
		panel:CheckBox( "Autospawn F35 Lightnings", "xt2_autospawnf35s", 0, 1)
		panel:Help("Whirlwinds Are Defined As Gustnados and Dust-Devils")
		panel:CheckBox( "Autospawn Whirlwinds", "xt2_autospawnwhirlwinds", 0, 1)
		panel:Help( "Whenever The Risk Updates, XT2 Prints It As A Tip, Toggle This Off To Disable" )
		panel:CheckBox( "Display Risk", "xt2_printrisklevel", 0, 1 )
		panel:Help( " Type in game chat : !xt2 to view all commands and their respective usages... " )
		panel:CheckBox( "Enable Chat Commands", "xt2_enablext2chatcommands", 0, 1 )

		panel:Help( " " )
		panel:Help("XT2 Changes The Skybox For The Autospawn, Toggle This Off To Disable XT2 Changing The Skybox")
		panel:CheckBox( "Enable Skybox Changes", "xt2_customskyboxes", 0, 1)

		panel:Help( " " )
		panel:Help( "Autospawn Settings" )
		panel:Help( " " )
		panel:Help( "Lower Is more, Higher Is Less. These Are NOT In Seconds, They Are Exponent Multipliers." )
		panel:Help( "(DEFAULT: 5)" )
		panel:NumSlider( "Storm Chance Multiplier per Risk", "xt2_stormchance", 3, 7.0, 1 )
		panel:NumSlider( "Hail Chance Multiplier per Storm", "xt2_hailstormchance", 3, 7.0, 1 )
		panel:NumSlider( "Derecho Chance Multiplier per Storm", "xt2_derechochance", 3, 7.0, 1 )
		panel:NumSlider( "Rainstorm Chance Multiplier per Risk", "xt2_rainstormchance", 3, 7.0, 1 )
		panel:NumSlider( "Tornado Chance Multiplier per Storm", "xt2_tornadochance", 3, 7.0, 1 )
		panel:NumSlider( "Sharknado Chance Multiplier per Storm", "xt2_sharknadochance", 3, 7.0, 1 )
		panel:NumSlider( "F12 Chance Multiplier per Storm", "xt2_f12chance", 3, 7.0, 1 )
		panel:NumSlider( "F35 Lightning Chance Multiplier per Storm", "xt2_f35chance", 3, 7.0, 1 )
		panel:NumSlider( "Whirlwind Chance Multiplier", "xt2_whirlwindchance", 3, 7.0, 1 )
		panel:Help( " " )
		panel:CheckBox( "Enable Events?", "xt2_enableevents", 0, 1 )
		panel:Help( " " )
		panel:Help( "Lower Is Less, Higher Is More. These Are NOT In Seconds, They Are Multipliers." )
		panel:Help( "(DEFAULT: 5)" )
		panel:NumSlider( "High Cape Event Chance Multiplier", "xt2_highcapeeventchance", 1, 25.0, 1 )
		panel:NumSlider( "Tornado Outbreak Chance Multiplier", "xt2_outbreakeventchance", 1, 25.0, 1 )
		panel:Help( " " )
		panel:Help( " Lower Is Less EF5's, Higher Is More. These Are NOT In Seconds, They Are Multipliers. " )
		panel:Help( "(DEFAULT: 5)" )
		panel:NumSlider( "VTP Commonality", "xt2_vtpcommonality", 1, 10.0, 1 )
		panel:Help( " " )
		panel:Help( "Lower Is Less, Higher Is More. These Are NOT In Seconds, They Are Multipliers." )
		panel:Help( "(DEFAULT: 10)" )
		panel:NumSlider( "NO-RISK Day Chance Multiplier", "xt2_noriskchance", 1, 20.0, 1 )
		panel:Help( " " )
		panel:Help( "How Long Until The Next Thermodynamic Update? These Are NOT In Seconds")
		panel:Help( "Lower Is A Slower Update Rate, Higher Is A Faster Update Rate. These Are NOT In Seconds, They Are Multipliers." )
		panel:Help( "(DEFAULT: 5)" )
		panel:NumSlider( "Thermodynamics Update Rate Multiplier", "xt2_updatethermosrate", 2, 8, 1 )
		panel:Help( " " )
		panel:Help( "Lower Is Shorter Lifespans, Higher Is Longer Lifespans. These Are NOT In Seconds, They Are Multipliers." )
		panel:Help( "(DEFAULT: 5)" )
		panel:NumSlider( "Tornado Lifetime Multiplier Autospawn", "xt2_t_lifetime_autospawn", 1, 10.0, 1 )
		panel:NumSlider( "Storm Lifetime Multiplier Autospawn", "xt2_s_lifetime_autospawn", 1, 10.0, 1 )
		
		panel:Help(" ")
		panel:Help(" FOR SERVER OWNERS: configs now use the xt2_prefix, please use this prefix to find commands ")
		panel:Help(" ")
		panel:Help("More Settings and config soon.")
		panel:Help( " " )

/*
		panel:CheckBox("Autospawn Weather", "SubScour")

		panel:Help( " " )
		panel:Help( "Autospawn Arcade Mode" )
		
		panel:CheckBox("Enable Arcade Mode", "SubScour")

		panel:NumSlider( "Tornado Refresh Time", "tlifetime", 5, 600, 0 )
		panel:NumSlider( "Tornado Spawn Chance", "tlifetime", 5, 600, 0 )
		panel:NumSlider( "Minimum Tornado Strength", "tlifetime", 5, 600, 0 )
		panel:NumSlider( "Max Tornado Strength", "tlifetime", 5, 600, 0 )

		panel:Help( " " )
		panel:Help( "Autospawn Extras" )
		panel:CheckBox("Autospawn Whirlwinds", "SubScour")
		panel:CheckBox("Autospawn Fire whirlwinds", "SubScour")
		panel:CheckBox("Autospawn Media Tornadoes", "SubScour")
		panel:CheckBox("Autospawn Realistic Tornadoes", "SubScour")
		panel:CheckBox("Autospawn Sharknado", "SubScour")
*/

	end )

end )	