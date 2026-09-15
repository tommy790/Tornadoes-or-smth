if !WireLib then return end

WireToolSetup.setCategory("GStorms")
WireToolSetup.open("gstorms_seismograph", "GStorms Seismograph", "gmod_wire_gstorms_seismograph", nil, "GStorms Seismographs") -- WireToolSetup.open pattern :contentReference[oaicite:4]{index=4}
WireToolSetup.SetupMax(3)

TOOL.Model = "models/props_c17/suitcase_passenger_physics.mdl"

if CLIENT then
	language.Add("Tool.wire_gstorms_seismograph.name", "GStorms Seismograph (Wire)")
	language.Add("Tool.wire_gstorms_seismograph.desc", "Spawns A Wiremod Based GStorms Seismographh")
	language.Add("Tool.wire_gstorms_seismograph.0", "Left click to place.")
end

function TOOL:MakeEnt(ply, model, Ang, trace)
	return WireLib.MakeWireEnt(ply, {
		Class = "gmod_wire_gstorms_seismograph",
		Pos = trace.HitPos,
		Angle = Ang,
		Model = model
	}, self:GetConVars())
end

function TOOL.BuildCPanel(panel)
	panel:AddControl( "Header", { Description = "Spawns A Wiremod Based GStorms Seismograph... Supports Inputs & Outputs" } )
end
