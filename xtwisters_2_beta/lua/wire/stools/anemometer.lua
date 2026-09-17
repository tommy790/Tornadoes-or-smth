AddCSLuaFile()

WireToolSetup.setCategory( "Detection" )
WireToolSetup.open( "anemometer", "Anemometer", "gmod_wire_anemometer", nil, "Anemometers" )

if CLIENT then
	language.Add( "tool.wire_anemometer.name", "Anemometer Tool (Wire)" )
	language.Add( "tool.wire_anemometer.desc", "Spawns a anemometer for use with the wire system." )
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
	panel:AddControl( "Header", { Description = "Estimate Tornado Windspeed via intercept." } )
end