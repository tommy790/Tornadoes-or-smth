if SERVER then return end

local twoPi = math.pi * 2

if SERVER then return end

local twoPi = math.pi * 2

local function GSApplyScreenshakeToView(localPlayer, view)

	local frameTime = FrameTime()

	localPlayer.GSShakeAmp = Lerp(frameTime * 10, localPlayer.GSShakeAmp or 0, localPlayer.GSShakeTarget)
	localPlayer.GSShakeFreq = Lerp(frameTime * 8, localPlayer.GSShakeFreq or 0, localPlayer.GSShakeFreqTarget or 0)
	localPlayer.GSShakePhase = (localPlayer.GSShakePhase or localPlayer.GSShakeSeed or 0) + localPlayer.GSShakeFreq * twoPi * RealFrameTime()

	local seed = localPlayer.GSShakeSeed or 0
	local shakePhase = localPlayer.GSShakePhase
	local ph1, ph2, ph3 = shakePhase + seed, shakePhase * 1.3 + seed * 1.7, shakePhase * 0.77 + seed * 2.3
	local s1, s2, s3 = math.sin(ph1), math.sin(ph2), math.sin(ph3)
	local a = localPlayer.GSShakeAmp * 0.04
	local pos = view.origin
	local ang = view.angles

	view.angles = Angle(ang.p + (s2 * 0.5 + s3 * 0.3 + s1 * 0.2) * a * 0.7, ang.y + (s3 * 0.5 + s1 * 0.3 + s2 * 0.2) * a * 0.5, ang.r + (s1 * 0.5 + s2 * 0.3 + s3 * 0.2) * a)
	view.origin = pos + ang:Right() * (s1 * a * 0.25) + ang:Up() * (s2 * a * 0.25) + ang:Forward() * (s3 * a * 0.15)

	return view

end

local function GSScreenshakeCalcView(localPlayer, pos, ang, fov, znear, zfar)

	if !localPlayer:IsValid() then return end
	if !localPlayer.GSScreenshakeHookActive or (localPlayer.GSShakeTarget or 0) <= 0 then return end

	local vehicle = localPlayer:GetVehicle()
	local weapon = localPlayer:GetActiveWeapon()
	local view = localPlayer.GSShakeView or {}

	localPlayer.GSShakeView = view

	view.origin = pos
	view.angles = ang
	view.fov = fov
	view.znear = znear
	view.zfar = zfar
	view.drawviewer = false

	if IsValid(vehicle) then

		local vehicleView = hook.Run("CalcVehicleView", vehicle, localPlayer, view)

		if vehicleView then view = vehicleView end

	else

		if drive and drive.CalcView and drive.CalcView(localPlayer, view) then return GSApplyScreenshakeToView(localPlayer, view) end

		if player_manager and player_manager.RunClass then player_manager.RunClass(localPlayer, "CalcView", view) end

		if IsValid(weapon) then

			local func = weapon.CalcView

			if func then

				local origin, angles, newFov = func(weapon, localPlayer, Vector(view.origin), Angle(view.angles), view.fov)

				view.origin = origin or view.origin
				view.angles = angles or view.angles
				view.fov = newFov or view.fov

			end

		end

	end

	return GSApplyScreenshakeToView(localPlayer, view)

end


hook.Add("CalcView", "GSScreenshakeHook", GSScreenshakeCalcView)

function GSWindspeedScreenshake(ply, windspeed, windspeedThresholdAmp, windspeedThresholdFreq, windspeedMaxAmp, windspeedMaxFreq, seed, inVehicle, earthquakeMagnitude, earthquakeMagnitudeMax, earthquakeMaxAmp, earthquakeMaxFreq)

	if !ply:IsValid() then return end

	local vehicleMult = inVehicle and 0.5 or 1

	windspeed = windspeed * vehicleMult

	local windAmpTarget = math.min(math.max(windspeed - windspeedThresholdAmp, 0), windspeedMaxAmp) * 0.5
	local windFreqTarget = math.min(math.max(windspeed - windspeedThresholdFreq, 0), windspeedMaxFreq) * 0.05
	local quakeAmpTarget = 0
	local quakeFreqTarget = 0

	if earthquakeMagnitude and earthquakeMagnitude > 0 then
		local magT = math.min(math.max(earthquakeMagnitude / earthquakeMagnitudeMax, 0), 1)
		quakeAmpTarget = magT * (earthquakeMaxAmp or windspeedMaxAmp) * 0.5 * vehicleMult
		quakeFreqTarget = magT * (earthquakeMaxFreq or windspeedMaxFreq) * 0.05 * vehicleMult
	end

	ply.GSShakeTarget = math.max(windAmpTarget, quakeAmpTarget)
	ply.GSShakeFreqTarget = math.max(windFreqTarget, quakeFreqTarget)
	ply.GSShakeSeed = seed
	ply.GSScreenshakeHookActive = ply.GSShakeTarget > 0
	ply.GSShakeLastCallTime = CurTime()

	if (ply.GSShakeAmp or 0) > ply.GSShakeTarget then ply.GSShakeAmp = ply.GSShakeTarget end
	if (ply.GSShakeFreq or 0) > ply.GSShakeFreqTarget then ply.GSShakeFreq = ply.GSShakeFreqTarget end

end