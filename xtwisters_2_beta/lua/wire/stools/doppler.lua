AddCSLuaFile()

WireToolSetup.setCategory( "Detection" )
WireToolSetup.open( "dopplerradar", "Doppler Radar", "gmod_wire_doppler", nil, "DopplerRadars" )

if CLIENT then
	language.Add( "tool.doppler_radar.name", "Doppler Radar Tool (Wire)" )
	language.Add( "tool.doppler_radar.desc", "Spawns a doppler radar for use with the wire system." )
	TOOL.Information = { { name = "left", text = "Create/Update " .. TOOL.Name } }
end
WireToolSetup.BaseLang()
WireToolSetup.SetupMax( 10 )

if SERVER then
	function TOOL:GetConVars()
	end
end

TOOL.Model = "models/jaanus/wiretool/wiretool_speed.mdl"

function TOOL.BuildCPanel(panel)
	panel:AddControl( "Header", { Description = "Estimate Tornado Windspeed, Size and Movement Speed via radar." } )
end