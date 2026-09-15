local pi = math.pi
local oneEightyPi = pi / 180
local tiny = 1e-12

local mathSin = math.sin
local mathCos = math.cos
local mathMin = math.min
local mathMax = math.max
local mathFloor = math.floor
local mathSqrt = math.sqrt
local mathAbs = math.abs
local mathLog = math.log
local mathAtan2 = math.atan2
local bitBand = bit.band
local bitTobit = bit.tobit
local bitBxor = bit.bxor
local bitRshift = bit.rshift

local function GSFade(t) return t*t*t*(t*(t*6 - 15) + 10) end

local function GSHash8(ix, iy, seedMul)
	local h = bitTobit(ix * 374761393 + iy * 668265263 + seedMul)
	h = bitBxor(h, bitRshift(h, 13))
	h = bitTobit(h * 1274126177)
	h = bitBxor(h, bitRshift(h, 16))
	return bitBand(h, 255) + 1
end

local gsGradX, gsGradY = {}, {}
local gradStep = pi / 128

for i = 0, 255 do
	local a = i * gradStep
	gsGradX[i + 1] = mathCos(a)
	gsGradY[i + 1] = mathSin(a)
end

local function GSGrad(ix, iy, seedMul)
	local idx = GSHash8(ix, iy, seedMul)
	return gsGradX[idx], gsGradY[idx]
end

local function GSPerlin2(x, y, seed)

	local xi, yi = mathFloor(x), mathFloor(y)
	local xf, yf = x - xi, y - yi
	local u, v = GSFade(xf), GSFade(yf)

	local xi1, yi1 = xi + 1, yi + 1
	local xf1, yf1 = xf - 1, yf - 1
	local seedMul = seed * 2147483647

	local g00x, g00y = GSGrad(xi,  yi,  seedMul)
	local g10x, g10y = GSGrad(xi1, yi,  seedMul)
	local g01x, g01y = GSGrad(xi,  yi1, seedMul)
	local g11x, g11y = GSGrad(xi1, yi1, seedMul)

	local d00 = g00x * xf  + g00y * yf
	local d10 = g10x * xf1 + g10y * yf
	local d01 = g01x * xf  + g01y * yf1
	local d11 = g11x * xf1 + g11y * yf1

	local x1 = d00 + u * (d10 - d00)
	local x2 = d01 + u * (d11 - d01)
	return x1 + v * (x2 - x1)

end

local function GSPerlin2Lerped(x, y, t0, tf, seed)
	local n0 = GSPerlin2(x, y, t0 + seed)
	return n0 + (GSPerlin2(x, y, t0 + seed + 1) - n0) * tf
end

function GSNoise(x, y, dirX, dirY, dirZ, minMultiplier, maxMultiplier, minSize, maxSize, minDirectionChange, maxDirectionChange, frequency, curTime)
	local invLen3 = 1 / mathSqrt(dirX * dirX + dirY * dirY + dirZ * dirZ + tiny)
	local nx, ny, nz = dirX * invLen3, dirY * invLen3, dirZ * invLen3

	local t = curTime * frequency
	local t0 = mathFloor(t)
	local tf = GSFade(t - t0)

	local sizeScale = 0.7692307692307692 / maxSize
	local cellSize = minSize + (maxSize - minSize) * (GSPerlin2Lerped(x * sizeScale, y * sizeScale, t0, tf, 0) * 0.5 + 0.5)

	local invCellSize = 1 / cellSize
	local px, py = x * invCellSize, y * invCellSize

	local n = GSPerlin2Lerped(px, py, t0, tf, 0)
	local a = (minDirectionChange + (maxDirectionChange - minDirectionChange) * mathAbs(n)) * oneEightyPi
	if n < 0 then a = -a end

	local ca, sa = mathCos(a), mathSin(a)
	local vx = nx * ca - ny * sa
	local vy = nx * sa + ny * ca

	return minMultiplier + (maxMultiplier - minMultiplier) * (GSPerlin2Lerped(px * 0.5 + 13.7, py * 0.5 - 9.2, t0, tf, 23) * 0.5 + 0.5), vx, vy, nz
end

local function GSRotationalNoiseSample(swirlPhase, radiusScale, radialMult, inwardsMul, swirlStrength, swirlRadius, invBlobSize, t0, tf, cycleOffset)
	local bx, by = mathCos(swirlPhase) * radiusScale, mathSin(swirlPhase) * radiusScale

	local phaseWarped = swirlPhase + GSPerlin2Lerped(bx * 0.70 + radialMult * 0.40 + 13.1 + cycleOffset * 0.07, by * 0.70 - radialMult * 0.25 - 7.2 - cycleOffset * 0.05, t0, tf, 17) * 0.85 * swirlStrength
	local radialWarped = radialMult + GSPerlin2Lerped(bx * 0.55 - radialMult * 0.30 - 4.7 + cycleOffset * 0.04, by * 0.55 + radialMult * 0.55 + 9.8 + cycleOffset * 0.06, t0, tf, 29) * 0.10 * inwardsMul

	local swirl = swirlRadius * invBlobSize
	local sx, sy = mathCos(phaseWarped) * swirl, mathSin(phaseWarped) * swirl

	local band0 = GSPerlin2(sx + radialWarped * 1.8 + cycleOffset * 0.11, sy - radialWarped * 1.1 - cycleOffset * 0.09, 51) * 0.5 + 0.5
	local band1 = GSPerlin2(sx * 1.65 - radialWarped * 2.8 + 5.3 - cycleOffset * 0.08, sy * 1.65 + radialWarped * 1.7 - 7.4 + cycleOffset * 0.12, 79) * 0.5 + 0.5
	local detail = GSPerlin2(sx * 3.10 + radialWarped * 4.6 - 10.2 + cycleOffset * 0.15, sy * 3.10 - radialWarped * 3.8 + 2.7 - cycleOffset * 0.13, 107) * 0.5 + 0.5

	return band0 * 0.60 + band1 * 0.28 + detail * 0.12
end

local fadeStart = 0.5

function GSRotationalNoise(posX, posY, centerPosX, centerPosY, vortexRMWSize, vortexSize, spinSpeed, minSize, maxSize, sizeExponent, minMul, maxMul, noiseFrequency, swirlStrength, inwardsStrength, outerStretchScale, curTime, anticyclonic)
	local dx, dy = posX - centerPosX, posY - centerPosY
	local r = mathSqrt(dx * dx + dy * dy)

	vortexRMWSize = mathMax(vortexRMWSize, 1)

	local annulusSize = mathMax(vortexSize - vortexRMWSize, 1)
	local shapeRadialFrac = mathMin(mathMax((r - vortexRMWSize) / annulusSize, 0), 1)
	local ratio = vortexSize / vortexRMWSize
	local logR = mathLog(mathMax(mathMin(r, vortexSize) / vortexRMWSize, 1.000001))

	local spinDirection = anticyclonic and -1 or 1
	local spinMul = spinSpeed * spinDirection
	local spinRate = spinSpeed < 0 and -spinSpeed or spinSpeed
	local cycleLength = mathMin(mathMax(3.6 / mathMax(spinRate * 0.35, 0.001), 35), 140)
	local cycleIndex, cycleFrac, cycleAge, cycleOffset = 0, 0, curTime, 0
	local cycleBlend = 0

	if spinRate > 0.0001 then
		local cyclePos = curTime / cycleLength
		cycleIndex = mathFloor(cyclePos)
		cycleFrac = cyclePos - cycleIndex
		cycleAge = cycleFrac * cycleLength
		cycleOffset = (cycleIndex % 97) * 19.19

		if cycleFrac > fadeStart then cycleBlend = GSFade((cycleFrac - fadeStart) / (1 - fadeStart)) end
	end

	local noiseTime = curTime * mathMax(noiseFrequency, 0)
	local t = noiseTime * 0.16
	local t0 = mathFloor(t)
	local tf = GSFade(t - t0)

	local sizeDenom = mathMax(maxSize * 1.3, 1)
	local sizeSampleX, sizeSampleY = dx / sizeDenom + 31.7, dy / sizeDenom - 14.2
	local sizeNoise = GSPerlin2Lerped(sizeSampleX, sizeSampleY, t0, tf, 211) * 0.5 + 0.5
	local sizeNoiseBiased = sizeNoise ^ mathMax(sizeExponent, 0.0001)
	local blobSize = mathMax(minSize + (maxSize - minSize) * sizeNoiseBiased, 1)

	local radiusScale = 2 + shapeRadialFrac * 1.8
	local inwardsMul = mathMax(inwardsStrength, 0)
	local radialRatioMul = mathMin(mathMax((ratio - 4) * 0.07, 0), 2.4)
	local radialMult = shapeRadialFrac * inwardsMul * (3.8 + radialRatioMul)

	local outerStretchMul = 1 + (outerStretchScale - 1) * shapeRadialFrac
	local effectiveRadius = vortexRMWSize + (r - vortexRMWSize) * outerStretchMul
	local swirlRadius = effectiveRadius * mathMax(1 - swirlStrength, 0.05)
	local invBlobSize = 1 / blobSize

	local spiralRatioMul = mathMin(mathMax((ratio - 4) * 0.025, 0), 0.8)
	local spiralTightness = 2.35 + spiralRatioMul
	local spinOffsetScale = 0.15 - shapeRadialFrac * 0.35
	local baseSpin = curTime * spinMul
	local swirlPhaseBase = mathAtan2(dy, dx) + logR * spiralTightness * swirlStrength * spinDirection
	local swirlPhase = swirlPhaseBase - (baseSpin + cycleAge * spinMul * spinOffsetScale)

	local bandField = GSRotationalNoiseSample(swirlPhase, radiusScale, radialMult, inwardsMul, swirlStrength, swirlRadius, invBlobSize, t0, tf, cycleOffset)

	local envDenom = mathMax(vortexSize * 0.55, 1)
	local asymmetry = GSPerlin2(dx / envDenom + noiseTime * 0.02 + 1.8, dy / envDenom - noiseTime * 0.015 - 3.1, 131) * 0.5 + 0.5

	local breakupDenom = mathMax(vortexSize * 0.18, 1)
	local breakup = GSPerlin2(dx / breakupDenom + noiseTime * 0.011 + 2.2, dy / breakupDenom - noiseTime * 0.009 - 4.5, 149) * 0.5 + 0.5

	local valueMul = (0.78 + asymmetry * 0.36) * (0.85 + breakup * 0.22)
	local value = mathMin(mathMax(bandField * valueMul, 0), 1)

	if cycleBlend > 0 then
		local nextCycleAge = (cycleFrac - 1) * cycleLength
		local nextCycleOffset = ((cycleIndex + 1) % 97) * 19.19
		local nextSwirlPhase = swirlPhaseBase - (baseSpin + nextCycleAge * spinMul * spinOffsetScale)
		local nextBandField = GSRotationalNoiseSample(nextSwirlPhase, radiusScale, radialMult, inwardsMul, swirlStrength, swirlRadius, invBlobSize, t0, tf, nextCycleOffset)
		local nextValue = mathMin(mathMax(nextBandField * valueMul, 0), 1)

		value = value + (nextValue - value) * cycleBlend
	end

	return minMul + (maxMul - minMul) * value
end

function GSGetModifiedTornadoOffsetFromHeightAndNoise(distanceZ, freq, amp, speed, anticyclonic, seed, phase, curTime, detailSize, peakHeight, funnelMaxHeight)
	local h = mathMax(distanceZ, tiny)
	local mainH = h * freq
	local curSpeed = phase or (curTime * speed * (anticyclonic and 0.0005 or -0.0005))
	local hFrac = h / funnelMaxHeight
	local hFrac2 = hFrac * hFrac
	local baseLock = hFrac2 / (hFrac2 + 0.04)
	local detailGate = mainH / (mainH + detailSize * 0.625)
	local peakFrac = hFrac / peakHeight
	local heightEnvelope

	if peakFrac < 1 then
		heightEnvelope = peakFrac * (2 - peakFrac)
	else
		local d = peakFrac - 1
		heightEnvelope = 1 / (1 + d * (2.2 + d * 1.3))
	end

	local ampMod = amp * funnelMaxHeight * 0.075 * baseLock * heightEnvelope
	local p0 = mainH + curSpeed + seed * 2.71
	local p1 = mainH * (2 / detailSize + 0.28) - curSpeed * 0.62 + seed * 4.93
	local mainWeight = 0.92 - detailGate * 0.10
	local detailWeight = detailGate * 0.24

	return ampMod * (mathSin(p0) * mainWeight + mathSin(p1) * detailWeight), ampMod * (mathCos(p0) * mainWeight + mathCos(p1) * detailWeight)
end

function GSGetModifiedTornadoPosFromHeightAndNoise(posX, posY, posZ, distanceZ, frequency, amp, speed, anticyclonic, seed, phase, curTime, detailSize, peakHeight, funnelMaxHeight)
	local offX, offY = GSGetModifiedTornadoOffsetFromHeightAndNoise(distanceZ, frequency, amp, speed, anticyclonic, seed, phase, curTime, detailSize, peakHeight, funnelMaxHeight)
	return posX + offX, posY + offY, posZ
end

function GSReturnPositionNoiseMaxOffset(maxH, amp, freq, dSize, peak)
	if maxH <= 0 or amp == 0 then return 0 end

	local peakFrac = math.Clamp(peak or 0.5, tiny, 1)
	local h = maxH * peakFrac
	local hFrac2 = peakFrac * peakFrac
	local baseLock = hFrac2 / (hFrac2 + 0.04)

	dSize = mathMax(dSize, tiny)

	local mainH = h * freq
	local detailGate = mainH / (mainH + dSize * 0.625)

	return mathAbs(amp) * maxH * 0.075 * baseLock * (0.92 + detailGate * 0.14)
end