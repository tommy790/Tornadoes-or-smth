AddCSLuaFile()

if not WireLib then return end

DEFINE_BASECLASS( "base_wire_entity" )
ENT.PrintName       = "Wire Doppler Radar"
ENT.WireDebugName	= "DOW radar"
ENT.Force = 0
ENT.Range = 0

ENT.vel = 0
ENT.maxvel = 0
ENT.tornadovel = 0
ENT.tornadodist = 0
ENT.tornadosize = 0
ENT.interferanceupdatetime = 0
ENT.interferance = 0
ENT.alternatenumber = 0

local function roundfordow(number)
	if number >= 0 then
		return math.floor(number + 0.5)
	else
		return math.ceil(number - 0.5)
	end
end

local d=false 
local windyents = {}

hook.Add("PreCleanupMap", "OnAdminCleanupDOW", function()
	windyents = {}
end)

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

		if vel == nil then
			local vel = 0
		end

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

	self.Inputs = WireLib.CreateInputs(self, {"Reset Max Windspeed", "Alternate Left", "Alternate Right" })
	self.Outputs = WireLib.CreateOutputs(self, {"Windspeed M/S", "Windspeed M/S Max", "Tornado Size in Yards", "Tornado Distance in Yards", "Storm Selected"})
end

function ENT:TriggerInput(iname, value)
	if iname == "Reset Max Windspeed" then
		self.maxvel = 0
	end


	if iname == "Alternate Left" then

		local val = self.alternatenumber-1/2
		self.alternatenumber = roundfordow(val)
		self.alternatenumber = math.Clamp(self.alternatenumber, 0, #windyents)

		self.tornadodist = 0
		self.tornadosize = 0
		self.vel = 0
		
		WireLib.TriggerOutput(self, "Storm Selected", self.alternatenumber)

		WireLib.TriggerOutput(self, "Windspeed M/S", 0)
		WireLib.TriggerOutput(self, "Windspeed M/S Max", 0)
		WireLib.TriggerOutput(self, "Tornado Size in Yards", 0)
		WireLib.TriggerOutput(self, "Tornado Distance in Yards", 0)
	end

	if iname == "Alternate Right" then

		local val = self.alternatenumber+1/2
		self.alternatenumber = val
		self.alternatenumber = math.Clamp(self.alternatenumber, 0, #windyents)

		self.tornadodist = 0
		self.tornadosize = 0
		self.vel = 0
		
		WireLib.TriggerOutput(self, "Storm Selected", self.alternatenumber)

		WireLib.TriggerOutput(self, "Windspeed M/S", 0)
		WireLib.TriggerOutput(self, "Windspeed M/S Max", 0)
		WireLib.TriggerOutput(self, "Tornado Size in Yards", 0)
		WireLib.TriggerOutput(self, "Tornado Distance in Yards", 0)
	end
end

function ENT:Think()
	BaseClass.Think(self)
	
	math.Clamp(self.alternatenumber, 0, #windyents)
	self.interferanceupdatetime = self.interferanceupdatetime+1

	if self.interferanceupdatetime >= 1 then
		self.interferanceupdatetime = 0
		self.interferance = math.random(-30, 30)
	end

	local windmakers = {"xt2_*"}

	for i, v in ipairs(ents.FindByClass( table.Random(windmakers) )) do
		if v.Force ~= nil and not FindIfENTindexed(windyents, v) then
			table.insert(windyents, i, v)
		end
	end

	local v = windyents[self.alternatenumber]

	if v ~= NULL and v ~= nil and v:IsValid() then
		local dist = math.Clamp((self:GetPos() - Vector(v:GetPos()[1] or 0, v:GetPos()[2] or 0, self:GetPos()[3] or 0)):Length(), 0, math.huge)
		self.vel = v.Force + self.interferance
		if v.range == nil then
			self.tornadodist = 0
			self.tornadosize = 0

			if v.Force ~= nil then
				self.vel = v.Force + self.interferance*0.1
			end
		else
			self.tornadodist = dist/48
			self.tornadosize = v.range/48
		end
	else
		table.remove(windyents, self.alternatenumber)
		self.tornadodist = 0
		self.tornadosize = 0
		self.vel = 0

		WireLib.TriggerOutput(self, "Windspeed M/S", 0)
		WireLib.TriggerOutput(self, "Windspeed M/S Max", 0)
		WireLib.TriggerOutput(self, "Tornado Size in Yards", 0)
		WireLib.TriggerOutput(self, "Tornado Distance in Yards", 0)
	end
	

	self.maxvel = math.Clamp(self.vel, self.maxvel, math.huge)

	WireLib.TriggerOutput(self, "Windspeed M/S", (self.vel * 1.60934) / 3.6)
	WireLib.TriggerOutput(self, "Windspeed M/S Max", (self.maxvel * 1.60934) / 3.6)
	WireLib.TriggerOutput(self, "Tornado Size in Yards", self.tornadosize)
	WireLib.TriggerOutput(self, "Tornado Distance in Yards", self.tornadodist)
	

	self.vel = math.Clamp(self.vel - math.random(1,20), 0, math.huge)
                                  
	self:NextThink(CurTime()+1)
	
	return true
end


duplicator.RegisterEntityClass("gmod_wire_doppler", WireLib.MakeWireEnt, "Data")


