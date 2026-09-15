if SERVER then return end

local matNoise = CreateMaterial("gs_fog_overlay_1", "UnlitGeneric", {
	["$basetexture"] = "post_processing/wind",
	["$basetexturetransform"] = "center .5 .5 scale 0.25 0.25 rotate 0 translate 0 0",
	["$translucent"] = "1",
	["$vertexalpha"] = "1",
	["$vertexcolor"] = "1",
	["$alphatest"] = "0",
	["$ignorez"] = "1"
})

local matGradV = CreateMaterial("gs_fog_background", "UnlitGeneric", {
	["$basetexture"] = "clouds_and_weather/cloud",
	["$basetexturetransform"] = "center 0.5 0.5 scale 0.5 0.5 rotate 0 translate 0 0",
	["$translucent"] = "1",
	["$vertexalpha"] = "1",
	["$vertexcolor"] = "1",
	["$alphatest"] = "0",
	["$ignorez"] = "1"
})

local colorValueTable = {
	{windspeed = 0, color = Color(96, 59, 34)},
	{windspeed = 50, color = Color(96, 59, 34)},
	{windspeed = 90, color = Color(125, 125, 125)}
}

local gsFog = {target = 0.0, value = 0.0, r = 255, g = 255, b = 255, hooked = false, anticyclonic = false, freq = 0, movement = 0}

local function GSParseFogColor(c) return c.r, c.g, c.b end

local function GSDirFromLookAngle(tornadoPos)
	local toTornado = tornadoPos - EyePos()
	toTornado.z = 0

	local L = toTornado:Length2D(); if L < 1e-6 then return 1 end
	local forward = EyeAngles():Forward()

	forward.z = 0
	forward:Normalize()

	return (((forward.x * toTornado.x + forward.y * toTornado.y) / L) < -0.20) and -1 or 1
end

local tile = 1.5
local base = 0.05
local inv255 = 1 / 255

local ppTbl = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

local function GSFogRenderHook()

	gsFog.value = Lerp(FrameTime() * 6, gsFog.value, gsFog.target)

	local w, h = ScrW(), ScrH()
	local cx, cy = w * 0.5, h * 0.5
	local v = gsFog.value

	ppTbl["$pp_colour_addr"] = (gsFog.r * inv255) * 0.008 * v
	ppTbl["$pp_colour_addg"] = (gsFog.g * inv255) * 0.008 * v
	ppTbl["$pp_colour_addb"] = (gsFog.b * inv255) * 0.008 * v
	ppTbl["$pp_colour_brightness"] = 0.015 * v
	ppTbl["$pp_colour_contrast"] = 1.0 - 0.05 * v
	ppTbl["$pp_colour_colour"] = 1.0 - 0.12 * v

	DrawColorModify(ppTbl)

	surface.SetMaterial(matGradV)
	surface.SetDrawColor(gsFog.r, gsFog.g, gsFog.b, 125 * v)
	surface.DrawTexturedRectRotated(cx, cy, w * 2, h * 2, 0)
	surface.DrawTexturedRectRotated(cx, cy, w * 2, h * 2, 90)

	local effDir = GSDirFromLookAngle(gsFog.tornadoPos) * (gsFog.anticyclonic and 1 or -1)

	gsFog.movement = gsFog.movement + (effDir * base * gsFog.freq) * RealFrameTime()

	surface.SetMaterial(matNoise)
	surface.SetDrawColor(gsFog.r, gsFog.g, gsFog.b, 150 * v)
	surface.DrawTexturedRectUV(0, 0, w, h, gsFog.movement, 0, gsFog.movement + tile, tile)

end

function GSSetPostProcessFog(localPlayer, tornadoPos, alpha, freq, distanceControl, anticyclonic)

	if !localPlayer:IsValid() then return end

	gsFog.target = alpha
	gsFog.r, gsFog.g, gsFog.b = GSParseFogColor(GSLerpAndSmoothColor(distanceControl, colorValueTable, true))
	gsFog.freq = freq
	gsFog.anticyclonic = anticyclonic
	gsFog.tornadoPos = tornadoPos

	localPlayer.GSPostProcessFogLastCallTime = CurTime()

	if !gsFog.hooked then
		hook.Add("RenderScreenspaceEffects", "GS_Custom_Fog_PostProcessing", GSFogRenderHook)
		gsFog.hooked = true
	end

end

function GSGetGSFog() return gsFog end