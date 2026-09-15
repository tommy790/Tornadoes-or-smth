include("gstorms_funcs/gstorms_shared.lua")

local hurtMinSpeed = 350

if SERVER then
    net.Receive("gs_hailstone_damage", function(_, ply)
        local speed = net.ReadFloat()

        if !IsValid(ply) or !ply:Alive() or speed < hurtMinSpeed then return end

        local curTime = CurTime()
        if ply.GSNextHailDamage and ply.GSNextHailDamage > curTime then return end

        ply.GSNextHailDamage = curTime + 0.15

        local world = game.GetWorld()
        local dmg = DamageInfo()

        dmg:SetDamage(speed * 0.01)
        dmg:SetDamageType(DMG_CRUSH)
        dmg:SetAttacker(world)
        dmg:SetInflictor(world)

        ply:TakeDamageInfo(dmg)
    end)

    return
end

local lifetime = 2.5
local fadeInFrac = 0.2
local fadeOutStartFrac = 0.75
local spawnRadius = 2000
local spawnHeight = 1000
local windVelocityMult = 20
local gravity = 800
local bounceMult = 0.25
local frictionMult = 0.6
local hurtMinSpeedSqr = hurtMinSpeed * hurtMinSpeed
local rollRadius = 12
local physicsDelay = engine.TickInterval() * 3
local invPhysicsDelay = 1 / physicsDelay

local invFadeInTime = 1 / (lifetime * fadeInFrac)
local invFadeOutTime = 1 / (lifetime * (1 - fadeOutStartFrac))
local bounceResponse = 1 + bounceMult
local rollSpeedMult = 57.295779513082 / rollRadius

local hailstones = {}
local hailstoneCount = 0
local nextDamageSend = 0
local lastDrawFrame = -1
local lastPhysicsTime = 0
local nextPhysicsTime = 0

local reflectivityThreshold = GSReturnValueColorsReflectivity()[5].windspeed
local reflectivityThresholdMax = GSReturnValueColorsReflectivity()[6].windspeed

local hailColor = Color(255, 255, 255, 255)
local windScratch = Vector()
local drawPos = Vector()
local traceStart = Vector()
local traceEnd = Vector()
local rollAxis = Vector()
local traceData = {start = traceStart, endpos = traceEnd, mask = MASK_SOLID}

local mathRand = math.Rand
local mathRandom = math.random
local mathMin = math.min
local mathSqrt = math.sqrt
local traceLine = util.TraceLine
local setBlend = render.SetBlend

local function RemoveHailstone(i, mdl)
    if IsValid(mdl) then mdl:Remove() end

    hailstones[i] = hailstones[hailstoneCount]
    hailstones[hailstoneCount] = nil
    hailstoneCount = hailstoneCount - 1
end

local function SpawnHailstone(pos, windVec, curTime, fallSpeed)

    local mdl = ClientsideModel("models/props_mining/rock_caves01c.mdl", RENDERGROUP_OPAQUE)
    if !IsValid(mdl) then return end

    local ang = Angle(mathRand(0, 360), mathRand(0, 360), mathRand(0, 360))

    mdl:SetPos(pos)
    mdl:SetAngles(ang)
    mdl:SetModelScale(mathRand(0.25, 1), 0)
    mdl:SetMaterial("other/hailstone/gstorms_hailstone")
    mdl:SetRenderMode(RENDERMODE_TRANSALPHA)
    mdl:SetColor(hailColor)
    mdl:SetNoDraw(true)

    hailstoneCount = hailstoneCount + 1
    hailstones[hailstoneCount] = {
        mdl = mdl, ang = ang,
        x = pos.x, y = pos.y, z = pos.z,
        prevX = pos.x, prevY = pos.y, prevZ = pos.z,
        vx = windVec.x * windVelocityMult, vy = windVec.y * windVelocityMult, vz = windVec.z * windVelocityMult - fallSpeed,
        initTime = curTime, dieTime = curTime + lifetime
    }

end

local function UpdateHailstonePhysics(curTime, dt, ply)
    local i = 1
    local gravityStep = gravity * dt
    local rollAngleMult = dt * rollSpeedMult

    while i <= hailstoneCount do
        local hail = hailstones[i]
        local mdl = hail.mdl

        if !IsValid(mdl) or curTime >= hail.dieTime then
            RemoveHailstone(i, mdl)
        else
            local oldX = hail.x
            local oldY = hail.y
            local oldZ = hail.z
            local vx = hail.vx
            local vy = hail.vy
            local vz = hail.vz - gravityStep
            local newX = oldX + vx * dt
            local newY = oldY + vy * dt
            local newZ = oldZ + vz * dt

            traceStart:SetUnpacked(oldX, oldY, oldZ)
            traceEnd:SetUnpacked(newX, newY, newZ)

            local tr = traceLine(traceData)

            if tr.Hit then
                if tr.Entity == ply and !hail.HurtPlayer then
                    local speedSqr = vx * vx + vy * vy + vz * vz

                    if speedSqr >= hurtMinSpeedSqr then
                        nextDamageSend = curTime + 0.15
                        net.Start("gs_hailstone_damage")
                        net.WriteFloat(mathSqrt(speedSqr))
                        net.SendToServer()
                        hail.HurtPlayer = true
                    end
                end

                local n = tr.HitNormal
                local dot = vx * n.x + vy * n.y + vz * n.z

                if dot < 0 then
                    local responseMul = bounceResponse * mathRand(1, 1.25) * dot
                    vx = (vx - responseMul * n.x) * frictionMult
                    vy = (vy - responseMul * n.y) * frictionMult
                    vz = (vz - responseMul * n.z) * frictionMult

                    if !hail.RandImpactDir then
                        vx = vx + mathRandom(-200, 200) * mathRand(0.25, 1)
                        vy = vy + mathRandom(-200, 200) * mathRand(0.25, 1)
                        hail.RandImpactDir = true
                    end

                    hail.vx = vx
                    hail.vy = vy
                end

                local hitPos = tr.HitPos

                if !hail.PlayedSound then 
                    sound.Play("hail/hail_impact_" .. mathRandom(1, 5) .. ".wav", hitPos, 80, mathRandom(75, 125), 0.4)
                    hail.PlayedSound = true
                end

                newX = hitPos.x + n.x
                newY = hitPos.y + n.y
                newZ = hitPos.z + n.z
            end

            hail.prevX = oldX
            hail.prevY = oldY
            hail.prevZ = oldZ

            hail.x = newX
            hail.y = newY
            hail.z = newZ
            hail.vz = vz

            local speed2DSqr = vx * vx + vy * vy

            if speed2DSqr > 1 then
                local speed2D = mathSqrt(speed2DSqr)
                local invSpeed2D = 1 / speed2D
            
                rollAxis:SetUnpacked(-vy * invSpeed2D, vx * invSpeed2D, 0)
                hail.ang:RotateAroundAxis(rollAxis, speed2D * rollAngleMult)
                mdl:SetAngles(hail.ang)
            end

            i = i + 1
        end
    end
end

local function DrawHailstones(curTime)
    local t = lastPhysicsTime > 0 and (curTime - lastPhysicsTime) * invPhysicsDelay or 1
    local curBlend = 1

    local eyePos = EyePos()
    local viewForward = EyeAngles():Forward()
    local eyeX, eyeY, eyeZ = eyePos.x, eyePos.y, eyePos.z
    local forwardX, forwardY, forwardZ = viewForward.x, viewForward.y, viewForward.z

    for i = 1, hailstoneCount do
        local hail = hailstones[i]
        local mdl = hail.mdl

        if IsValid(mdl) then
            local fadeIn = (curTime - hail.initTime) * invFadeInTime
            local fadeOut = (hail.dieTime - curTime) * invFadeOutTime
            local alpha = mathMin(fadeIn, fadeOut, 1)

            if alpha > 0 then
                local prevX, prevY, prevZ = hail.prevX, hail.prevY, hail.prevZ
                local x = prevX + (hail.x - prevX) * t
                local y = prevY + (hail.y - prevY) * t
                local z = prevZ + (hail.z - prevZ) * t

                if (x - eyeX) * forwardX + (y - eyeY) * forwardY + (z - eyeZ) * forwardZ > -64 then
                    drawPos:SetUnpacked(x, y, z)
                    mdl:SetPos(drawPos)

                    if alpha ~= curBlend then
                        setBlend(alpha)
                        curBlend = alpha
                    end

                    mdl:DrawModel()
                end
            end
        end
    end

    if curBlend ~= 1 then setBlend(1) end
end

hook.Add("Think", "Gstorms_Hailstone_Handler", function()
    local curTime = CurTime()
    local ply = LocalPlayer()

    if hailstoneCount > 0 then
        if curTime + 3 < nextPhysicsTime then
            nextPhysicsTime = 0
            lastPhysicsTime = 0
        end

        if curTime >= nextPhysicsTime then
            local dt = lastPhysicsTime > 0 and curTime - lastPhysicsTime or physicsDelay

            lastPhysicsTime = curTime
            nextPhysicsTime = curTime + physicsDelay

            UpdateHailstonePhysics(curTime, dt, ply)
        end
    else
        lastPhysicsTime = 0
        nextPhysicsTime = 0
    end

    local env = gs_env.client

    if !GetConVar("gstorms_env_hail"):GetBool() or #gs_weatherEntityList.client == 0 or !IsValid(env) then return end

    local weatherList = gs_weatherEntityList.client
    local updraft = false

    if env.Temperature > 10 then
        for _, ent in ipairs(weatherList) do
            if !IsValid(ent) or !ent.Networked then continue end
            if ent.Tornado or ent.Thunderstorm or ent.Rainstorm or ent.Derecho then updraft = true break end
        end
    end

    if !updraft or !IsValid(ply) then return end

    local plyPos = ply:GetPos()
    local reflectivityAtPly, _, parent = GSGetStormReflectivityValueFromPoint(plyPos, false, weatherList)

    if !IsValid(parent) or !(parent.Thunderstorm or parent.Tornado or parent.Spout) then return end
    if reflectivityAtPly < reflectivityThreshold or mathRand(0, 1) > Lerp(mathMin((reflectivityAtPly - reflectivityThreshold) / (reflectivityThresholdMax - reflectivityThreshold), 1), 0.01, 0.4) then return end

    local _, windVec = GSGetGlobalWindspeedAndVectors(plyPos, weatherList, GetConVar("gstorms_tornado_inflow_jet"):GetBool(), env, curTime, windScratch)

    local fallSpeed = mathRandom(300, 500)
    local startVZ = windVec.z * windVelocityMult - fallSpeed
    local fallTime = (startVZ + mathSqrt(startVZ * startVZ + 2 * gravity * spawnHeight)) / gravity
    local delta = windVelocityMult * fallTime
    local driftX = windVec.x * delta
    local driftY = windVec.y * delta
    local targetX = plyPos.x + mathRandom(-spawnRadius, spawnRadius)
    local targetY = plyPos.y + mathRandom(-spawnRadius, spawnRadius)
    
    SpawnHailstone(Vector(targetX - driftX, targetY - driftY, plyPos.z + spawnHeight), windVec, curTime, fallSpeed)
end)

hook.Add("PostDrawEffects", "Gstorms_Hailstone_Draw", function()
    if hailstoneCount <= 0 then return end

    local frame = FrameNumber()
    if frame == lastDrawFrame then return end

    lastDrawFrame = frame

    DrawHailstones(CurTime())
end)

hook.Add("ShutDown", "Gstorms_Hailstone_Cleanup", function()
    for i = 1, hailstoneCount do
        if IsValid(hailstones[i].mdl) then hailstones[i].mdl:Remove() end
    end
end)