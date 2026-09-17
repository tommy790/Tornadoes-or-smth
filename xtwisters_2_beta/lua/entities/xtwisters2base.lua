AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.sFScale = 0
ENT.range = 0
ENT.Force = 0
ENT.weldf = 0
ENT.rotforce = 0
ENT.inflowmult = 1
ENT.speedmult = 1
ENT.HasLightning = true  
ENT.Subvorts = false
ENT.isderp = false
ENT.derptype = 0 
ENT.Tornadic = true 
ENT.IsFirenado = false  
ENT.CustomAudio = false  
ENT.StormName = "Tornado"
ENT.PlayerNPCForceMult = 0.4

--For XT2 Mod API
ENT.DeviateChance = false  
ENT.GrowToSize = false  
ENT.StrengthenOverTime = false  
ENT.StrengthenTime = 1  
ENT.IsAutospawn = false
ENT.isTornado = false
ENT.MinParticleUpdateTime = 40
ENT.AutospawnEventChanceMultiplier = 2.0 -- Chance for particle to switch its current flags given the current phaseflags and typeflags etc,. 
ENT.AutospawnRangeClimbRateMultiplier = 0.15 -- Climb rate multiplier for updating the autospawn range and such. Very sensitive as you can tell so be cautious. (can also be above 1 not just below 1)
ENT.GeneralForceMultiplier = 1.0 -- X and Y velocities of props and players
ENT.HeightForceMultiplier = 1.0 -- Z velocities of props and players
ENT.InnerFunnelDistance = nil -- Inner Funnel Distance
ENT.IsAnticyclonic = false
ENT.MaxWinds = 100
ENT.IsMaxWinds = false
ENT.CurrentAutospawnParticleTypeFlags = {}
ENT.CurrentAutospawnPhaseFlags = {}
ENT.CurrentAutospawnWallcloudColor = "white"
ENT.IsDynamicTornado = false

--IGNORE THIS STUFF (FORTYFOURs ENT Variables, RELEVANT TO THE SCRIPT, NOT RELEVANT TO THE API AND YOU PROBABLY SHOULD NOT TOUCH UNDER ANY CIRCUMSTANCES CUZ THE FUNNY MAY OCCUR (who knows lol)) -- nah but fr like these literally initialize the autospawn particle list queue for removal so pls dont :(
ENT.JustInitialized = false
ENT.oldConditions = {}
ENT.PrecachedParticlesAutospawn = {}
ENT.JustInitialized = false
ENT.oldParticleName = ""
ENT.PauseIsMaxWindsVB = false
ENT.RFDOrientation = 1
ENT.JustSpawned = true
ENT.HasRFD = false


-- INIT GENERAL LOCAL VARS, DO NOT TOUCH THESE --

local ForceZMult = 3.75 --height velocity scaling on props GENERALIZED not localized to entities either so do not touch.
local CompressDebrisHeight = 3.0 --this is an exponential function i.e ^3.0 to make debris have a soft-knee form of compression when it comes to wind relative height
local MassMult = 0.75 --Used for calculating mass equivalent wind force on props
local EngineUpdateDelay = 0.01 -- Entire engine update delay (probably shouldn't touch in brackets...)
local PhysDelay = 0.1 -- 0.1 Physics update delay, optimized for this number though possibly changable (not recomended)
local RagMult = 15.0 --Physics multiplier for ragdolls (Change if you feel that tornadoes are throwing ragdolls too aggressively.)
local distheightexponent = 0.3 --makes it so that the closer you are, the exponentially higher you will go, NON-LINEAR, adjust with caution if necessary.
local exponentialoffset = 0.1
local AtmosphericPressure = 101325


-- You guys can touch this for custom sounds, I.E for break sounds, title them break1, break2 etc,. and then change this to the highest break number, I.E in the default sound folder this would be break4
local NumberOfBreakSoundFiles = 4

------------------------------------------------------------------------------------------------------------------------------------

local function IsLVSVehicle(ent)
    if IsValid(ent) and ent.GetClass then
        local class = ent:GetClass()
        if string.sub(class, 1, 3) == "lvs" then
            return true
        end
    end
    return false
end

if SERVER then
    include("autorun/server/autospawn.lua")
    spawnedTornadoesInWorld = spawnedTornadoesInWorld or 0
    scheduledRemovalsXT2 = scheduledRemovalsXT2 or {}
    hook.Add("PreCleanupMap", "OnAdminCleanupForAutospawn", function()
        -- Reset the scheduledRemovals table to an empty table when cleanup is performed
        scheduledRemovalsXT2 = {}
    end)
end

if SERVER then
    util.AddNetworkString("UpdateEntityParticle")
    util.AddNetworkString("RemoveEntityParticle") 
    util.AddNetworkString("PrecacheClientside")
    util.AddNetworkString("AttachParticleClients")
end

scheduledRemovalsXT2 = scheduledRemovalsXT2 or {}

if CLIENT then
    PrecacheParticleSystem("XT2Subvortthing")
    -- Handling the update of entity particles
    net.Receive("PrecacheClientside", function()
        local ent = net.ReadEntity()
        local newParticleName = net.ReadString()
        if newParticleName ~= "" and ent:IsValid() then
            if !PrecacheParticleSystem(newParticleName) then
                PrecacheParticleSystem(newParticleName)
            end
            net.Start("AttachParticleClients")
            net.WriteEntity(ent)
            net.WriteString(newParticleName)
            net.SendToServer()
        end
    end)
    net.Receive("UpdateEntityParticle", function()
        local ent = net.ReadEntity()
        local newParticleName = net.ReadString()
        if newParticleName ~= "" and ent:IsValid() then
            ParticleEffectAttach(newParticleName, PATTACH_ABSORIGIN_FOLLOW, ent, 0)
        end
    end)

    -- Initialize the table for scheduled removals if it doesn't exist
	hook.Add("PreCleanupMap", "OnAdminCleanupForAutospawn", function()
        -- Resetting da scheduledRemovals table to an empty table when cleanup is performed
        scheduledRemovals = {}
    end)

    -- Function to safely add a particle to the removal queue
    local function AddToRemovalQueue(entIndex, particleName)
        -- Initialize the entity's removal data if not already present
        if not scheduledRemovalsXT2[entIndex] then
            scheduledRemovalsXT2[entIndex] = {removeQueue = {}}
        end

        -- Add the particle to the queue, no condition to check against currentParticle
        table.insert(scheduledRemovalsXT2[entIndex].removeQueue, particleName)
    end

    net.Receive("RemoveEntityParticle", function()
        local readEnt = net.ReadEntity()
        local oldParticleName = net.ReadString()

        if oldParticleName ~= "" and IsValid(readEnt) then
            local entIndex = readEnt:EntIndex()

            -- Add the particle to the removal queue directly
            AddToRemovalQueue(entIndex, oldParticleName)

            local timerName = "RemoveParticle_" .. entIndex
            local timerDelay = 22 -- Delay in seconds before attempting removal

            -- Create or restart the timer for this entity
            if not timer.Exists(timerName) then
                timer.Create(timerName, timerDelay, 1, function()
                    local currentEnt = IsValid(readEnt) and readEnt or nil
                    if currentEnt then
                        local removeList = scheduledRemovalsXT2[entIndex] and scheduledRemovalsXT2[entIndex].removeQueue or {}
                        for _, particleName in ipairs(removeList) do
                            currentEnt:StopParticlesNamed(particleName)
                        end
                    end

                    -- Clearing all particles from the removal queue for this entity after processing
                    scheduledRemovalsXT2[entIndex].removeQueue = {}
                end)
            end
        end
    end)
end

local function clamp(value, mi, ma) if value < mi then value = mi end if value > ma then value = ma end return value end
local function rnd(mi, ma) return math.random(1000) / 1000 * (ma - mi) + mi end

local MinWindSpeed = 65
local MaxWindSpeed = 320

-- Define windspeed thresholds and corresponding values
local ef0Windspeed = 85  -- MAX windspeed for EF-0 (Baseline)
local ef3Windspeed = 165 -- MAX Windspeed for EF-3
local ef5Windspeed = 225 -- Minimum windspeed for EF-5
local ef3Value = 10 -- 

local function TraceCheckWalls(Entity, TraceSender)

    local BlockedFromTheFront = false 
    local BlockedFromTheBack = false 
    local BlockedFromTheLeft = false 
    local BlockedFromTheRight = false 
    local BlockedFromTheTop = false 

    local AreasBlocked = 0
    local WindTunnelCheck = 0
    local WindMultiplier = 1
    local WindMultiplierUpdraft = 1

    local EntityPos = Entity:GetPos()

    if Entity:IsPlayer() or Entity:IsNPC() then
        EntityPos = EntityPos + Vector(0, 0, 50)
    end

    local IgnoreList = {Entity, TraceSender}
    local WallTraceFront = util.TraceLine({start = EntityPos, endpos = EntityPos+Vector(0, 800, 0), filter = IgnoreList})
    
    local WallTraceBack = util.TraceLine({start = EntityPos, endpos = EntityPos+Vector(0, -800, 0), filter = IgnoreList})

    local WallTraceRight = util.TraceLine({start = EntityPos, endpos = EntityPos+Vector(800, 0, 0), filter = IgnoreList})

    local WallTraceLeft = util.TraceLine({start = EntityPos, endpos = EntityPos+Vector(-800, 0, 0), filter = IgnoreList})

    local RoofTrace = util.TraceLine({start = EntityPos, endpos = EntityPos+Vector(0, 0, 800), filter = IgnoreList})

    if WallTraceFront.Hit then
        BlockedFromTheFront=true 
        AreasBlocked = AreasBlocked+1
        WindTunnelCheck = WindTunnelCheck+1
        WindMultiplier = math.Clamp(WindMultiplier - 0.2, 0, 2)
    end
    
    if WallTraceBack.Hit then
        BlockedFromTheBack=true 
        AreasBlocked = AreasBlocked+1
        WindTunnelCheck = WindTunnelCheck+1
        WindMultiplier = math.Clamp(WindMultiplier - 0.2, 0, 2)
    end

    if WallTraceLeft.Hit then
        BlockedFromTheLeft=true 
        AreasBlocked = AreasBlocked+1
        WindTunnelCheck = WindTunnelCheck+1
        WindMultiplier = math.Clamp(WindMultiplier - 0.2, 0, 2)  
    end

    if WallTraceRight.Hit then
        BlockedFromTheRight=true 
        AreasBlocked = AreasBlocked+1
        WindTunnelCheck = WindTunnelCheck+1
        WindMultiplier = math.Clamp(WindMultiplier - 0.2, 0, 2)
    end

    if RoofTrace.Hit then
        BlockedFromTheTop=true 
        AreasBlocked = AreasBlocked+2
        WindMultiplier = math.Clamp(WindMultiplier - 0.35, 0, 2)
        WindMultiplierUpdraft = 0
    end

    if BlockedFromTheTop == true and WindTunnelCheck == 2 then
        WindMultiplier = math.Clamp(WindMultiplier + 1.35, 0, 2)
        WindMultiplierUpdraft = 0.25
    end

    if BlockedFromTheTop == false and WindTunnelCheck >= 4 then
        WindMultiplierUpdraft = 8
    end
    if AreasBlocked >= 6 then
        return true, WindMultiplier, WindMultiplierUpdraft
    else
        return false , WindMultiplier, WindMultiplierUpdraft
    end
end


function ENT:CalculatePressureDrop(propdist)
    self.MaxPressureDrop = 5000 * (self.Force / 80) * (6500 / self.range)
    self.windSpeedProportion = math.min(math.max((self.Force - MinWindSpeed) / (MaxWindSpeed - MinWindSpeed), 0), 1)

    self.distanceFactor3 = math.max(0, (self.InnerFunnelDistance - propdist) / self.InnerFunnelDistance)

    -- Pressure drop scales with both wind speed and proximity to the center (also an EF-4 will drop around 100 millibars dynamically on its own as similar to its real world counterpart)
    self.pressureDrop = self.MaxPressureDrop * self.windSpeedProportion * self.distanceFactor3

    -- Prop location relative to tornado based pressure
    self.resultingPressure = AtmosphericPressure - self.pressureDrop
    self.resultingPressure = math.max(self.resultingPressure, AtmosphericPressure - self.MaxPressureDrop)

    -- Return the calculated pressure
    return self.resultingPressure
end

function ENT:ForceMultiplierFunctionAutospawn(baselineValue, maxValue)
    -- Check for windspeed below EF-0 Maximum
    if self.Force <= ef0Windspeed then
        return baselineValue
    -- Check for windspeed above EF-5 minimum
    elseif self.Force >= ef5Windspeed then
        return maxValue
    -- Calculate for windspeeds within the EF-0 to EF-3 range using an exponential function
    elseif self.Force <= ef3Windspeed then
        local expScale = math.log(ef3Value / baselineValue) / (ef3Windspeed - ef0Windspeed)
        local value = baselineValue * math.exp(expScale * (self.Force - ef0Windspeed))
        return value
    -- Calculate for windspeeds within the EF-3 to EF-5 range
    else
        local slope = (maxValue - ef3Value) / (ef5Windspeed - ef3Windspeed)
        local value = ef3Value + slope * (self.Force - ef3Windspeed)
        return value
    end
end

function ENT:startx()

    if SERVER then
        self.physdelstarttime = CurTime()
        self.StartUpdateTime = CurTime()
        self.SpawnInInitTime = CurTime()
        if self.InnerFunnelDistance == nil then
            self.InnerFunnelDistance = self.range / 6
        end
        self:UpdateForcePlayersAndNPCs()
        self.PlayerNPCForceMult = self.PlayerNPCForceMult * 1.5
        self.desiredOrbitRadius = self.range / 1.5

        RunConsoleCommand("r_farz",  "90000")
        RunConsoleCommand("gmod_mcore_test", "1")
        self.OldPos = self:GetPos()
        self.NewPos = self:GetPos()
        local function GenerateProperties()
	        self.Windspeedmultifordamage = (self.Force + 75) - (self.Force * (0.001*self.Force)) 	--0.001 is the gradient value to scale props unfreezing along a gradient EF-0 EF-5 etc,. (changing it to 0.002 makes EF-5s do significantly less damage in contrast to other tornado types etc,.)
		    self.weldf = math.Clamp(170 * 3000000000 / (self.Windspeedmultifordamage * 0.35 * self.Windspeedmultifordamage * 0.5 * self.Windspeedmultifordamage * 0.8 * self.Windspeedmultifordamage) / 10, 1, 10000)
            function self:GetWeldfFromBase()
                return self.weldf
            end
        end
        
        if self.IsAutospawn == false then
            GenerateProperties()
        end

        self:SetNWFloat( "Rotforce", self.rotforce )
        self:SetNWFloat( "Windspeed", self.Force )
        self:SetNWFloat( "Windfield", self.range )
        self:SetNWFloat( "Subvorts", self.Subvorts )
        if self.isTornado or self.Tornadic then
            self:RearFlankDowndraftSim()
        end
        if self.IsDynamicTornado or self.IsAutospawn then
            self:AutospawnHandler()
        end
        self.GeneralForceMultiplier = self:ForceMultiplierFunctionAutospawn(1.3, 1.9)
        self.HeightForceMultiplier = self:ForceMultiplierFunctionAutospawn(4.8, 25)

        self.LightningChance = math.random(200,800)
        self.dgob = { start = self:GetPos(), mask = MASK_SOLID_BRUSHONLY + MASK_WATER, filter = self, endpos = self:GetPos() + Vector(0, 0, -10000) }
        self.dgobs = util.TraceLine(self.dgob)

        if self.dgobs.Hit then
            self:SetPos( Vector( 0, 0, 20 ) + self.dgobs.HitPos )
        end
        
    end

	PrecacheParticleSystem("tor")
    PrecacheParticleSystem("rearflankdowndraft")
    PrecacheParticleSystem("rearflankdowndraft2")
    PrecacheParticleSystem("rearflankdowndraft3")
    PrecacheParticleSystem("rearflankdowndraft4")
end

function ENT:testing2()
    if SERVER then
        self.trnt = Vector(0,0,0)
    end
end

function ENT:AutospawnHandler()
    if SERVER then
        function self:UpdateForceAutospawn()
            local TornadoesInWorldShouldStartTickingDown2 = false
            if calculateRiskLevel(GetSRH(), GetCape()) == "NO-RISK" then
                TornadoesInWorldShouldStartTickingDown2 = true
            else
                TornadoesInWorldShouldStartTickingDown2 = false
            end
            if self.Force <= 40 and self:IsValid() and self.IsAutospawn == true or self.Force <= 40 and self:IsValid() and self.IsDynamicTornado == true then -- Remove Tornado if self force less than 40 (winds less than 40)
                self:Remove()
                if spawnedTornadoesInWorld ~= 0 and self.IsDynamicTornado == false then
                    spawnedTornadoesInWorld = spawnedTornadoesInWorld - 1
                end
            end
            if !self:IsValid() then -- if self is not valid after removal then do nothing else
                return
            end
            if self.Force >= self.MaxWinds and self.IsMaxWinds == false and self.PauseIsMaxWindsVB == false then -- set maxwinds to true, LEAVE THIS AT THE START OF THE IF CHAIN, IT IS IMPORTANT SINCE THE NEXT LOGIC RELIES ON MAXWINDS.
                self.IsMaxWinds = true
            end

            self.reintensifyrange = (((GetCape() <= 1000 and (150 + (1000 - GetCape()) * 0.05)) or (GetCape() <= 6000 and (150 - ((GetCape() - 1000) * (100 / 5000)))) or (50 - ((GetCape() - 6000) * (5 / 1000)))) * ((GetSRH() / 300) + 0.5)) ^ 0.65 + 60
            self.reintensifyrange = math.max(self.reintensifyrange, 1)  -- Ensure value does not become negative or zero
            if GetCape() > 1500 and GetSRH() > 125 then
                self.reintensifychance = math.random(1, (self.reintensifyrange)) * (GetConVar("xt2_t_lifetime_autospawn"):GetInt() / 5)
                if self.reintensifychance == 1 and self.IsDynamicTornado == false then
                    self.IsMaxWinds = false
                    self.MaxWindsRerolled = GetMaxWindsForAutospawn(self.IsAnticyclonic)
                    if self.MaxWindsRerolled > self.MaxWinds then
                        self.MaxWinds = self.MaxWindsRerolled
                    end
                end
            end
            if self.IsDynamicTornado == true and self.IsMaxWinds == false then
                self.Force = self.Force + self.ForceAdderDynamic
            elseif self.IsDynamicTornado == true and self.IsMaxWinds == true then
                self.Force = self.Force - self.ForceSubtracterDynamic
            end
            if self.IsMaxWinds == false and TornadoesInWorldShouldStartTickingDown2 == false and GetCape() > 850 and self.IsDynamicTornado == false then
                self.Force = self.Force + ((1*( GetSRH() /200) + 0.5) * (GetConVar("xt2_t_lifetime_autospawn"):GetInt() / 5)) -- if SELF WINDS IS FALSE THEN do fancy math to calculate the speed at which it increases in strength
            elseif self.IsMaxWinds == true and self.JustInitialized ~= true and TornadoesInWorldShouldStartTickingDown2 == false and self.IsDynamicTornado == false then
                self.Force = self.Force - ((0.7*( 2000 / GetCape() ) + 1.5) * (GetConVar("xt2_t_lifetime_autospawn"):GetInt() / 5)) -- if SELF WINDS IS TRUE THEN do fancy math to calculate the speed at which it decreases in strength.
            elseif GetCape() <= 850 and self.JustInitialized ~= true and self.IsDynamicTornado == false then
                self.Force = self.Force - (1.25 * (GetConVar("xt2_t_lifetime_autospawn"):GetInt() / 5)) -- if cape is less than 850 then tornadoes should automatically decrease pre quick
            elseif TornadoesInWorldShouldStartTickingDown2 == true or globalThunderstormCount == 0 and self.IsDynamicTornado == false then
                self.Force = self.Force - (1.8  * (GetConVar("xt2_t_lifetime_autospawn"):GetInt() / 5))
            end
            self.Windspeedmultifordamage2 = (self.Force + 75) - (self.Force * (0.001*self.Force)) 	--0.001 is the gradient value to scale props unfreezing along a gradient EF-0 EF-5 etc,. (changing it to 0.002 makes EF-5s do significantly less damage in contrast to other tornado types etc,.)
            self.weldf = math.Clamp(170 * 3000000000 / (self.Windspeedmultifordamage2 * 0.35 * self.Windspeedmultifordamage2 * 0.5 * self.Windspeedmultifordamage2 * 0.8 * self.Windspeedmultifordamage2) / 10, 1, 10000)
        end

        
        function self:UpdateParamsListAutospawn()
            if self:IsValid() and self.sFScale >= 0 then
                self.GeneralForceMultiplier = self:ForceMultiplierFunctionAutospawn(1.3, 1.9)
                self.HeightForceMultiplier = self:ForceMultiplierFunctionAutospawn(4.8, 25)
            else
                return
            end
        end

        function self:UpdateElseAutospawn()
            if self.IsAutospawn == true and self.IsDynamicTornado == false then
                self.speedmult = (0.2*(( 0.9 * GetSRH() / 400) + 0.5)^3.55) + 0.4
            end
            if self.IsDynamicTornado == true and self.IsAutospawn == false then
                self.speedmult = 0.6
            end
        end

        function self:UpdateRotforceAutospawn()
            if self.IsAnticyclonic == false and self.Force < 200 then
                self.rotforce = -(self.Force / 1.05)
            elseif self.IsAnticylonic == true and self.Force < 200 then
                self.rotforce = (self.Force / 1.05)
            end
        end

        function self:UpdateFujitaValue()
            if self.Force >= 65 and self.Force <= 85 then
                self.sFScale = 0
            elseif self.Force >= 65 and self.Force <= 110 then
                self.sFScale = 1
            elseif self.Force >= 65 and self.Force <= 135 then
                self.sFScale = 2
            elseif self.Force >= 65 and self.Force <= 165 then
                self.sFScale = 3
            elseif self.Force >= 65 and self.Force <= 200 then
                self.sFScale = 4
            elseif self.Force >= 65 and self.Force <= 500 then
                self.sFScale = 5
            else
                return
            end
        end

        net.Receive("AttachParticleClients", function()
            local ent = net.ReadEntity()
            local particleName = net.ReadString()
            net.Start("UpdateEntityParticle")
            net.WriteEntity(ent)
            net.WriteString(particleName)
            net.Broadcast()
        end)
    
                -- Keep in mind : These functions update every 3 secs to when doing math for rates keep this in mind. The average tornado lifetime is also around 250 seconds from experience as well assuming a slight risk -- FORTYFOURs lil notes for himself again.
    
        -- Update particle types based on dynamic conditions
        function self:particleTypesUpdateMatrix()
            local srh = GetSRH()
    
            if self.JustInitialized == true then
                if (self.range >= 5000 and math.random(1, 3) == 1) or (math.random(1, 6) == 1) and self.IsAnticyclonic == false then
                    table.insert(self.CurrentAutospawnParticleTypeFlags, "MULTI-VORTEX")
                else
                    table.insert(self.CurrentAutospawnParticleTypeFlags, "NORMAL")
                end
            end
    
            -- Handle MULTI-VORTEX logic
            if srh >= 200 then
                local chance = ( math.floor(250 - 210 * (srh - 200) / (450 - 200)) )
                if math.random(1, (chance/3) * self.AutospawnEventChanceMultiplier) == 1 and not table.HasValue(self.CurrentAutospawnParticleTypeFlags, "MULTI-VORTEX") and self.IsAnticyclonic == false then
                    table.insert(self.CurrentAutospawnParticleTypeFlags, "MULTI-VORTEX")
                    table.RemoveByValue(self.CurrentAutospawnParticleTypeFlags, "NORMAL")
                end
            end
    
            -- Handle DRILLBIT logic
            if self.range >= 3500 and self.range <= 6500 and self.sFScale >= 3 then
                if math.random(1, 20* self.AutospawnEventChanceMultiplier) == 1 and not table.HasValue(self.CurrentAutospawnParticleTypeFlags, "DRILLBIT") and self.IsAnticyclonic == false then
                    table.insert(self.CurrentAutospawnParticleTypeFlags, "DRILLBIT")
                    table.RemoveByValue(self.CurrentAutospawnParticleTypeFlags, "NORMAL")
                end
            end
    
            -- Ensure NORMAL and MULTI-VORTEX cannot coexist
            if table.HasValue(self.CurrentAutospawnParticleTypeFlags, "MULTI-VORTEX") and table.HasValue(self.CurrentAutospawnParticleTypeFlags, "NORMAL") then
                table.RemoveByValue(self.CurrentAutospawnParticleTypeFlags, "NORMAL")
            end
            if not table.HasValue(self.CurrentAutospawnPhaseFlags, "BIRTH") and math.random(1, 15* self.AutospawnEventChanceMultiplier) == 1 then
                self.CurrentAutospawnParticleTypeFlags = {"NORMAL"}
            end
            if table.HasValue(self.CurrentAutospawnPhaseFlags, "MULTI-VORTEX") and math.random(1, 10) == 1 then
                table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "MULTI-VORTEX")
                if table.HasValue(self.CurrentAutospawnPhaseFlags, "VORTEX-BREAKDOWN") then
                    table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "VORTEX-BREAKDOWN")
                end
                if !table.HasValue(self.CurrentAutospawnPhaseFlags, "NORMAL") then
                    table.insert(self.CurrentAutospawnParticleTypeFlags, "NORMAL")
                end
            end
            if self.CurrentAutospawnPhaseFlags == {} then
                self.CurrentAutospawnPhaseFlags = {"NORMAL"}
            end


            self.JustInitialized = false
        end
    
        function self:BumpWindspeedsForASecLol(timerNameVortexBreakdown) -- Handles vortex breakdown windfield logic and such.
            self.PauseIsMaxWindsVB = true
            self.Force = self.Force * 1.75
            timer.Create(tostring(timerNameVortexBreakdown), math.random(3, 5), 1, function()
                if self:IsValid() then
                    self.Force = self.Force / 1.75
                    self.PauseIsMaxWindsVB = false
                end
            end)
        end
    
    
        -- Update phases based on conditions
        function self:particlePhasesUpdateMatrix()
            if self.Force < 86 and self.isTornado and self.IsAutospawn and not self.IsMaxWinds then
                if not table.HasValue(self.CurrentAutospawnPhaseFlags, "BIRTH") then
                    table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "MAIN")
                    table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "DEATH")
                    table.insert(self.CurrentAutospawnPhaseFlags, "BIRTH")
                end
            end
    
            if math.random(1, 10 * self.AutospawnEventChanceMultiplier) == 1 and self.sFScale >= 1 then
                table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "BIRTH")
                table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "DEATH")
                if not table.HasValue(self.CurrentAutospawnPhaseFlags, "MAIN") then
                    table.insert(self.CurrentAutospawnPhaseFlags, "MAIN")
                end
            end
    
            if self.sFScale >= 3 and table.HasValue(self.CurrentAutospawnPhaseFlags, "BIRTH") or self.sFScale >= 3 and table.HasValue(self.CurrentAutospawnPhaseFlags, "DEATH") then
                table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "BIRTH")
                table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "DEATH")
                if not table.HasValue(self.CurrentAutospawnPhaseFlags, "MAIN") then
                    table.insert(self.CurrentAutospawnPhaseFlags, "MAIN")
                end
            end
    
            if self.Force < 86 and self.IsMaxWinds then
                if not table.HasValue(self.CurrentAutospawnPhaseFlags, "DEATH") then
                    table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "MAIN")
                    table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "BIRTH")
                    table.insert(self.CurrentAutospawnPhaseFlags, "DEATH")
                end
            end
    
            if table.HasValue(self.CurrentAutospawnParticleTypeFlags, "MULTI-VORTEX") and not table.HasValue(self.CurrentAutospawnPhaseFlags, "VORTEX-BREAKDOWN") and math.random(1, 35 * self.AutospawnEventChanceMultiplier) == 1 and self.IsAnticyclonic == false then
                table.insert(self.CurrentAutospawnPhaseFlags, "VORTEX-BREAKDOWN")
            end
    
            if table.HasValue(self.CurrentAutospawnPhaseFlags, "VORTEX-BREAKDOWN") and math.random(1, 10* self.AutospawnEventChanceMultiplier) == 1 then
                table.RemoveByValue(self.CurrentAutospawnPhaseFlags, "VORTEX-BREAKDOWN")
            end
    
            if table.HasValue(self.CurrentAutospawnPhaseFlags, "VORTEX-BREAKDOWN") and math.random(2, 3*self.AutospawnEventChanceMultiplier) == 1 and self.IsAnticyclonic == false then
                local timerName = tostring(self).."vortexbreakdowntimer"..tostring(self:EntIndex())
                self:BumpWindspeedsForASecLol(timerName)
            end
        end
    
        -- Update target range based on phase flags
        function self:targetRangeMatrix()
            -- First, check if the current range has reached the target range
            if !self.targetrange then -- If this is true (on initialization) it overrides the script below and forces a generated target range etc,.
                self.targetrange = self.range
            end
            if self.IsMaxWinds == true and self.sFScale <= 2 and math.random(1, 12) == 1 then
                self.targetrange = math.random(1500, 2250)
                self.UpdateRangeSpeed = (math.random(75, 350)) * self.AutospawnRangeClimbRateMultiplier
                self.RangeEqualOverride = true
            elseif self.IsMaxWinds == false then
                self.RangeEqualOverride = false
            end
    
            if self.range == self.targetrange and not self.RangeEqualOverride then
                -- Decide the new target range based on phase flags
                if table.HasValue(self.CurrentAutospawnPhaseFlags, "BIRTH") or table.HasValue(self.CurrentAutospawnPhaseFlags, "DEATH") then
                    self.targetrange = math.random(1500, 8000)
                elseif table.HasValue(self.CurrentAutospawnPhaseFlags, "MAIN") then
                    self.targetrange = math.random(2500, 12000)
                end
            end
            
            -- Ensure the speed variable is a property of self and is independent for each entity
            if not self.UpdateRangeSpeed and not self.RangeEqualOverride then
                self.UpdateRangeSpeed = (math.random(10, 125)) * self.AutospawnRangeClimbRateMultiplier
            end
        
            -- Approach the target range
            if math.abs(self.range - self.targetrange) > self.UpdateRangeSpeed then
                self.range = self.range + (self.targetrange > self.range and self.UpdateRangeSpeed or -self.UpdateRangeSpeed)
                if not self.RangeEqualOverride then
                    self.UpdateRangeSpeed = (math.random(10, 125)) * self.AutospawnRangeClimbRateMultiplier
                end
            else
                self.range = self.targetrange -- If the target is within one 'speed' step, finalize the range value
                if not self.RangeEqualOverride then
                    self.UpdateRangeSpeed = (math.random(10, 125)) * self.AutospawnRangeClimbRateMultiplier
                end
            end
        end
    
        -- Check whether an update is needed for the particle system
        function self:ShouldAutospawnParticleUpdate()
            local currentTime = CurTime()
            if not self.lastParticleUpdate or (currentTime - self.lastParticleUpdate) > self.MinParticleUpdateTime then
                self.lastParticleUpdate = currentTime
                return true
            end
            return false
        end
    
        function self:RunAutoSpawnUpdate()
            local timerName = tostring(self).."autospawntimer"..tostring(self:EntIndex())
            timer.Create(timerName, 3, 1, function()
                if self:IsValid() then
                    self:UpdateForceAutospawn()
                    self:UpdateParamsListAutospawn()
                    self:UpdateElseAutospawn()
                    self:UpdateRotforceAutospawn()
                    self:UpdateFujitaValue()
                    self:targetRangeMatrix()
                    self.InnerFunnelDistance = self.range / 6
                    self.desiredOrbitRadius = self.range / 1.5
                    self.CurrentRangeTierSelected = math.ceil((self.range - 2000) / 1500) + 1
                    self.SaveCurrentStateParticles = {self.CurrentAutospawnParticleTypeFlags, self.CurrentAutospawnPhaseFlags, self.CurrentAutospawnWallcloudColor, self.CurrentRangeTierSelected}
                    local currentTime = CurTime()
                    if not self.lastParticleUpdate or (currentTime - self.lastParticleUpdate) > self.MinParticleUpdateTime and self.SaveOldStateParticles ~= self.SaveCurrentStateParticles or self.JustInitialized then
                        self:particleTypesUpdateMatrix()
                        self:particlePhasesUpdateMatrix()
                        self.SaveOldStateParticles = self.SaveCurrentStateParticles
                    end
                    self:UpdateEntParticleSystem()
                    self:SetNWFloat( "Rotforce", self.rotforce )
                    self:SetNWFloat( "Windspeed", self.Force )
                    self:SetNWFloat( "Windfield", self.range )
                    self:SetNWFloat( "Subvorts", self.Subvorts )
                    self:RunAutoSpawnUpdate()
                end
            end)
        end
        if (self:IsValid() and self.IsAutospawn == true) or (self:IsValid() and self.IsDynamicTornado == true) then
            self:RunAutoSpawnUpdate()
        end

        -- Handling the update of entity particles based on conditions
        function self:UpdateEntParticleSystem()
            if not self:ShouldAutospawnParticleUpdate() then return end
            local particleInfo = UpdateEntParticleXT2(self)  -- Assume this returns {name = "particleName", subvorts = true/false}
            if particleInfo then
                self.Subvorts = particleInfo.subvorts

                if particleInfo.name == nil then
                    print("Hi bug-testers, you're probably wondering why you're setting this message, its due to the fact that at this exact moment, I knew I wanted to kill myself, the immediate moment that this message popped up in my console I knew that I done fucked up with the formatting of this script so fucking bad that it might very well be irredeemable - FORTYFOUR. (lol jk but thats what I initially thought)")
                end
                -- Check if there is a new particle and it's different from the old one
                if self.oldParticleName ~= particleInfo.name and particleInfo.name ~= nil then
                    -- Remove the old particle if it exists
                    if self.oldParticleName ~= "" then
                        net.Start("RemoveEntityParticle")
                        net.WriteEntity(self)
                        net.WriteString(self.oldParticleName)
                        net.Broadcast()
                    end

                    if not table.HasValue(self.PrecachedParticlesAutospawn, particleInfo.name) then
                        PrecacheParticleSystem(particleInfo.name)
                        table.insert(self.PrecachedParticlesAutospawn, particleInfo.name)
                    end
                    net.Start("PrecacheClientside")
                    net.WriteEntity(self)
                    net.WriteString(particleInfo.name)
                    net.Broadcast()

                    -- Update the old particle name tracking
                    self.oldParticleName = tostring(particleInfo.name)
                end
            end
        end
    end
end

local delaytime = CurTime()

function ENT:ApplyRFDEffect()
    for i, ply in ipairs( player.GetAll() ) do
        if CLIENT then
            if ply == LocalPlayer() then
                local WindRFD = self:GetNWFloat("RFDSpeeds") or 0
                if self.OldWindRFD ~= WindRFD then
                    self.OldWindRFD = WindRFD
                    local RFDOrientation = self:GetNWInt("rfdorientation") or 1
                    if GetIsPausedState() ~= true and GetConVar("xt2_debriseffect"):GetInt() == 1 and (self.Tornadic == true or self.isTornado == true) and WindRFD and WindRFD >= 70 and (GetConVar("xt2_rfdsimulation"):GetInt() or self.HasRFD) == 1 and RFDOrientation == 4 then
                        ParticleEffect("rearflankdowndraft", ply:GetPos(), Angle(0,0,0) )
                    elseif GetIsPausedState() ~= true and GetConVar("xt2_debriseffect"):GetInt() == 1 and (self.Tornadic == true or self.isTornado == true) and WindRFD and WindRFD >= 70 and (GetConVar("xt2_rfdsimulation"):GetInt() or self.HasRFD) == 1 and RFDOrientation == 1 then
                        ParticleEffect("rearflankdowndraft2", ply:GetPos(), Angle(0,0,0) )
                    elseif GetIsPausedState() ~= true and GetConVar("xt2_debriseffect"):GetInt() == 1 and (self.Tornadic == true or self.isTornado == true) and WindRFD and WindRFD >= 70 and (GetConVar("xt2_rfdsimulation"):GetInt() or self.HasRFD) == 1 and RFDOrientation == 3 then
                        ParticleEffect("rearflankdowndraft3", ply:GetPos(), Angle(0,0,0) )
                    elseif GetIsPausedState() ~= true and GetConVar("xt2_debriseffect"):GetInt() == 1 and (self.Tornadic == true or self.isTornado == true) and WindRFD and WindRFD >= 70 and (GetConVar("xt2_rfdsimulation"):GetInt() or self.HasRFD) == 1 and RFDOrientation == 2 then
                        ParticleEffect("rearflankdowndraft4", ply:GetPos(), Angle(0,0,0) )
                    else
                        break
                    end
                end
            end
        end
    end
end

function ENT:testing()
    if SERVER then
        self.pos = self:GetPos()
        self.dir = (self.trnt - self.pos):GetNormalized()
        self.speedmult = self.speedmult or 1 -- Assuming a default if not set
        self.Speed = GetConVar("xt2_xspeed"):GetFloat() * self.speedmult * 36

        self.tr = util.TraceLine({
            start = self:GetPos() + Vector(rnd(-0.2, 0.2), rnd(-0.2, 0.2), 2000),
            endpos = self:GetPos() - Vector(0, 0, 10000),
            mask = MASK_WATER + MASK_SOLID_BRUSHONLY
        })

        if self.tr.Hit then
            self:SetPos(self.tr.HitPos + self.dir * self.Speed + Vector(0, 0, 20))
        else
            self:SetPos(self.pos + self.dir * self.Speed)
        end

        if math.random(1, rnd(1, 700)) == 1 then
            self.trnt = self.pos + (self.dir + Vector(rnd(-0.2, 0.2), rnd(-0.2, 0.2), 0)) * 58000
        end

        self.hitwall = util.TraceLine({
            start = self.pos + Vector(0, 0, 1000),
            endpos = self.pos + Vector(0, 0, 1000) + (self.dir * self.Speed * 2),
            mask = MASK_WATER + MASK_SOLID_BRUSHONLY,
            filter = self,
        })

        if self.hitwall.Hit or not self:IsInWorld() then
            self.offsetPoint = self.hitwall.HitPos - (self.dir * 200)
            -- Fix to correctly reference self.dir
            self.trnt = self.offsetPoint + (self.dir - 2 * (self.dir:Dot(self.hitwall.HitNormal)) * self.hitwall.HitNormal) * self.pos:Distance(self.trnt)
            self.RapidDirectionChange = true
        end

        -- Ensure unique delaytime for each entity
        self.delaytime = self.delaytime or CurTime()
        self.OldPos = self.OldPos or self:GetPos()

        if self.delaytime - CurTime() <= -1 then
            self.delaytime = CurTime()
            local vel = (self.OldPos - self:GetPos()):Length()
            self.OldPos = self.OldPos or self:GetPos() -- Initialize OldPos if not already set
            if self.rotforce > 0 then
                local posydiff = self.pos.y - self.OldPos.y
                local posxdiff = self.pos.x - self.OldPos.x
                if self.pos.x ~= self.OldPos.x and math.abs(posxdiff) > math.abs(posydiff) then
                    self.RFDOrientation = self.pos.x > self.OldPos.x and 3 or 4
                elseif self.pos.y ~= self.OldPos.y and math.abs(posydiff) > math.abs(posxdiff) then
                    self.RFDOrientation = self.pos.y > self.OldPos.y and 2 or 1
                end
                self:SetNWInt("rfdorientation", self.RFDOrientation or 1)
            else
                local posydiff = self.pos.y - self.OldPos.y
                local posxdiff = self.pos.x - self.OldPos.x
                if self.pos.x ~= self.OldPos.x and math.abs(posxdiff) > math.abs(posydiff) then
                    self.RFDOrientation = self.pos.x > self.OldPos.x and 1 or 2
                elseif self.pos.y ~= self.OldPos.y and math.abs(posydiff) > math.abs(posxdiff) then
                    self.RFDOrientation = self.pos.y > self.OldPos.y and 3 or 4
                end
                self:SetNWInt("rfdorientation", self.RFDOrientation or 1)
            end

            --print("MAN SHUTCHO BITCH ASS UP, (GHETTO SMOSH VOICE) Current Tornado Speed: " .. math.Round(vel / 16 / 3.281 / 1000 * 3600 * 0.621371192) .. " MPH")
            self.OldPos = self:GetPos()
        end
    end
end

function rnd(mi, ma) return math.random(1000) / 1000 * (ma - mi) + mi end
function CoolerLerp(a, b, t) return a + (b - a) * t end

local A = rnd(360,-360) 
local B = rnd(360,-360) 
local C = rnd(360,-360) 
local D = rnd(360,-360) 
local vary = 0

local Subvort1 = Vector(9990,0,0)
local Subvort2 = Vector(9990,0,0)
local Subvort3 = Vector(9990,0,0)
local Subvort4 = Vector(9990,0,0)

local subvorts = {
    Subvort1,
    Subvort2,
    Subvort3,
    Subvort4,
}

local Subvort1Alive = true
local Subvort2Alive = true
local Subvort3Alive = true
local Subvort4Alive = true
local ScouringChanceThang = 100

local selectedtime = 0

local guhtime = 0
local guhtime2 = 0
local rand = rnd(2,0.3)

local Subvortss
local Windspeed
local Range 
local Rotforce

local tempmass = 250 -- init tempmass (not important really even though it looks kinda important since it has a value assigned)

local SubvortUnweldForceDivisor = 2
local SubvortForceMultiplier = 2
local CompressDebrisHeightSubvorts = 0.5

function ENT:Think()
    self:testing()
    self:ApplyRFDEffect()
    if self.SpawnInInitTime and self.JustSpawned == true and (CurTime() - self.SpawnInInitTime) >= 1 then
        self.JustSpawned = false
    end

    for i, ply in ipairs( player.GetAll() ) do
        if CLIENT then

            Subvortss = self:GetNWFloat( "Subvorts", false )
            Windspeed = self:GetNWFloat( "Windspeed", 0 )
            Range = self:GetNWFloat( "Windfield", 0 )
            Rotforce = self:GetNWFloat( "Rotforce", -1 )

            if InsideTrigger == nil then
                InsideTrigger = true 
            end 
            
            if Subvortss == true and GetConVar("xt2_subscour"):GetInt() == 1 and Windspeed >= 185 then

				subvorts2 = {
					Subvort1,
					Subvort2,
					Subvort3,
					Subvort4,
				}
				
				if guhtime >= selectedtime then
					selectedtime = rnd(70,5)
					guhtime = 0 
					rand = rnd(2,0.3)
				end

				guhtime = guhtime + 1
				vary = CoolerLerp(vary, rand, 0.01)
		
				local SubvortRadius = Range * 0.25
	
				local degreesPerSecond1 = math.rad(Windspeed*0.008 * 0.35*5)
				local degreesPerSecond2 = math.rad(Windspeed*0.008 * 0.4*5)
				local degreesPerSecond3 = math.rad(Windspeed*0.008 * 0.3*5)
				local degreesPerSecond4 = math.rad(Windspeed*0.008 * 0.5*5)
	
				if Rotforce >= 0 then
					degreesPerSecond1 = math.rad(-Windspeed*0.008 * 0.35*5)
					degreesPerSecond2 = math.rad(-Windspeed*0.008 * 0.4*5)
					degreesPerSecond3 = math.rad(-Windspeed*0.008 * 0.3*5)
					degreesPerSecond4 = math.rad(-Windspeed*0.008 * 0.5*5)
				end
				
				A = (A + degreesPerSecond1) % (math.pi * 2)    
				B = (B + degreesPerSecond2) % (math.pi * 2) 
				C = (C + degreesPerSecond3) % (math.pi * 2)    
				D = (D + degreesPerSecond4) % (math.pi * 2)
			
				x1 = (math.cos(A) * SubvortRadius*1*vary) + self:GetPos()[1]
				y1 = (math.sin(A) * SubvortRadius*1*vary) + self:GetPos()[2]
			
				x2 = (math.cos(B) * SubvortRadius*0.5*vary) + self:GetPos()[1]
				y2 = (math.sin(B) * SubvortRadius*0.5*vary) + self:GetPos()[2]
			
				x3 = (math.cos(C) * SubvortRadius*0.8*vary) + self:GetPos()[1]
				y3 = (math.sin(C) * SubvortRadius*0.8*vary) + self:GetPos()[2]
			
				x4 = (math.cos(C) * SubvortRadius*0.3*vary) + self:GetPos()[1]
				y4 = (math.sin(C) * SubvortRadius*0.3*vary) + self:GetPos()[2]
			
				if subvort1 ~= nil then
					if util.IsInWorld(Subvort1) == true then
						Subvort1Alive = not Subvort1Alive
					end
				end

				if subvort2 ~= nil then
					if util.IsInWorld(Subvort2) == true then
						Subvort2Alive = not Subvort2Alive 
					end
				end

				if subvort3 ~= nil then
					if util.IsInWorld(Subvort3) == true then
						Subvort3Alive = not Subvort3Alive
					end
				end

				if subvort4 ~= nil then
					if util.IsInWorld(Subvort4) == true then
						Subvort4Alive = not Subvort4Alive
					end
				end
				
				local function rnd(a, b)
					return math.random() * (b - a) + a
				end
				
				local actions = {
					[1] = function() Subvort1Alive = not Subvort1Alive; A = rnd(360, -360) end,
					[2] = function() Subvort2Alive = not Subvort2Alive; B = rnd(360, -360) end,
					[3] = function() Subvort3Alive = not Subvort3Alive; C = rnd(360, -360) end,
					[4] = function() Subvort4Alive = not Subvort4Alive; D = rnd(360, -360) end,
					[5] = function() 
						Subvort1Alive = not Subvort1Alive; Subvort2Alive = not Subvort2Alive
						A = rnd(360, -360); B = rnd(360, -360)
					end,
					[6] = function() 
						Subvort3Alive = not Subvort3Alive; Subvort4Alive = not Subvort4Alive
						C = rnd(360, -360); D = rnd(360, -360)
					end,
					[7] = function() 
						Subvort1Alive = not Subvort1Alive; Subvort2Alive = not Subvort2Alive
						Subvort3Alive = not Subvort3Alive; Subvort4Alive = not Subvort4Alive
						A = rnd(360, -360); B = rnd(360, -360); C = rnd(360, -360); D = rnd(360, -360)
					end,
					[8] = function() 
						Subvort1Alive = true; Subvort2Alive = true; Subvort3Alive = true; Subvort4Alive = true
					end,
					[9] = function() 
						Subvort1Alive = false; Subvort2Alive = false; Subvort3Alive = false; Subvort4Alive = false
						A = rnd(360, -360); B = rnd(360, -360); C = rnd(360, -360); D = rnd(360, -360)
					end,
				}
				
				if math.random(1, 100) == 1 then
					local chooser = math.random(1, 9)
					if actions[chooser] then
						actions[chooser]()
					end
				end

				if Subvort1Alive == true then 
					Subvort1 = Vector(x1, y1, self:GetPos()[3])
				else
					Subvort1 = nil
				end
	
				if Subvort2Alive == true then
					Subvort2 = Vector(x2, y2, self:GetPos()[3])
				else
					Subvort2 = nil
				end
	
				if Subvort3Alive == true then
					Subvort3 = Vector(x3, y3, self:GetPos()[3])
				else
					Subvort3 = nil
				end
	
				if Subvort4Alive == true then
					Subvort4 = Vector(x4, y4, self:GetPos()[3])
				else
					Subvort4 = nil
				end
	
				for i = 1, #subvorts2 do
					local subv = subvorts2[i]
					if subv ~= nil then
						-- Perform a trace from above the subvort to below it
						local subvtrace = util.TraceLine({
							start = subv + Vector(0, 0, 500),
							endpos = subv + Vector(0, 0, -500),
							mask = MASK_SOLID,
							filter = self
						})
				
						-- Check if the trace hit something solid
						if subvtrace.Hit then
							-- Increment guhtime2 if we hit the ground
							guhtime2 = guhtime2 + 0.01
				
							-- Check if it's time to place a decal
							if guhtime2 >= 0.03 then
				
								-- Check if the hit entity is the world
								if subvtrace.Entity:IsWorld() then
									local decal = Material("decals/scorch1.png", "Scorch")
				
									-- Only apply the decal if the game isn't paused
									if GetIsPausedState() ~= true and guhtime2 >= 0.03 then
										util.DecalEx(decal, subvtrace.Entity, subvtrace.HitPos, (subvtrace.StartPos - subvtrace.HitPos), Color(63, 51, 31, math.random(5, 35)), 3, 3)
                                        guhtime2 = 0
									end
								end
							end
						end
					end
				end
            end
    
            if ply == LocalPlayer() then
                local dist = clamp((self:GetPos() - Vector(ply:GetPos()[1], ply:GetPos()[2], self:GetPos()[3])):Length(), 0, math.huge)
                local thresholdDistance = self.range * exponentialoffset
                -- Exponential height multiplier for tornado radius so players and props don't go flying when on the outer debris cloud
                local distheightmultiplier = dist > thresholdDistance and distheightexponent^ ((dist - thresholdDistance) / 1000) + 1 or 1
                if self.CustomAudio == false then
                    if GetConVar("xt2_arcadesounds"):GetInt() == 0 then
                        if self.DistantRoarLoop == nil and InsideTrigger == false then
                            self.DistantRoarLoop = CreateSound(ply, Sound("Tornado/DistantRoarLoop.wav"))
                            self.DistantRoarLoop:Play()
                        end
                    
                        if self.WindsRushingLoop == nil then
                            self.WindsRushingLoop = CreateSound(ply, Sound("Tornado/WindsRushingLoop.wav"))
                            self.WindsRushingLoop:Play()
                        end
                    
                        if self.CloseRoar == nil and self.Tornadic == true then
                            self.CloseRoar = CreateSound(ply, Sound("Tornado/CloseRoar.wav"))
                            self.CloseRoar:Play()
                        end
                    
                        if self.EarsPoppingBacksideLoop == nil and InsideTrigger == true and Windspeed >= 140 then
                            self.EarsPoppingBacksideLoop = CreateSound(ply, Sound("Tornado/EarsPoppingBacksideLoop.wav"))
                            self.EarsPoppingBacksideLoop:ChangeVolume(0)
                            self.EarsPoppingBacksideLoop:Play()
                        end
                    
                        if self.DistantRoarLoop ~= nil then
                            self.DistantRoarLoop:ChangeVolume(1 * (1.0 - dist/Range*0.35), 0.1)
                            if self.Tornadic == false then
                                self.DistantRoarLoop:ChangePitch(233)
                            end
                        end
                    
                        if self.WindsRushingLoop ~= nil then
                            self.WindsRushingLoop:ChangeVolume(2 * (1.0 - dist/Range*0.5), 0.1)
                        end
                    
                        if self.CloseRoar ~= nil then
                            self.CloseRoar:ChangeVolume(4 * (1.0 - dist/Range*0.65), 0.1)
                            self.CloseRoar:ChangePitch(math.Clamp(Windspeed*0.60, 0, 255), 0)
                        end
                    
                        if self.EarsPoppingBacksideLoop ~= nil then
                            self.EarsPoppingBacksideLoop:ChangeVolume(Windspeed*0.02 * (1.0 - dist/Range*1.3), 0)
                            self.EarsPoppingBacksideLoop:ChangePitch(math.Clamp(Windspeed*0.80, 0, 255), 0)
                        end
                    
                        if self.Tornadic == true or Windspeed >= 140 then
                            if dist <= Range then
                                InsideTrigger = true
                                if self.DistantRoarLoop ~= nil and InsideTrigger == true then
                                    self.DistantRoarLoop:Stop()
                                    self.DistantRoarLoop = nil
                                end
                            else
                                InsideTrigger = false
                                if self.EarsPoppingBacksideLoop ~= nil and InsideTrigger == false then
                                    self.EarsPoppingBacksideLoop:Stop()
                                    self.EarsPoppingBacksideLoop = nil
                                end
                            end
                        end
                        if self.DistantRoarLoop ~= nil and self.EarsPoppingBacksideLoop ~= nil then
                            self.DistantRoarLoop:Stop()
                            self.DistantRoarLoop = nil
                            self.EarsPoppingBacksideLoop:Stop()
                            self.EarsPoppingBacksideLoop = nil
                        end
                    else
                        if self.CloseRoar == nil then
                            self.CloseRoar = CreateSound(ply, Sound("Tornado/ArcadeTornadoLoop.wav"))
                            self.CloseRoar:Play()
                        end
                    
                        if self.CloseRoar ~= nil then
                            self.CloseRoar:ChangeVolume(0.7 * (1.0 - dist/Range*0.35), 0.1)
                            self.CloseRoar:ChangePitch(math.Clamp((Windspeed*0.5) * (1.5 - dist/Range*0.2), 50, 255), 0)
                        end
                    
                        if self.EarsPoppingBacksideLoop == nil then
                            self.EarsPoppingBacksideLoop = CreateSound(ply, Sound("Tornado/ArcadeTornadoInnerLoop.wav"))
                            self.EarsPoppingBacksideLoop:Play()
                        end
                    
                        if self.EarsPoppingBacksideLoop ~= nil then
                            self.EarsPoppingBacksideLoop:ChangeVolume(1 * (1.0 - dist/Range*0.45), 0.1)
                            self.EarsPoppingBacksideLoop:ChangePitch(math.Clamp((Windspeed*0.12) * (1.5 - dist/Range*0.45), 60, 100), 0)
                        end
                    end                    
                end

                if GetConVar("xt2_screenshake"):GetInt() == 1 and dist <= Range*1.25 and self.Tornadic == true and GetIsPausedState() ~= true then
                    local shakeval = Windspeed/20 * (1* (1.0 - dist/Range) +1.0 - dist/Range)
                    util.ScreenShake( ply:GetShootPos(), shakeval, 3, 0.1, 10000 )
                end
                if GetIsPausedState() ~= true and GetConVar("xt2_debriseffect"):GetInt() == 1 and self.Tornadic == true and dist <= Range*0.5 then
                    ParticleEffect("tor", ply:GetPos(), Angle(0,0,0) )
                else
                    break
                end
            end

        end
    end

    if SERVER then

        if math.random(1, self.LightningChance) == 1 and self.HasLightning then
            if GetConVar("xt2_lightningintornadoes"):GetInt() == 1 then
                local t = ents.Create("lightning_bolt")
                t:Spawn()
                if t:IsValid() then
                    local stv = self:GetPos() + Vector(math.random(-self.range * 1.1, self.range * 1.1), math.random(-self.range * 1.1, self.range * 1.1), 0)
                    local dontgoon = util.TraceLine({ start = stv, mask = MASK_SOLID_BRUSHONLY, endpos = stv + Vector(0, 0, 100000) })
                    t:SetPos(dontgoon.HitPos)
                    t:Setup()
                end
            end
        end

        if self.isderp then
            timer.Simple(25, function()
                if self.derptype == 1 and math.random(0, 4) == 0 then
                    local Shark = ents.Create("shark")
                    Shark:SetPos(self:GetPos() + Vector(math.random(-140, 140), math.random(-140, 140), math.random(600, 30)))
                    Shark:Spawn()
                end
            end)
        end

        if self.physdelstarttime - CurTime() <= -PhysDelay then
            self.physdelstarttime = CurTime()

            local e = ents.FindInSphere(self:GetPos() + Vector(0, 0, rnd(10000, 0)), self.range)
        
            for i = 1, #e do
                local v = e[i]
                
                if v:IsValid() and v != self and v:GetClass() ~= "gmod_ghost" and not v:IsWorld() and not v:IsWeapon() and v:GetClass() ~= "sent_anim" and not v:IsVehicle() and not IsLVSVehicle(v) == true then
                    local physobj = v:GetPhysicsObject()
                    if physobj:IsValid() then
                        
                        self.dist = math.max(0,(self:GetPos() - Vector(v:GetPos()[1], v:GetPos()[2], self:GetPos()[3])):Length())

                        v.xt2propdist = self.dist -- storing these for use
                        v.xt2proprange = self.range -- storing these for use
                        self.thresholdDistance = self.range * exponentialoffset
                        -- Exponential height multiplier for tornado radius so players and props don't go flying when on the outer debris cloud
                        self.distheightmultiplier = self.dist > self.thresholdDistance and distheightexponent^ ((self.dist - self.thresholdDistance) / 1000) + 1 or 1

                        local Trace = false 
                        local WindDefuseMult = 1
                        local WindUpdraftDefuseMult = 1

                        if GetConVar("xt2_windblockedbyobjects"):GetInt() == 1 or v:IsPlayer() or v:IsNPC() then
                            Trace, WindDefuseMult, WindUpdraftDefuseMult = TraceCheckWalls(v, self)  
                        else
                            Trace = false   
                        end

                        if Trace == false then
                            local origin = self:GetPos()
                            local vorigin = v:GetPos() 					
                            local Pull = (self:GetPos() - v:GetPos()):GetNormalized()
                            local Length = (self:GetPos() - v:GetPos()):GetNormalized():Length()
                            local ZDif = (Vector(0, 0, self:GetPos()[3]) - Vector(0, 0, v:GetPos()[3])):Length()
                            if !v.xt2pressure then
                                v.xt2pressure = self:CalculatePressureDrop(self.dist) or AtmosphericPressure
                            end
                            v.xt2pressure = self:CalculatePressureDrop(self.dist) or AtmosphericPressure
                            self.pressurefactor = (v.xt2pressure / AtmosphericPressure)^10

                            Pull = Vector(Pull.x, Pull.y, 0.125*clamp(1+(ZDif/(self.Force*0.015385*1 * rnd(-1.6, self.Force*0.015385*1.2 * (1.0 - ZDif/rnd(15000,50000)/(physobj:GetMass()*0.1) - 5*150)))), -3, 2.5)) --0.325
                            
                            Pull = Pull * ( (1-(Length/self.range))^3.3 ) --3.3
                            local force = Pull * (34000*(1^(self.Force*0.015385^1.425))) * (0.05+(5*0.2)) * (self.Force*0.015385*0.5) * (1.0 - (self.dist/self.range))
                            local force2 = Pull * (34000*(1^(self.Force*0.015385^1.425))) * (0.05+(5*0.2)) * (self.Force*0.015385*0.5) * (1.0 - (self.dist/self.range))  
                            local force3 = (((force*0.35 * self.inflowmult) + (force2*0.45))) * (1.0 - (self.dist/self.range))   --Adjust ratio between pull and spin
                            mass = 50 + physobj:GetMass()*0.1 * physobj:GetMass()*0.05 / self.Force * clamp(ZDif/1000,1,math.huge)
                            self.gMulThink = 1 * clamp(self.Force*0.01, 1, 8+mass) 
                            if v:IsOnGround() and !v:IsPlayer() and !v:IsNPC() then
                                mass = mass * 1.5
                                self.gMulThink = 0.75 * (1.0 - self.dist/self.range) 
                            end

                            local isRagdoll = v:IsRagdoll()
                            if isRagdoll == true then
                                local phys = v:GetPhysicsObject()
                                if IsValid(phys) then
                                    self.gMulThink = 10.33 * (1.0 - self.dist/self.range)
                                    phys:ApplyForceCenter( Vector(clamp((force3.x/2)/mass,-150,150),clamp((force3.y/2)/mass,-150,150),clamp((force3.z*2.5/2*self.distheightmultiplier + 1)/mass,-150,150)) * self.gMulThink *RagMult *2 * (1.0 - self.dist/self.range) )
                                end
                            end

                            if v:IsVehicle() then
                                self.gMulThink = 1.5 * (1.0 - self.dist/self.range) 
                                
                                local phys = v:GetPhysicsObject()
                                phys:AddAngleVelocity(Vector(0,500,100)* (1.0 - self.dist/self.range) * 1.5)
                            end

                            self.massAdjustmentFactor = 1
                            if not v:IsPlayer() and not v:IsNPC() then
                                local massobjectdata = v:GetPhysicsObject()
                                if IsValid(massobjectdata) then
                                    local tempmass = massobjectdata:GetMass()
                                    -- The higher this exponent, the less mass plays a factor
                                    self.massAdjustmentFactor = 1.4 / math.sqrt(tempmass)
                                end
                            else
                                self.massAdjustmentFactor = 1.4 / math.sqrt(tempmass)
                            end

                            if self.IsFirenado == true then
                                v:Ignite(5, 0)
                            end

                            if !v:IsPlayer() and !isRagdoll == true and !v:IsVehicle()  then
                                local dmg = DamageInfo()
                                function TakeDamage( victim, damage, attacker, inflictor ) dmg:SetDamage( damage ) dmg:SetAttacker( attacker ) dmg:SetInflictor( inflictor ) dmg:SetDamageType( DMG_PREVENT_PHYSICS_FORCE ) victim:TakeDamageInfo( dmg ) end

                                if self.dist <= self.range * 0.7 then 

                                    if self.derptype == 2 or self.Force >= 600 then
                                        if self.dist <= self.range * 0.15 then 
                                            if GetConVar("xt2_hurtprops"):GetInt() == 1 and v:IsValid() then 
                                                TakeDamage( v, 10000, self, self ) --Hurt stuff inside the funnel
                                                if ( constraint.HasConstraints( v )) and !v:IsVehicle() and IsLVSVehicle(v) == false then			
                                                    v:EmitSound("break" .. math.random(1, NumberOfBreakSoundFiles) .. ".mp3", 100)
                                                    constraint.RemoveAll(v)
                                                end
                                            end
                                        end
                                    else
                                        if GetConVar("xt2_hurtprops"):GetInt() == 1 and v:IsValid() then 
                                            TakeDamage( v, (1*(self.Force*0.15)) * (1.0 - self.dist/self.range), self, self ) --Hurt stuff inside the funnel
                                        end
                                    end
                                    self.tempweldfmain = self.weldf * ((self.range / 2000)^0.3)
                                    if GetConVar("xt2_windblockedbyobjects"):GetInt() == 1 then
                                        self.tempweldfmain = self.tempweldfmain / 1.12
                                    else
                                        self.tempweldfmain = self.tempweldfmain / 1.05
                                    end
                                    if GetConVar("xt2_rfdsimulation"):GetInt() == 0 then
                                        self.tempweldfmain = self.tempweldfmain / 1.05
                                    end
                                    if math.random(1, clamp((self.tempweldfmain / WindDefuseMult) * (0.0 + self.dist/self.range) / self.pressurefactor, 1, math.huge)) == 1 and GetConVar("xt2_unweldprops"):GetInt() == 1 then
                                        local p = v:GetPhysicsObject()	
                                        if p:IsValid() then 
                                            
                                            if ( constraint.HasConstraints( v )) and !v:IsVehicle() and !p:IsMotionEnabled() and IsLVSVehicle(v) == false then			
                                                v:EmitSound("break" .. math.random(1, 4) .. ".mp3", 100)
                                                constraint.RemoveAll(v)
                                            end

                                            if !p:IsMotionEnabled() then
                                                p:Wake()
                                                p:EnableMotion(true) 
                                            end  

                                        end
                                    end 
                                end

                            end
                                                        -- Scaling factors adjusted to decrease force with distance...
                            self.distanceFactor = (1 - (self.dist / self.range))^CompressDebrisHeight  -- This inverts the scaling just so that it lessens with distance
                            self.orbitCenter = Vector(self.pos.x, self.pos.y, self.pos.z) -- Orbit center adjusted below the tornado's position due to the offset that tornadoes have to ensure that nothing funky happens.
                            self.objectPos = v:GetPos()
                            self.toObjectVector = self.objectPos - self.orbitCenter
                            self.toObjectVector.z = 0 -- z Offset for rotation control point is 0, pre self explanatory. (by control point I mean the axis at which it targets the rotation around)
                            self.distanceFromCenter = self.toObjectVector:Length() -- Actual distance from the orbit center
                            self.toObjectDirection = self.toObjectVector:GetNormalized()
                            
                            -- Adjusting tangential direction to encourage rotation, fuck you gmod.
                            if self.rotforce > 0 then
                                self.pressurefactorvelocity = -0.4 * self.pressurefactor
                            else
                                self.pressurefactorvelocity = 0.4 * self.pressurefactor
                            end
                            self.tangentialDirection = Vector(-self.toObjectDirection.y, self.toObjectDirection.x, self.pressurefactorvelocity)
                            
                            -- Dynamically adjusting the force based on proximity to the target orbit radius
                            self.scale = 0.05  -- Increase to make the diminishing effect more aggressive, decrease to make it less so, please don't touch this though, i spent a while calibrating it.

                            -- Me adjusting the force based on proximity to target orbit radius
                            self.proximityFactor = (math.abs(self.distanceFromCenter - self.desiredOrbitRadius) / self.desiredOrbitRadius) * self.scale
                            self.adjustmentFactor = 1.0 - math.Clamp(self.proximityFactor, 0, 1) -- Reducing force as it gets closer to target orbit radius
                            
                            --Tangential velocity magnitude calculations here.
                            self.tangentialForceMagnitude = 20.0 * (1.5 + (1000 / self.range))^1.5 * (mass / 110) ^ 0.9
                            self.orbitalVelocityMagnitude = self.desiredOrbitRadius * -0.00045 * (1.0 + (4000 / self.range)) * self.rotforce * (self.Force / 160)
                            self.velocityToAdd = self.tangentialDirection * self.tangentialForceMagnitude * self.orbitalVelocityMagnitude * self.adjustmentFactor * self.distanceFactor * ((1.5 + (1000 / self.range))^1.5) * self.massAdjustmentFactor * self.pressurefactor * (50 / mass)
                            local finalVelocityToAdd = Vector(clamp(self.GeneralForceMultiplier*force3.x * WindDefuseMult /mass,-500,500), clamp(self.GeneralForceMultiplier*force3.y * WindDefuseMult /mass,-500,500), clamp(self.pressurefactor*ForceZMult*self.HeightForceMultiplier*force3.z/2^CompressDebrisHeight * WindDefuseMult * WindUpdraftDefuseMult * (1.0 - ZDif/rnd(8000,10000))/mass * self.gMulThink, -500,500)  )
                            if physobj:IsValid() and physobj:IsMotionEnabled() then 
                                physobj:AddVelocity(finalVelocityToAdd)
                            end	
                            if not v:IsPlayer() and not v:IsNPC() and not v:IsVehicle() then
                                local rotObject = v:GetPhysicsObject()
                                if rotObject:IsValid() and rotObject:IsMotionEnabled() then
                                    rotObject:AddVelocity(self.velocityToAdd * WindDefuseMult)
                                    self.gMulThink = 1.5 * (1.0 - self.dist/self.range) 
                                    rotObject:AddAngleVelocity(Vector(0,500,100)* (1.0 - self.dist/self.range) * self.Force * 0.0007)
                                end
                            end	
                        end
                    end		
                end
            end
                
            if self.Subvorts and GetConVar("xt2_subvorts"):GetInt() == 1 then

                subvorts = {
                    Subvort1,
                    Subvort2,
                    Subvort3,
                    Subvort4,
                }
                
                if guhtime >= selectedtime then
                    selectedtime = rnd(70,5)
                    guhtime = 0 
                    rand = rnd(2.5,0.3)
                end

                guhtime = guhtime + 1
                vary = CoolerLerp(vary, rand, 0.01)
        
                local SubvortRadius = self.range * 0.5
                local SubvortRange = self.range * 0.4
            
                local degreesPerSecond1 = math.rad(self.Force*0.04 * 0.35)
                local degreesPerSecond2 = math.rad(self.Force*0.04 * 0.4)
                local degreesPerSecond3 = math.rad(self.Force*0.04 * 0.3)
                local degreesPerSecond4 = math.rad(self.Force*0.04 * 0.5)

                if self.rotforce >= 0 then
                    degreesPerSecond1 = math.rad(-self.Force*0.09 * 0.35)
                    degreesPerSecond2 = math.rad(-self.Force*0.09 * 0.4)
                    degreesPerSecond3 = math.rad(-self.Force*0.09 * 0.3)
                    degreesPerSecond4 = math.rad(-self.Force*0.09 * 0.5)
                end
                
                A = (A + degreesPerSecond1) % (math.pi * 2)    
                B = (B + degreesPerSecond2) % (math.pi * 2) 
                C = (C + degreesPerSecond3) % (math.pi * 2)    
                D = (D + degreesPerSecond4) % (math.pi * 2)
            
                x1 = (math.cos(A) * SubvortRadius*1*vary) + self:GetPos()[1]
                y1 = (math.sin(A) * SubvortRadius*1*vary) + self:GetPos()[2]
            
                x2 = (math.cos(B) * SubvortRadius*0.5*vary) + self:GetPos()[1]
                y2 = (math.sin(B) * SubvortRadius*0.5*vary) + self:GetPos()[2]
            
                x3 = (math.cos(C) * SubvortRadius*0.8*vary) + self:GetPos()[1]
                y3 = (math.sin(C) * SubvortRadius*0.8*vary) + self:GetPos()[2]
            
                x4 = (math.cos(C) * SubvortRadius*0.3*vary) + self:GetPos()[1]
                y4 = (math.sin(C) * SubvortRadius*0.3*vary) + self:GetPos()[2]

                if subvort1 ~= nil then
                    if util.IsInWorld(Subvort1) == true then
                        Subvort1Alive = not Subvort1Alive
                    end
                end

                if subvort2 ~= nil then
                    if util.IsInWorld(Subvort2) == true then
                        Subvort2Alive = not Subvort2Alive 
                    end
                end

                if subvort3 ~= nil then
                    if util.IsInWorld(Subvort3) == true then
                        Subvort3Alive = not Subvort3Alive
                    end
                end

                if subvort4 ~= nil then
                    if util.IsInWorld(Subvort4) == true then
                        Subvort4Alive = not Subvort4Alive
                    end
                end

                local function rnd(a, b)
                    return math.random() * (b - a) + a
                end
                
                local actions = {
                    function()
                        Subvort1Alive = not Subvort1Alive
                        A = rnd(-360, 360)
                    end,
                    function() -- for chooser == 2
                        Subvort2Alive = not Subvort2Alive
                        B = rnd(-360, 360)
                    end,
                    function() -- for chooser == 3
                        Subvort3Alive = not Subvort3Alive
                        C = rnd(-360, 360)
                    end,
                    function() -- for chooser == 4
                        Subvort4Alive = not Subvort4Alive
                        D = rnd(-360, 360)
                    end,
                    function() -- for chooser == 5
                        Subvort1Alive = not Subvort1Alive
                        Subvort2Alive = not Subvort2Alive
                        A = rnd(-360, 360)
                        B = rnd(-360, 360)
                    end,
                    function() -- for chooser == 6
                        Subvort3Alive = not Subvort3Alive
                        Subvort4Alive = not Subvort4Alive
                        C = rnd(-360, 360)
                        D = rnd(-360, 360)
                    end,
                    function() -- for chooser == 7
                        Subvort1Alive = not Subvort1Alive
                        Subvort2Alive = not Subvort2Alive
                        Subvort3Alive = not Subvort3Alive
                        Subvort4Alive = not Subvort4Alive
                        A = rnd(-360, 360)
                        B = rnd(-360, 360)
                        C = rnd(-360, 360)
                        D = rnd(-360, 360)
                    end,
                    function() -- for chooser == 8
                        Subvort1Alive = true
                        Subvort2Alive = true
                        Subvort3Alive = true
                        Subvort4Alive = true
                    end,
                    function() -- for chooser == 9
                        Subvort1Alive = false
                        Subvort2Alive = false
                        Subvort3Alive = false
                        Subvort4Alive = false
                        A = rnd(-360, 360)
                        B = rnd(-360, 360)
                        C = rnd(-360, 360)
                        D = rnd(-360, 360)
                    end,
                }
                
                -- Main block for actually running the new chooser script.
                if math.random(1, 100) == 1 then
                    local chooser = math.random(1, 9)
                    if actions[chooser] then
                        actions[chooser]()
                    end
                end

                if Subvort1Alive == true then 
                    Subvort1 = Vector(x1, y1, self:GetPos()[3])
                else
                    Subvort1 = nil
                end

                if Subvort2Alive == true then
                    Subvort2 = Vector(x2, y2, self:GetPos()[3])
                else
                    Subvort2 = nil
                end

                if Subvort3Alive == true then
                    Subvort3 = Vector(x3, y3, self:GetPos()[3])
                else
                    Subvort3 = nil
                end

                if Subvort4Alive == true then
                    Subvort4 = Vector(x4, y4, self:GetPos()[3])
                else
                    Subvort4 = nil
                end

                for i = 1, #subvorts do
                    
                    local strengthmult = 1.3
                    local subv = subvorts[i]

                    if subv ~= nil then
                        ParticleEffect( "XTSubvortthing", subv, Angle(0,0,0), self)
            
                        local subvtrace = util.TraceLine( { start = subv + Vector(0 , 0 , 200), mask = MASK_SOLID, filter = self, endpos = subv + Vector(0 , 0 , -500) } )
                    
                        if subvtrace.Hit then
                            guhtime2 = guhtime2 + 0.01

                            if guhtime2 >= 0.03 then
                                guhtime2 = 0

                            end
                        end
                        

                        local e = ents.FindInSphere(subv + Vector(0, 0, rnd(10000,0)), SubvortRange )
            
                        for i = 1 , #e do
                            local v = e[i]
                            if v:IsValid() and v != self and not (v:GetClass() == "gmod_ghost") and !v:IsWorld() and !v:IsWeapon() and !v:IsNPC() and not (v:GetClass() == "sent_anim") then
                                local physobj = v:GetPhysicsObject()
                                if physobj:IsValid() then
                                    
                                    local dist = clamp((subv - Vector(v:GetPos()[1], v:GetPos()[2], subv[3])):Length(), 0, math.huge)
                                    local thresholdDistance = self.range * exponentialoffset
                                    -- Exponential height multiplier for tornado radius so players and props don't go flying when on the outer debris cloud
                                    local distheightmultiplier = dist > thresholdDistance and distheightexponent^ ((dist - thresholdDistance) / 1000) + 1 or 1

                                    local trace = {
                                        start = subv + Vector(0, 0, rnd(10000,10)),
                                        endpos = v:GetPos(),
                                        filter = self
                                    }
                
                                    tr = util.TraceLine( trace )
                                
                                    if guhtime >= selectedtime then
                                        selectedtime = rnd(70,5)
                                        guhtime = 0 
                                        rand = rnd(2.5,0.3)
                                    end
                                    guhtime = guhtime + 1

                                    if tr.Entity == v then
                
                                        local origin = subv
                                        local vorigin = v:GetPos() 					
                                        local Pull = (subv - v:GetPos())
                                        Pull:Normalize()
                                        local Pull2 = (subv - v:GetPos())
                                        Pull2:Normalize()
                                        local Length = Vector(Pull2.x,Pull2.y,0):Length()
                                        
                                        local ZDif = clamp((Vector(0,0,subv[3]) - Vector(0, 0, v:GetPos()[3])):Length(), 0, math.huge)
                                        --print(ZDif)
                    
                                        Pull = Vector(Pull.x, Pull.y, 0.125*clamp(1+(ZDif/(self.Force*0.015385*1*strengthmult * rnd(-1.6, self.Force*0.015385*1.2*strengthmult * (1.0 - ZDif/rnd(15000,50000)/(physobj:GetMass()*0.1) - 5*150)))), -3, 2.5)) --0.325
                    
                                        if v:IsPlayer() then
                                            Pull = Vector(Pull.x, Pull.y, 0.125*clamp(1+(ZDif/(self.sFScale * rnd(-1, 10 * (1.0 - ZDif/rnd(8000,0))))), -3, 2))
                                        end
                    
                                        Pull = Pull * ( (1-(Length/SubvortRange))^3.3 ) --3.3
                                        local force = Pull * (34000*(1^(self.Force*0.015385*strengthmult^1.425))) * (0.05+(5*0.2)) * (self.Force*0.015385*0.5*strengthmult) * (1.0 - dist/SubvortRange)
                                        local force2 = Pull * (34000*(1^(self.Force*0.015385*strengthmult^1.425))) * (0.05+(5*0.2)) * (self.Force*0.015385*0.5*strengthmult) * (1.0 - dist/SubvortRange)  
                                        force2:Rotate(Angle(0,self.rotforce * (1.0 - dist/SubvortRange), 0))
                                        local force3 = ((((force*0.35) + (force2*0.45))) * (1.0 - dist/SubvortRange) * 1.5) --Adjust ratio between pull and spin
                                        mass = (50 + physobj:GetMass()*0.1 * physobj:GetMass()*0.05 / self.Force * clamp(ZDif/1000,1,math.huge))*MassMult
                                        self.gMulSubvorts = 1 * clamp(self.Force*0.01, 1, 8+mass) 
                                        if v:IsOnGround() and !v:IsPlayer() then
                                            mass = mass * MassMult
                                            self.gMulSubvorts = 8.33 * (1.0 - dist/SubvortRange) 
                                        elseif  v:IsOnGround() and v:IsPlayer() then
                                            self.gMulSubvorts = 3.33 * (1.0 - dist/SubvortRange) 
                                        end
                    
                                        local isRagdoll = v:IsRagdoll()
                                        if isRagdoll == true then
                                            local phys = v:GetPhysicsObject()
                                            if IsValid(phys) and phys:IsMotionEnabled() then
                                                self.gMulSubvorts = 10.33 * (1.0 - dist/SubvortRange) 
                                                phys:ApplyForceCenter( Vector(clamp((force3.x/2)/mass,-150,150),clamp((force3.y/2)/mass,-150,150),clamp((force3.z/2)^CompressDebrisHeight*0.5/mass,-150,150)) * self.gMulSubvorts * (1.0 - dist/SubvortRange) )
                                            end
                                        end
                                        if v:IsVehicle() then
                                            self.gMulSubvorts = 1.1 * (1.0 - dist/SubvortRange) 
                                        end
                                        if IsLVSVehicle(v) == true then
                                            self.gMulSubvorts = 0.5 * (1.0 - dist/SubvortRange) 
                                        end
                                        
                                        if v:GetMoveType() != MOVETYPE_NOCLIP and (v:IsPlayer() or v:IsNPC()) and v:IsValid() then
                                            if v.AddVelocity and v:IsValid() then
                                                v:AddVelocity( Vector(clamp((self.GeneralForceMultiplier*force3.x/2)/mass,-150,150),clamp((self.GeneralForceMultiplier*force3.y/2)/mass,-150,150),clamp((self.HeightForceMultiplier*force3.z/2^CompressDebrisHeight*0.5* (1.0 - ZDif/rnd(6000,10000)) )/mass ,-150,150)) * self.gMulSubvorts*strengthmult * (1.0 - dist/SubvortRange))
                                            elseif v:IsValid() then
                                                v:SetVelocity( Vector(clamp((self.GeneralForceMultiplier*force3.x/2)/mass,-150,150),clamp((self.GeneralForceMultiplier*force3.y/2)/mass,-150,150),clamp((self.HeightForceMultiplier*force3.z/2^CompressDebrisHeight*0.5* (1.0 - ZDif/rnd(6000,10000)) )/mass ,-150,150)) * self.gMulSubvorts*strengthmult * (1.0 - dist/SubvortRange))
                                            end					
                                        end
                    
                                        TornadoRealisticDamage = true 

                                        if TornadoRealisticDamage == true and !v:IsPlayer() and !v:IsVehicle() and v.TimeInTornado ~= nil and v.TimeToSpendInTornado != nil then
                                            if v.TimeInTornado >= v.TimeToSpendInTornado then
                                                weightmult = rnd(500,1)
                                                mass = mass * 300000
                                            end
                                        end

                                        if (v:IsPlayer() and v:InVehicle()) or v:IsVehicle() then 
                    
                                        else
                                            if v:IsPlayer() and tr.HitWorld then 
                    
                                            else
                                                if !v:IsPlayer() and !isRagdoll == true and !v:IsVehicle()  then
                                                    local dmg = DamageInfo()
                                                    function TakeDamage( victim, damage, attacker, inflictor ) dmg:SetDamage( damage ) dmg:SetAttacker( attacker ) dmg:SetInflictor( inflictor ) dmg:SetDamageType( DMG_PREVENT_PHYSICS_FORCE ) victim:TakeDamageInfo( dmg ) end
                    
                                                    if dist <= SubvortRange * 0.7 then 
                                                        self.tempweldf = self.weldf * ((self.range / 2000)^0.3)
                                                        if GetConVar("xt2_hurtprops"):GetInt() == 1 and math.random(1, self.tempweldf) == 1 and v:IsValid() then 
                                                            TakeDamage( v, (1*(self.Force*0.07)) * (1.0 - dist/SubvortRange), self, self ) --Hurt stuff inside the funnel
                                                        end
                                                        if GetConVar("xt2_windblockedbyobjects"):GetInt() == 1 then
                                                            self.tempweldf = self.tempweldf / 1.12
                                                        else
                                                            self.tempweldf = self.tempweldf / 1.075
                                                        end
                                                        if GetConVar("xt2_rfdsimulation"):GetInt() == 1 then
                                                            self.tempweldf = self.tempweldf * 1.05
                                                        end

                                                        if math.random(1, clamp(self.tempweldf * (0.0 + dist/SubvortRange), 1, math.huge)) == 1 and GetConVar("xt2_unweldprops"):GetInt() == 1 then
                                                            local p = v:GetPhysicsObject()	
                                                            if p:IsValid() then 
                                                                
                                                                if ( constraint.HasConstraints( v )) and !v:IsVehicle() and !p:IsMotionEnabled() and IsLVSVehicle(v) == false then			
                                                                    v:EmitSound("break" .. math.random(1, 4) .. ".mp3", 100)
                                                                    constraint.RemoveAll(v)
                                                                end
                    
                                                                if !p:IsMotionEnabled() then
                                                                    p:Wake()
                                                                    p:EnableMotion(true) 
                                                                end   
                                                            end
                                                        end 
                                                    end
                                                end
                                            end
                                        end
                                        local finalAddedVelocity = Vector(clamp(force3.x/mass*SubvortForceMultiplier,-750,750), clamp(force3.y/mass*SubvortForceMultiplier,-750,750), clamp(force3.z^CompressDebrisHeightSubvorts * SubvortForceMultiplier * 3/2*0.5 * (1.0 - ZDif/rnd(8000,10000))/mass, -750,750))
                                        finalAddedVelocity = finalAddedVelocity * 1.5 * self.gMulSubvorts
                                        if v:GetClass() == "gmod_wire_anemometer" and v:IsValid() then
                                            local forceMagnitude = math.sqrt(finalAddedVelocity.x^2 + finalAddedVelocity.y^2 + finalAddedVelocity.z^2)
                                            local MagnitudeScaling = 0.05
                                            table.insert(v.xt2ForceListTotal, 2, forceMagnitude * self.gMulSubvorts * MagnitudeScaling)
                                        end	
                                        if physobj:IsValid() and physobj:IsMotionEnabled() then 
                                            physobj:AddVelocity(finalAddedVelocity)
                                        end		
                                    end
                                end	
                            end
                        end		
                    end
                end
        
            end

        end
        self.FullyInitTest = true

        self:NextThink(CurTime() + EngineUpdateDelay + engine.TickInterval())
        return true 
    end

end

function ENT:OnRemoveX()
    self:StopParticles() -- Lil safeguard for autospawn that should kill everything in case its outside of the map for the funny (if not then rip)
    if self.TimerNameFinal then
        if timer.Exists(self.TimerNameFinal) then
            timer.Remove(self.TimerNameFinal)
        end
    end
    if self.TimerNameRFD then
        if timer.Exists(self.TimerNameRFD) then
            timer.Remove(self.TimerNameRFD)
        end
    end
    if self.DistantRoarLoop ~= nil then  
        self.DistantRoarLoop:Stop() 
        self.DistantRoarLoop = nil 
    end
    if self.WindsRushingLoop ~= nil then  
        self.WindsRushingLoop:Stop() 
        self.WindsRushingLoop = nil 
    end
    if self.CloseRoar ~= nil then  
        self.CloseRoar:Stop() 
        self.CloseRoar = nil 
    end
    if self.EarsPoppingBacksideLoop ~= nil then  
        self.EarsPoppingBacksideLoop:Stop() 
        self.EarsPoppingBacksideLoop = nil 
    end
end

function ENT:UpdateMovementEnt()
    local lastUpdateTimeMovement = 0
    local updateIntervalMovement = 0.2
    local currentTimeNew = CurTime()
    if currentTimeNew - lastUpdateTimeMovement >= updateIntervalMovement then
        self:testing()
        lastUpdateTimeMovement = currentTimeNew
    end
end

function ENT:UpdateForcePlayersAndNPCs()
    if SERVER and self:IsValid() then
        self.pos2 = self:GetPos()
        -- Too lazy to unindent where the old timer was.. -- Indentation starts here.
            if !self:IsValid() then
                return
            else
                if CurTime() >= (self.StartUpdateTime + 0.5) then
                    local e = ents.FindInSphere(self:GetPos() + Vector(0, 0, rnd(10000, 0)), self.range)
                
                    for i = 1, #e do
                        local v = e[i]
                        
                        if v != self and v:GetClass() ~= "gmod_ghost" and not v:IsWorld() and not v:IsWeapon() and v:GetClass() ~= "sent_anim" and (IsLVSVehicle(v) == true) or v:IsVehicle() or v:IsPlayer() or v:IsNPC() and v:IsValid() then
                            local physobj = v:GetPhysicsObject()
                            if physobj:IsValid() and self:IsValid() then

                                self.distother = math.max(0,(self:GetPos() - Vector(v:GetPos()[1], v:GetPos()[2], self:GetPos()[3])):Length())

                                if !v.xt2pressure then
                                    v.xt2pressure = self:CalculatePressureDrop(self.distother) or AtmosphericPressure
                                end
                                v.xt2pressure = self:CalculatePressureDrop(self.distother) or AtmosphericPressure
                                self.pressurefactorPlayers = (v.xt2pressure / AtmosphericPressure)^5
                                self.thresholdDistance = self.range * exponentialoffset
                                -- Exponential height multiplier for tornado radius so players and props don't go flying when on the outer debris cloud
                                self.distheightmultiplier = self.distother > self.thresholdDistance and distheightexponent^ ((self.distother - self.thresholdDistance) / 1000) + 1 or 1


                                local Trace = false 
                                local WindDefuseMult = 1
                                local WindUpdraftDefuseMult = 1
        
                                if Trace == false then
                                    local Pull = (self:GetPos() - v:GetPos()):GetNormalized()
                                    local Length = (self:GetPos() - v:GetPos()):GetNormalized():Length()
                                    local ZDif = (Vector(0, 0, self:GetPos()[3]) - Vector(0, 0, v:GetPos()[3])):Length()

                                    Pull = Vector(Pull.x, Pull.y, 0.125*clamp(1+(ZDif/(self.sFScale * rnd(-1, 10 * (1.0 - ZDif/rnd(8000,0))))), -3, 2))
                                    Pull = Pull * ( (1-(Length/self.range))^3.3 ) --3.3
                                    mass = 50 + physobj:GetMass()*0.1 * physobj:GetMass()*0.05 / self.Force * clamp(ZDif/1000,1,math.huge)
                                    self.gMulPlayers = 1 * clamp(self.Force*0.01, 1, 8+mass) 
                                    if  v:IsOnGround() and v:IsPlayer() or v:IsNPC() then
                                        self.gMulPlayers = 4.0 * (1.0 - self.distother/self.range) 
                                    elseif  !v:IsOnGround() and v:IsPlayer() or v:IsNPC() then
                                        self.gMulPlayers = 3.0 * (1.0 - self.distother/self.range) 
                                    end
                                    -- Scaling factors adjusted to decrease force with distance...
                                    self.distanceFactor = (1.0 - (self.distother / self.range))
                                    self.orbitCenter = Vector(self.pos2.x, self.pos2.y, self.pos2.z + 5000)
                                    self.objectPos = v:GetPos()
                                    self.toObjectVector = self.objectPos - self.orbitCenter
                                    self.toObjectVector.z = 0
                                    self.distanceFromCenter = self.toObjectVector:Length()
                                    self.toObjectDirection = self.toObjectVector:GetNormalized()
                                    self.tangentialDirection = Vector(-self.toObjectDirection.y, self.toObjectDirection.x, 0)
                                    self.scale = 0.1
                                    self.proximityFactor = (math.abs(self.distanceFromCenter - self.desiredOrbitRadius) / self.desiredOrbitRadius) * self.scale
                                    self.adjustmentFactor = 1.0 - math.Clamp(self.proximityFactor, 0, 7)
                                    self.tangentialForceMagnitude = 1.5 * (1.5 + (1000 / self.range))^1.5 * (mass / 110) ^ 0.9
                                    self.orbitalVelocityMagnitude = self.desiredOrbitRadius * -0.0005 * (1.0 + (4000 / self.range)) * self.rotforce * (self.Force / 160) * self.distanceFactor

                                    if v:IsVehicle() or IsLVSVehicle(v) == true then
                                        self.gMulPlayers = 1.75 * (1.0 - self.distother/self.range) 
                                        if IsLVSVehicle(v) == true then
                                            self.gMulPlayers = 1.9
                                        end
                                        local phys = v:GetPhysicsObject()
                                        phys:AddAngleVelocity(Vector(0,500,100)* (1.0 - self.distother/self.range) * self.Force * 0.0008)
                                        -- Base multipliers for scaling forces
                                        local massAdjustmentFactor
                                        if not v:IsPlayer() and not v:IsNPC() then
                                            local massobjectdata = v:GetPhysicsObject()
                                            if IsValid(massobjectdata) then
                                                local tempmass = massobjectdata:GetMass()
                                                -- The higher this exponent, the less mass plays a factor
                                                massAdjustmentFactor = 1.4 / math.sqrt(tempmass)
                                            end
                                        else
                                            massAdjustmentFactor = 0.1 / math.sqrt(tempmass)
                                        end

                                        self.rotationalForceMultiplier = (1.0 * 0.4 * -(self.rotforce) * (6000 / self.range) * 5.0)
                                        self.inwardForceMultiplier = (0.4 * 0.2 * math.abs(self.rotforce / 2) * (6000 / self.range) * 20)  -- Negative to pull towards the center
                                        self.heightForceMultiplier = ((0.5 * 0.8 * math.abs(self.Force) * (15000 / self.range * (self.Force / 80)) * 0.5) /125)  -- Upward force scaling
                                    
                                        self.distanceToCenter = (v:GetPos() - self.orbitCenter):Length2D()
                                        -- Adjust multipliers based on distance to center
                                        self.inwardForceMultiplier = self.inwardForceMultiplier * self.distanceFactor
                                        self.heightForceMultiplier = self.heightForceMultiplier * self.distanceFactor
                                        self.rotationalForceMultiplier = self.rotationalForceMultiplier * self.distanceFactor

                                        if v:IsOnGround() then
                                            self.inwardForceMultiplier = self.inwardForceMultiplier * 6
                                            self.heightForceMultiplier = self.heightForceMultiplier * 1.1
                                            self.rotationalForceMultiplier = self.rotationalForceMultiplier * 0.6
                                        else
                                            self.inwardForceMultiplier = self.inwardForceMultiplier * 5
                                            self.heightForceMultiplier = self.heightForceMultiplier * 0.9
                                            self.rotationalForceMultiplier = self.rotationalForceMultiplier * 0.6
                                        end
                                    
                                        self.generalHeightMultiplier = 0.06 * (self.distanceFactor)^CompressDebrisHeight -- General multiplier for height effect
                                    
                                        -- Height force calculation
                                        self.heightForce = self.distanceFactor * self.heightForceMultiplier * self.Force * self.generalHeightMultiplier
                                        self.heightForce = math.max(self.heightForce * WindUpdraftDefuseMult, 0)  -- Ensure it doesn't become negative
                                        -- Adjusting rotational direction based on self.rotforce sign
                                        self.directionMultiplier = self.rotforce < 0 and 1 or -1  -- Reverse direction based on directional sign for rotforce
                                        self.tangentialDirection = Vector(-self.toObjectDirection.y * self.directionMultiplier, self.toObjectDirection.x * self.directionMultiplier, 0)
                                        self.rotationalVelocity = self.tangentialDirection * self.rotationalForceMultiplier * -(self.rotforce) * self.distanceFactor
                                        -- Inward force calculation
                                        self.toCenterVector = (Vector(self.orbitCenter.x, self.orbitCenter.y, 0) - v:GetPos()):GetNormalized()  -- Corrected to ensure pull towards center
                                        self.inwardVelocity = (self.toCenterVector * self.inwardForceMultiplier * self.Force) * 4.0 * self.pressurefactorPlayers * (self.distanceFactor)^CompressDebrisHeight
                                        -- Combine forces, adjusting for upward pull and rotation direction
                                        self.finalVelocity = (self.rotationalVelocity + self.inwardVelocity) * self.PlayerNPCForceMult + Vector(0, 0, ((self.heightForce) or 0)) * self.pressurefactorPlayers / ( Vector(1, 1, 2) ) * 1.15 * massAdjustmentFactor
                                        local rotObject = v:GetPhysicsObject()
                                        if rotObject and rotObject:IsValid() then
                                            self.finalVelocity.z = self.finalVelocity.z / 10
                                            rotObject:AddVelocity((self.finalVelocity/100 / self.gMulPlayers)*WindDefuseMult * self.pressurefactorPlayers)
                                        end
                                    end
                                    if v:IsPlayer() or v:IsNPC() then
                                        -- Base multipliers for scaling forces

                                        self.rotationalForceMultiplier = (1.0 * 0.4 * -(self.rotforce) * (6000 / self.range) * 2) /7
                                        self.inwardForceMultiplier = (0.4 * 0.2 * math.abs(self.rotforce) * (6000 / self.range) * 4.75) /3.5  -- Negative to pull towards the center
                                        self.heightForceMultiplier = ((0.5 * 0.95 * math.abs(self.rotforce) * (15000 / self.range * (self.Force / 80)) * 0.5) /75)  -- Upward force scaling
                                    
                                        self.distanceToCenter = (v:GetPos() - self.orbitCenter):Length2D()
                                    
                                        -- Adjust multipliers based on distance to center
                                        self.inwardForceMultiplier = self.inwardForceMultiplier * self.distanceFactor
                                        self.heightForceMultiplier = self.heightForceMultiplier * self.distanceFactor
                                        self.rotationalForceMultiplier = self.rotationalForceMultiplier * self.distanceFactor

                                        if v:IsOnGround() then
                                            self.inwardForceMultiplier = self.inwardForceMultiplier * 1.0
                                            self.heightForceMultiplier = self.heightForceMultiplier * 3
                                            self.rotationalForceMultiplier = self.rotationalForceMultiplier * 1.0
                                        else
                                            self.inwardForceMultiplier = self.inwardForceMultiplier * 0.1
                                            self.heightForceMultiplier = self.heightForceMultiplier * 0.1
                                            self.rotationalForceMultiplier = self.rotationalForceMultiplier * 0.1
                                        end
                                    
                                        self.generalHeightMultiplier = 0.06 * (self.distanceFactor)^CompressDebrisHeight -- General multiplier for height effect
                                    
                                        -- Height force calculation
                                        self.heightForce = self.distanceFactor * self.heightForceMultiplier * self.Force * self.generalHeightMultiplier
                                        self.heightForce = math.max(self.heightForce * WindUpdraftDefuseMult, 0)  -- Ensure it doesn't become negative

                                        -- Adjusting rotational direction based on self.rotforce sign
                                        self.directionMultiplier = self.rotforce < 0 and 1 or -1  -- Reverse direction based on directional sign for rotforce
                                        self.tangentialDirection = Vector(-self.toObjectDirection.y * self.directionMultiplier, self.toObjectDirection.x * self.directionMultiplier, 0)
                                        self.rotationalVelocity = self.tangentialDirection * self.rotationalForceMultiplier * -(self.rotforce) * self.distanceFactor
                                        -- Inward force calculation
                                        self.toCenterVector = (self.orbitCenter - v:GetPos()):GetNormalized()  -- Corrected to ensure pull towards center
                                        self.inwardVelocity = (self.toCenterVector * self.inwardForceMultiplier * self.Force) * 2 * self.pressurefactorPlayers * (self.distanceFactor)^CompressDebrisHeight
                                    
                                        -- Combine forces, adjusting for upward pull and rotation direction
                                        self.finalVelocity = (self.rotationalVelocity + self.inwardVelocity) * self.PlayerNPCForceMult + Vector(0, 0, self.heightForce) * self.pressurefactorPlayers
                                        if v:IsPlayer() or v:IsNPC() and v:IsValid() then
                                            v:SetVelocity((self.finalVelocity / self.gMulPlayers)*WindDefuseMult * self.pressurefactorPlayers)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    local timerNameFinal = tostring(self:EntIndex())..tostring(self).."updateforcetimerforNPCSandsuch"
                    self.TimerNameFinal = timerNameFinal
                    timer.Create(timerNameFinal, 0.02, 1, function()
                        if self:IsValid() then
                            self:UpdateForcePlayersAndNPCs()
                        end
                    end)
                elseif self:IsValid() then
                    local timerNameFinal = tostring(self:EntIndex())..tostring(self).."updateforcetimerforNPCSandsuch"
                    self.TimerNameFinal = timerNameFinal
                    timer.Create(timerNameFinal, 0.02, 1, function()
                        if self:IsValid() then
                            self:UpdateForcePlayersAndNPCs()
                        end
                    end)
                end
            end
        -- Ok the weird indentation stops here. If you really want to you can just highlight all of this from where I say that I did the weird indentation and then just unindent all the way up to here by one tab.
    end
end

function ENT:RearFlankDowndraftSim()
    if SERVER and self:IsValid() then
        if GetConVar("xt2_rfdsimulation"):GetInt() == 1 then
            self.HasRFD = true
            -- Calculate current and previous positions to get movement vector
            local newPos = self:GetPos()
            local oldPos = self.OldPos2 or newPos  -- Initialize oldPos if nil at the time of RFD sim.
            local newMoveVector = (newPos - oldPos):GetNormalized()
            local oldMoveVector = self.LastMoveVector or newMoveVector
            local rapidChange = self.RapidDirectionChange or false
            local smoothFactor = 0.4
            if rapidChange == true then
                smoothFactor = 0
            end
            local offset = 0.7
            local moveVector = LerpVector(smoothFactor, oldMoveVector, newMoveVector)
            local leftVector = Vector(-moveVector.y*offset, moveVector.x*offset, 0)
            local backLeftVector = (moveVector + leftVector) * -0.3
            backLeftVector.z = 0
            leftVector.z = 0
            self.OldPos2 = newPos
            self.LastMoveVector = moveVector
            self.RapidDirectionChange = false

            for _, ent in pairs(ents.FindInSphere(newPos, self.range * 1.5)) do
                if ent:IsValid() and ent != self and not ent:IsWorld() and ent:GetClass() ~= "gmod_ghost" and ent:GetClass() ~= "sent_anim" then
                    local Trace = false 
                    local WindDefuseMult = 1
                    local WindUpdraftDefuseMult = 1
            
                    if GetConVar("xt2_windblockedbyobjects"):GetInt() == 1 or ent:IsPlayer() or ent:IsNPC() then
                        Trace, WindDefuseMult, WindUpdraftDefuseMult = TraceCheckWalls(ent, self)  
                    else
                        Trace = false   
                    end
                    if Trace == false then
                        local entPos = ent:GetPos()
                        local toEnt = (entPos - newPos):GetNormalized()
                        local dotProduct = toEnt:Dot(backLeftVector)
                        if dotProduct > 0 then
                            local CompressDebrisHeightRFD = 0.4
                            local distance = newPos:Distance(entPos)
                            local maxDistance = self.range * 1.5
                            local distanceFactor = (1 - (distance / maxDistance))
                            distanceFactor = math.max(0, math.min(1, distanceFactor))
                            local inwardForce = (newPos - entPos):GetNormalized() * self.Force * distanceFactor^CompressDebrisHeightRFD
                            local rotationDirection = (self.rotforce > 0 and 1 or -1) * leftVector
                            local rotationalForce = rotationDirection * self.Force * distanceFactor^CompressDebrisHeightRFD
                            rotationalForce.z = 0
                            rotationDirection.z = 0
                            inwardForce.z = 0
                            local finalForce = inwardForce + rotationalForce
                            local gMulRFD = 1
                            if ent:IsVehicle() then
                                gMulRFD = 0.9
                            elseif ent:IsPlayer() or ent:IsNPC() then
                                gMulRFD = 1.5
                            else
                                gMulRFD = 2.5
                            end
                            if IsLVSVehicle(ent) == true then
                                gMulRFD = 0.5
                            end
                            if ent:GetClass() == "gmod_wire_anemometer" and ent:IsValid() then
                                local forceMagnitude = math.sqrt(finalForce.x^2 + finalForce.y^2 + finalForce.z^2)
                                local MagnitudeScaling = 0.225
                                ent.xt2RFDForce = (forceMagnitude * gMulRFD) * MagnitudeScaling
                            
                                -- Inserting xt2RFDForce at the first position of the xt2ForceListTotal
                                table.insert(ent.xt2ForceListTotal, 1, ent.xt2RFDForce)
                            end
                            if ent:IsPlayer() or ent:IsNPC() then
                                if ent:IsPlayer() then
                                    local forceMagnitude = math.sqrt(finalForce.x^2 + finalForce.y^2 + finalForce.z^2)
                                    local MagnitudeScaling = 0.125
                                    local calculation = (forceMagnitude * gMulRFD) * MagnitudeScaling
                                end
                                local playerNPCDiv = 5
                                if ent:IsOnGround() and ent:IsValid() then
                                    ent:SetVelocity(finalForce/1.5/playerNPCDiv * WindDefuseMult)
                                elseif ent:IsValid() then
                                    ent:SetVelocity(finalForce/2/playerNPCDiv * WindDefuseMult)
                                end
                                local forceMagnitude = math.sqrt(finalForce.x^2 + finalForce.y^2 + finalForce.z^2)
                                local MagnitudeScaling = 0.125
                                local calculation = (forceMagnitude * gMulRFD) * MagnitudeScaling
                                self:SetNWFloat("RFDSpeeds", (calculation*2.25) or 0)
                            else
                                local gMulRotation = 0.2
                                if ent:IsVehicle() then
                                    gMulRotation = 0
                                end
                                if IsLVSVehicle(ent) == true then
                                    gMulRotation = 0
                                end
                                gMulRFD = gMulRFD * 2.5
                                local physobj = ent:GetPhysicsObject()
                                if physobj:IsValid() and physobj:IsMotionEnabled() then
                                    local physobjDiv = 5.0
                                    physobj:AddVelocity(finalForce/physobjDiv*gMulRFD)
                                    physobj:AddAngleVelocity(Vector(0,-400,100)* distanceFactor * finalForce/physobjDiv*gMulRFD * 0.02 * gMulRotation * WindDefuseMult)
                                end
                            end

                            if self.tempweldfmain then
                                local MagnitudeScaling = 0.5
                                local forceMagnitude = math.sqrt(finalForce.x^2 + finalForce.y^2 + finalForce.z^2)
                                local xt2RFDUnweldForce = ((forceMagnitude) * MagnitudeScaling)
                                local minUnweldForce = self.weldf -- The force at distanceFactor = 1 (closest)
                                local maxUnweldForce = 8000  -- The maximum unweld force at distanceFactor = 0 (furthest)
                                
                                -- Linear interpolation between minUnweldForce and maxUnweldForce
                                local unweldForce = minUnweldForce + (maxUnweldForce - minUnweldForce) * (1 - distanceFactor)
                                
                                -- Calculate unweldChance using the adjusted unweldForce
                                local unweldChance = (unweldForce / ((distanceFactor^CompressDebrisHeightRFD)) / WindDefuseMult) * (20 / xt2RFDUnweldForce)
                                if math.random(1, math.max(1, unweldChance)) == 1 and GetConVar("xt2_unweldprops"):GetInt() == 1 then
                                    if ent:GetPhysicsObject():IsValid() and !ent:IsVehicle() and constraint.HasConstraints(ent) and IsLVSVehicle(ent) == false then
                                        ent:EmitSound("break" .. math.random(1, NumberOfBreakSoundFiles) .. ".mp3", 100)
                                        constraint.RemoveAll(ent)
                                        local physobj = ent:GetPhysicsObject()
                                        if physobj:IsValid() then
                                            physobj:Wake()
                                            physobj:EnableMotion(true)
                                        end
                                    end
                                end 
                            end
                        end
                    end
                end
            end
            local timerNameRFD = tostring(self:EntIndex()) .. "_RFD_update_timer"
            self.TimerNameRFD = timerNameRFD
            timer.Create(timerNameRFD, 0.1, 0, function()
                if self:IsValid() then
                    self:RearFlankDowndraftSim()
                end
            end)
        else
            if self.HasRFD == true then
                self.HasRFD = false
            end
            local timerNameRFD = tostring(self:EntIndex()) .. "_RFD_update_timer"
            self.TimerNameRFD = timerNameRFD
            timer.Create(timerNameRFD, 0.1, 0, function()
                if self:IsValid() then
                    self:RearFlankDowndraftSim()
                end
            end)
        end
    end
end








