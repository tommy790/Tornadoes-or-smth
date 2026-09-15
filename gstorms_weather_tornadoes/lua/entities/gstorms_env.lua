ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Weather"
ENT.GSEnv = true

local nilVector = Vector(0, 0, 0)

function ENT:Initialize()
    self:SetModel("models/props_c17/canister01a.mdl")
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetColor(Color(0, 0, 0, 0))
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
end

function ENT:Update()

	local currentParams = GSGetAtmosphericProperties()
	local entList = gs_weatherEntityList and gs_weatherEntityList.server or {}
	local temp = (currentParams and currentParams.TEMPERATURE) or 0

	if GetConVar("gstorms_env_ambient_temperature_override"):GetBool() then temp = GetConVar("gstorms_env_ambient_temperature"):GetInt() end

	self.Temperature = temp

	local enabled = GetConVar("gstorms_sim_ambient_wind"):GetBool()
	local ambientDir = currentParams.WINDDIRECTION or nilVector
	local ambientWS = 0

	if enabled then ambientWS = (currentParams and currentParams.WIND) or 0 end
    ambientWS = math.max(ambientWS, 0.001)
    
    if GetConVar("gstorms_env_ambient_windspeed_override"):GetBool() then ambientWS = GetConVar("gstorms_env_ambient_windspeed"):GetInt() end

	local totalDir = ambientDir * ambientWS
	local totalWS = ambientWS

	for _, entity in ipairs(entList) do

		if !entity:IsValid() or !entity.Networked or entity.Flow or entity == self then continue end

		local fwdSpeed = entity.ForwardsSpeedMPH
		local mv = entity.MovementVector or nilVector
		local v = mv * fwdSpeed

		totalDir = totalDir + v
		totalWS = math.max(totalWS, fwdSpeed)

	end

	local dir = (totalDir:LengthSqr() > 0) and totalDir:GetNormalized() or nilVector

	self.WindDirection = dir * totalWS
	self.Windspeed = totalWS
	self.ForwardsSpeedMPH = totalWS

end

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Windspeed")
    self:NetworkVar("Float", 1, "Temperature")
    self:NetworkVar("Float", 2, "ForwardsSpeedMPH")
    self:NetworkVar("Vector", 0, "WindDirection")
    self:NetworkVar("Bool", 0, "Networked")
end

function ENT:SendNetworkVariables()
    self:SetWindspeed(self.Windspeed)
    self:SetTemperature(self.Temperature)
    self:SetForwardsSpeedMPH(self.ForwardsSpeedMPH)
    self:SetWindDirection(self.WindDirection)
    self.Networked = true
    self:SetNetworked(true)
end

function ENT:ReceiveNetworkVariables()
    self.Windspeed = self:GetWindspeed()
    self.Temperature = self:GetTemperature()
    self.ForwardsSpeedMPH = self:GetForwardsSpeedMPH()
    self.WindDirection = self:GetWindDirection()
    self.Networked = self:GetNetworked()
end

function ENT:Think()

    if !self:IsValid() then return end

    self.CurTime = CurTime()

    if SERVER then
        self:Update()
        self:SendNetworkVariables()
    else
        self:ReceiveNetworkVariables()
    end

    self:NextThink(self.CurTime + (engine.TickInterval() * 60))
    return true

end

function ENT:UpdateTransmitState() return TRANSMIT_ALWAYS end