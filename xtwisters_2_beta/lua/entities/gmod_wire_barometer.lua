AddCSLuaFile()

if not WireLib then return end

DEFINE_BASECLASS( "base_wire_entity" )
ENT.PrintName       = "Wire Barometer"
ENT.WireDebugName	= "Barometer"
ENT.Force = 0
ENT.range = 0

local windyents = {}
ENT.AtmosphericPressureBASE = 101325 -- (PASCALS)
ENT.PAtoMILLIBARConversion = 100 -- 100 PA is 1 MB
ENT.PressureDropped = 0
ENT.Pressure = 101325
ENT.AdjustedPressure = 101325
ENT.SeaLevelZ = nil
ENT.PressureDroppedFactor = 101325
ENT.FindDifference = 0
ENT.xt2pressure = 101325

local function FindIfENTindexed(table, searchfor)
	for i, v in ipairs(table) do
		if v == searchfor then
			return true 
		elseif i==#table then
			return false 
		end
	end
end

if CLIENT then
    function ENT:Think()
        BaseClass.Think(self)
		local pressure = self:GetNWFloat("pressure", 0)
        local seaLevelZ = self:GetNWFloat("SeaLevelZ", 0) -- Default to 0 if not set
		if seaLevelZ == 0 then
			seaLevelZ = self:GetNWFloat("SeaLevelZ", 0)
		end
        local entityZ = self:GetPos().z

        local altitude = entityZ - seaLevelZ -- Calculate altitude only if seaLevelZ is valid

        -- Base parameters for pressure adjustment
        local P0 = 101325 -- Starting pressure at sea level

        -- Calculate adjusted pressure based on altitude
        local decreaseFactor = 0.0000025 --  this factor controls the sensitivity of the decrease
        self.AdjustedPressure = pressure * math.exp(-altitude * decreaseFactor)

        -- Display the adjusted pressure
        local txt = "CURRENT PRESSURE (PASCALS) = " .. tostring(math.Round(self.AdjustedPressure))
        self:SetOverlayText(txt)
        
        self:NextThink(CurTime() + 0.1)
        return true
    end
    return
end


local MODEL = Model("models/jaanus/wiretool/wiretool_speed.mdl")

function ENT:Initialize()
	self:SetModel( MODEL )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )

	self.Inputs = WireLib.CreateInputs(self, {"Recalibrate Pressure" })
	self.Outputs = Wire_CreateOutputs(self, {"PASCALS",  "MILLIBARS", "PASCALS DROPPED MAX", "MILLIBARS DROPPED MAX"})
end

function ENT:TriggerInput(iname, value)
	if iname == "Recalibrate Pressure" then
        self.Pressure = 101325
		self.AdjustedPressure = 101325
		self.PressureDropped = 0
		self.FindDifference = 0
	end
end

function ENT:Setup()
	local outs = {}
	outs = {"PASCALS",  "MILLIBARS", "PASCALS DROPPED MAX", "MILLIBARS DROPPED MAX" }

	Wire_AdjustOutputs(self, outs)
end

function ENT:Think()
    BaseClass.Think(self)
    
    -- Determine sea level if not already set
    if self.SeaLevelZ == nil then
        local traceStart = self:GetPos() + Vector(100, 100, 5000)
        local traceEnd = self:GetPos() - Vector(0, 0, 1000)
        local trace = util.TraceLine({
            start = traceStart,
            endpos = traceEnd,
            mask = MASK_WATER + MASK_SOLID, -- Include both water and solid ground in the trace
        })

        if trace.Hit then
            self.SeaLevelZ = trace.HitPos.z
            self:SetNWFloat("SeaLevelZ", self.SeaLevelZ) -- Store the value as a networked float for the client.
        end
    end

    -- Default pressure to atmospheric if no influences are found
    if #windyents == 0 then
        self.Pressure = self.AtmosphericPressureBASE
    end

	self.Pressure = self.xt2pressure or 0
	self.PressureDroppedFactor = self.xt2pressure or 0

    -- Calculate adjusted pressure based on altitude
-- Calculate adjusted pressure based on altitude
	local altitudeDifference = self:GetPos().z - self.SeaLevelZ
	local decreaseFactor = 0.0000025

	-- Calculate the current pressure drop from the base atmospheric pressure
	self.AdjustedPressure = self.Pressure * math.exp(-altitudeDifference * decreaseFactor)
	self.currentPressureDrop = self.AtmosphericPressureBASE - self.AdjustedPressure

	-- Initialize PressureDropped as nil for the first run or keep its value, nil is the flag im using to register whether PressureDropped is in a state in which it should update.
	if self.PressureDropped == nil then
		self.PressureDropped = self.currentPressureDrop
	else
		-- Update the maximum pressure drop if the current drop is larger than the previously recorded maximum
		if self.currentPressureDrop > self.PressureDropped then
			self.PressureDropped = self.currentPressureDrop
		end
	end

	-- Correcting logic for display: AdjustedPressure and the max drop from atmospheric pressure
	self:SetNWFloat("pressure", self.Pressure)

	-- Assuming self.PressureDropped correctly tracks the largest drop from AtmosphericPressureBASE cuz im a moron... (IT DOES!)
	-- Update Wiremod outputs
	Wire_TriggerOutput(self, "PASCALS", self.AdjustedPressure)
	Wire_TriggerOutput(self, "MILLIBARS", self.AdjustedPressure / self.PAtoMILLIBARConversion)
	
	-- For the lowest pressure experienced (assuming PressureDropped is the maximum observed drop)
	self.lowestPressureExperienced = self.AtmosphericPressureBASE - (self.PressureDropped) - (self.AtmosphericPressureBASE - self.PressureDroppedFactor)
	if self.AtmosphericPressureBASE - self.lowestPressureExperienced >= self.FindDifference then
		self.FindDifference = self.AtmosphericPressureBASE - self.lowestPressureExperienced
	end
	Wire_TriggerOutput(self, "PASCALS DROPPED MAX", self.FindDifference)
	Wire_TriggerOutput(self, "MILLIBARS DROPPED MAX", self.FindDifference / self.PAtoMILLIBARConversion)

	self:NextThink(CurTime()+0.1)
	
	return true
end

duplicator.RegisterEntityClass("gmod_wire_barometer", WireLib.MakeWireEnt, "Data")


