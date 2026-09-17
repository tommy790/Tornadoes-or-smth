AddCSLuaFile()

if not WireLib then return end

DEFINE_BASECLASS( "base_wire_entity" )
ENT.PrintName       = "Wire Anemometer"
ENT.WireDebugName	= "Anemometer"
ENT.Force = 0
ENT.range = 0

local windyents = {}
ENT.vel = 0
ENT.maxvel = 0
ENT.selfmaxvel = 0
ENT.forceSubvorts = 0
ENT.forceRFD = 0
ENT.forceMainVortex = 0
ENT.xt2ForceListTotal = {nil, nil, nil}

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
        local vel = self:GetNWFloat("CurrentVel", 0)
		local txt
		txt =  "Speed = " .. math.Round((vel or 0)*1000)/1000
		self:SetOverlayText( txt )
		self:NextThink(CurTime()+0.04)
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

	self.Inputs = WireLib.CreateInputs(self, {"Reset Max Windspeed" })
	self.Outputs = Wire_CreateOutputs(self, {"MPH",  "KPH", "MPH Max", "KPH Max"})
end

function ENT:TriggerInput(iname, value)
	if iname == "Reset Max Windspeed" then
		if self.maxvel ~= nil then
			self.maxvel = 0
			self.vel = 0
			self.xt2ForceListTotal = {nil, nil, nil}
		end
		if self.selfmaxvel ~= nil then
			self.selfmaxvel = 0
		end
	end
end

function ENT:Setup()
	local outs = {}
	outs = {"MPH",  "KPH", "MPH Max", "KPH Max" }

	Wire_AdjustOutputs(self, outs)
end

function ENT:Think()
	self.vel = 0
	BaseClass.Think(self)
	local windmakers = {"xt2_*"} -- Gets all windmakers

	for i, v in ipairs(ents.FindByClass( table.Random(windmakers) )) do
		if v.Force ~= nil and not FindIfENTindexed(windyents, v) then
			table.insert(windyents, i, v)
		end
	end
	if #windyents == 0 and self.JustKilledWindyents == false then
		self.xt2ForceListTotal = {nil, nil, nil}
		self.JustKilledWindyents = true
	elseif #windyents ~= 0 and self.JustKilledWindyents == true then
		self.JustKilledWindyents = false
	end

	for i=1, #windyents do
		local v = windyents[i]
		if v ~= nil and v:IsValid() then
			if v.range ~= nil then
				self.MaxForceValuePossibleTornadoes = v.Force
				local dist = clamp((self:GetPos() - Vector(v:GetPos()[1], v:GetPos()[2], self:GetPos()[3])):Length(), 0, math.huge)
				local function calculate_adjusted_value(dist, v_range)
					local fraction = (1.0 - ((dist / v_range)^(1/2))) + 0.25
					return fraction
				end
				if (v.range / dist) >= 1 then
					self.MainVortexWindspeeds = ((v.Force) or 0) * calculate_adjusted_value(dist, v.range)
				else
					self.MainVortexWindspeeds = 0
				end
				if v.Subvorts == true and GetConVar("xt2_subvorts"):GetInt() == 1 then
					self.SubvortexWindspeeds = self.xt2ForceListTotal[2]
				else
					self.SubvortexWindspeeds = 0
				end
				self.RearFlankDowndraftWindspeeds = self.xt2ForceListTotal[1]
				if GetConVar("xt2_rfdsimulation"):GetInt() == 0 then
					self.RearFlankDowndraftWindspeeds = 0
				end
				local function maxWindspeed(...)
					local values = {...}
					local maxVal = nil
					for _, v in ipairs(values) do
						if v ~= nil then
							if maxVal == nil or v > maxVal then
								maxVal = v
							end
						end
					end
					return maxVal
				end
				
				-- Use the function to find the maximum windspeed
				if v.JustSpawned == false and v:IsValid() then
					local dist = clamp((self:GetPos() - Vector(v:GetPos()[1], v:GetPos()[2], self:GetPos()[3])):Length(), 0, math.huge)
					self.vel = maxWindspeed(self.MainVortexWindspeeds, self.SubvortexWindspeeds, self.RearFlankDowndraftWindspeeds)
				end
				self.vel = math.min(self.vel or 0, self.MaxForceValuePossibleTornadoes)
			end
		else
			table.remove(windyents,i)
			if #windyents == 0 then
				self.xt2ForceListTotal = {nil, nil, nil}
			end
		end
	end

	local selfvel = self:GetVelocity():Length()

	if self.vel >= selfvel then
		selfvel = 0
	end

    if self.vel > self.selfmaxvel then
        self.maxvel = math.max(self.vel, self.maxvel)
    else
        self.selfmaxvel = math.max(selfvel, self.selfmaxvel)
    end
    self.selfmaxvel = (self.selfmaxvel) or 0
    self.maxvel = (self.maxvel) or 0
	self.selfmaxvel = math.Clamp(selfvel, self.selfmaxvel, math.huge)

	self.vel = math.Clamp(self.vel -math.random(1,4), 0, math.huge)

	Wire_TriggerOutput(self, "MPH", math.max(self.vel, selfvel * 3600 / 63360 * 0.75))
	Wire_TriggerOutput(self, "KPH", math.max(self.vel * 1.60934, selfvel * 3600 * 0.0000254 * 0.75))
	Wire_TriggerOutput(self, "MPH Max", math.max(self.maxvel, self.selfmaxvel * 3600 / 63360 * 0.75) )
	Wire_TriggerOutput(self, "KPH Max", math.max(self.maxvel * 1.60934, self.selfmaxvel * 3600 * 0.0000254 * 0.75))
    self.OutputVelOverlay = math.max(self.vel, selfvel * 3600 / 63360 * 0.75)
    self:SetNWFloat("CurrentVel", self.OutputVelOverlay)

	self:NextThink(CurTime()+0.04)
	
	return true
end

duplicator.RegisterEntityClass("gmod_wire_anemometer", WireLib.MakeWireEnt, "Data")


