if !WireLib then return end

WireToolSetup.setCategory("GStorms")
WireToolSetup.open("gstorms_probe", "GStorms Probe", "gmod_wire_gstorms_probe", nil, "GStorms Probes") -- WireToolSetup.open pattern :contentReference[oaicite:4]{index=4}
WireToolSetup.SetupMax(3)

TOOL.Model = "models/props_interiors/pot01a.mdl"

if CLIENT then
	language.Add("Tool.wire_gstorms_probe.name", "GStorms Probe (Wire)")
	language.Add("Tool.wire_gstorms_probe.desc", "Spawns A Wiremod Based GStorms Probe")
	language.Add("Tool.wire_gstorms_probe.0", "Left click to place.")
end

function TOOL:MakeEnt(ply, model, Ang, trace)
	return WireLib.MakeWireEnt(ply, {
		Class = "gmod_wire_gstorms_probe",
		Pos = trace.HitPos,
		Angle = Ang,
		Model = model
	}, self:GetConVars())
end

function TOOL.BuildCPanel(panel)
	panel:AddControl( "Header", { Description = "Spawns A Wiremod Based GStorms Probe... Supports Inputs & Outputs" } )
end
