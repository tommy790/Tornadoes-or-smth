AddCSLuaFile()

WireToolSetup.setCategory( "Detection" )
WireToolSetup.open( "barometer", "Barometer", "gmod_wire_barometer", nil, "Barometers" )

if CLIENT then
	language.Add( "tool.wire_barometer.name", "Barometer Tool (Wire)" )
	language.Add( "tool.wire_barometer.desc", "Spawns a barometer for use with the wire system." )
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
	panel:AddControl( "Header", { Description = "Estimate Tornado Pressure Drops via intercept." } )
end