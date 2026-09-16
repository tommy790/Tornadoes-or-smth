AddCSLuaFile()

if SERVER then return end

local function AddX2( crack, class )
	list.Set( "Xtwister2", class || crack.Class, crack )
end


local TornadoesCategory = "XTwisters2 Tornadoes" 
local WhirlwindCategory = "XTwisters2 Whirlwinds" 
local WeatherCategory = "XTwisters2 Weather" 
local WeaponsCategory = "XTwisters2 Weaponry"
local SpaceCategory = "XTwisters2 Outerspace"   
local MiscCategory = "XTwisters2 Miscellaneous" 
local XBlizters = "XTwizzlers3" 


-- Tornadoes

	AddX2({ Name = "Random Tornado", Class = "xt2_tornadoes_ef-u", Category = TornadoesCategory })
	AddX2({ Name = "Dynamic Tornado", Class = "xt2_tornadoes_dynamic", Category = TornadoesCategory })
	AddX2({ Name = "EF0 Tornado", Class = "xt2_tornadoes_ef-0", Category = TornadoesCategory })
	AddX2({ Name = "EF1 Tornado", Class = "xt2_tornadoes_ef-1", Category = TornadoesCategory })
	AddX2({ Name = "EF2 Tornado", Class = "xt2_tornadoes_ef-2", Category = TornadoesCategory })
	AddX2({ Name = "EF3 Tornado", Class = "xt2_tornadoes_ef-3", Category = TornadoesCategory })
	AddX2({ Name = "EF4 Tornado", Class = "xt2_tornadoes_ef-4", Category = TornadoesCategory })
	AddX2({ Name = "EF5 Tornado", Class = "xt2_tornadoes_ef-5", Category = TornadoesCategory })
	AddX2({ Name = "Drillbit Tornado", Class = "xt2_tornadoes_drillbit", Category = TornadoesCategory })

-- Whirlwinds

	AddX2({ Name = "Fire Tornado", Class = "xt2_whirlwinds_firetornado", Category = WhirlwindCategory })
	AddX2({ Name = "Firewhirl", Class = "xt2_whirlwinds_firewhirl", Category = WhirlwindCategory })
	AddX2({ Name = "Dust Devil", Class = "xt2_whirlwinds_dustdevil", Category = WhirlwindCategory })
	AddX2({ Name = "Gustnado", Class = "xt2_whirlwinds_gustnado", Category = WhirlwindCategory })

-- Weather

	AddX2({ Name = "Lightning Bolt", Class = "lightning_bolt", Category = WeatherCategory })
	AddX2({ Name = "Rainstorm", Class = "xt2_weather_rainstorm", Category = WeatherCategory })
	AddX2({ Name = "Moderate Rainstorm", Class = "xt2_weather_moderaterainstorm", Category = WeatherCategory })
	AddX2({ Name = "Heavy Rainstorm", Class = "xt2_weather_heavyrainstorm", Category = WeatherCategory })
	AddX2({ Name = "Hailstorm", Class = "xt2_weather_hailstorm", Category = WeatherCategory })
	AddX2({ Name = "Rainstorm", Class = "xt2_weather_rainstorm", Category = WeatherCategory })
	AddX2({ Name = "Thunderstorm", Class = "xt2_weather_thunderstorm", Category = WeatherCategory })
	AddX2({ Name = "Severe Thunderstorm", Class = "xt2_weather_severethunderstorm", Category = WeatherCategory })
	AddX2({ Name = "Supercell Thunderstorm", Class = "xt2_weather_supercellthunderstorm", Category = WeatherCategory })
	AddX2({ Name = "Derecho", Class = "xt2_weather_derecho", Category = WeatherCategory })

-- Weapons

	AddX2({ Name = "1500 Pound Explosive", Class = "xt2_weapons_1500poundexplosivedevice", Category = WeaponsCategory })
	AddX2({ Name = "Nuclear Weapon", Class = "xt2_weapons_nuclearbomb", Category = WeaponsCategory })

-- XT2 Remakes

	AddX2({ Name = "Media Tornadoes Remade", Class = "xt2_tornadoes_remakes", Category = TornadoesCategory })

-- space

	AddX2({ Name = "Meteor", Class = "xt2_space_smallmeteor", Category = SpaceCategory })
	AddX2({ Name = "Meteor Shower", Class = "xt2_space_meteorshower", Category = SpaceCategory })
	--AddX2({ Name = "Large Meteor", Class = "xt2_space_mediummeteor", Category = SpaceCategory })
	--AddX2({ Name = "Colossal Meteor", Class = "xt2_space_largemeteor", Category = SpaceCategory })

-- MiscCategory

	AddX2({ Name = "Weather Balloon", Class = "xt2_misc_weather_balloon", Category = MiscCategory })
	AddX2({ Name = "Tornado Siren", Class = "xt2_misc_tornado_siren", Category = MiscCategory })

-- XBlizters

	AddX2({ Name = "''Realistic'' Tornado", Class = "xt2_tornadoes_realistictornado", Category = XBlizters })
	AddX2({ Name = "Sharknado", Class = "xt2_tornadoes_sharknado", Category = XBlizters })
	AddX2({ Name = "F12", Class = "xt2_tornadoes_f-12", Category = XBlizters })
	AddX2({ Name = "F-35 Lightning", Class = "xt2_tornadoes_f-35", Category = XBlizters })
	AddX2({ Name = "The Flying Black Orb.", Class = "xt2_tornadoes_orb", Category = XBlizters })
	
-- loser shit

	hook.Add( "PopulateXTWISTERS2", "AddXTWISTERS2", function( pnlContent, tree, node )

		local XTLIST = list.Get( "Xtwister2" )

		local Categories = {}
		for k, shit in pairs( XTLIST ) do

			local Category = shit.Category || "Other"
			local Tab = Categories[ Category ] || {}

			Tab[ k ] = shit

			Categories[ Category ] = Tab

		end

		for CategoryName, v in SortedPairs( Categories ) do

			local node = tree:AddNode( CategoryName, "materials/icon2.png" )

			node.DoPopulate = function( self )

				if ( self.PropPanel ) then return end

				self.PropPanel = vgui.Create( "ContentContainer", pnlContent )
				self.PropPanel:SetVisible( true )
				self.PropPanel:SetTriggerSpawnlistChange( false )

				for name, ent in SortedPairsByMemberValue( v, "Name" ) do

					spawnmenu.CreateContentIcon( ent.ScriptedEntityType or "entity", self.PropPanel, {
						nicename	= ent.Name or name,
						spawnname	= name,
						material	= "entities/" .. name .. ".png",
						weapon		= ent.Weapons,
						admin		= ent.AdminOnly
					} )

				end

			end

			node.DoClick = function( self )

				self:DoPopulate()
				pnlContent:SwitchPanel( self.PropPanel )

			end

		end

		local FirstNode = tree:Root():GetChildNode( 0 )
		if ( IsValid( FirstNode ) ) then
			FirstNode:InternalDoClick()
		end

	end )
	spawnmenu.AddCreationTab( "XTwisters2", function()

		local ctrl = vgui.Create( "SpawnmenuContentPanel" )
		ctrl:EnableSearch( "entity", "PopulateXTWISTERS2" )
		ctrl:CallPopulateHook( "PopulateXTWISTERS2" )
		return ctrl

	end, "materials/icon1.png", 50 )