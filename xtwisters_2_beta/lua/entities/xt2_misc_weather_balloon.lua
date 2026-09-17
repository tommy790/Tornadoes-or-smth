AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Weather Balloon"
ENT.Spawnable = true
ENT.AdminOnly = false

hook.Add("PlayerSpawnSENT", "SetWeatherBalloonOwner", function(player, class)
    if class == "xt2_misc_weather_balloon" then
        player.LastSENT = CurTime() -- Tracking when the player last spawned an entity
    end
end)

if SERVER then
    util.AddNetworkString("WeatherBalloonData")
    util.AddNetworkString("WeatherBalloonDataThermos")
    util.AddNetworkString("WeatherBalloonDataWeights")
end

function ENT:SetupDataTables()
    self:NetworkVar("Float", 1, "SpawnHeight")
    self:NetworkVar("Bool", 1, "ReachedMaxHeight")
end

function ENT:Initialize()
    if SERVER then
        for _, ply in ipairs(player.GetAll()) do
            if ply.LastSENT and ply.LastSENT + 0.1 > CurTime() then -- 0.1 seconds leeway to set the owner, hopefully this is enough lol.
                self.Owner = ply
                break
            end
        end
        self.currentLerp = 0.000025
        self:SetModel("models/weather_balloon/an_ordinary_weather_baloon.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_WORLD)
        self:SetModelScale(1)
        
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:Wake()
            phys:EnableMotion(true)
            phys:SetBuoyancyRatio(1.05)
        end

        self:SetSpawnHeight(self:GetPos().z)
        self:SetReachedMaxHeight(false)

        -- Send initial weather data after a short delay and then periodically
        timer.Simple(25, function() 
            if self:IsValid() then
                self:SendWeatherData() 
            end
        end)
        timer.Simple(30, function()
            if IsValid(self) then
                self:Remove()
            end
        end)
    end
end

function ENT:Think()
    if SERVER and not self:GetReachedMaxHeight() then
        local currentPos = self:GetPos()
        local targetHeight = self:GetSpawnHeight() + 8000
        if currentPos.z < targetHeight then
            self.currentLerp = self.currentLerp + 0.000003
            local nextPos = Vector(currentPos.x, currentPos.y, math.min(targetHeight, Lerp(self.currentLerp, currentPos.z, targetHeight)))
            self:SetPos(nextPos)
            if nextPos.z == targetHeight then
                self:SetReachedMaxHeight(true)
            end
        end
        self:NextThink(CurTime())
        return true
    end
end

function ENT:SendWeatherData()
    if SERVER then
        local statusThermos = ReturnThermosWeatherBalloon()
        local status = GetWeatherBalloonCurrentWeatherSelectorStatus()
        local statusweightstemp = ReturnWeightEFsWeatherBalloon()
        local statusweightsfinal = statusweightstemp[1].."\n" ..statusweightstemp[2].."\n" ..statusweightstemp[3].."\n" ..statusweightstemp[4].."\n" ..statusweightstemp[5].."\n" ..statusweightstemp[6]
        
        if IsValid(self.Owner) and self.Owner:IsPlayer() then
            net.Start("WeatherBalloonDataThermos")
            net.WriteString(statusThermos)
            net.Send(self.Owner)

            net.Start("WeatherBalloonData")
            net.WriteString(status)
            net.Send(self.Owner)

            net.Start("WeatherBalloonDataWeights")
            net.WriteString(statusweightsfinal)
            net.Send(self.Owner)
        end
    end
end

if CLIENT then
    net.Receive("WeatherBalloonDataThermos", function()
        local status = net.ReadString()
        print("\n"..status)
    end)
    net.Receive("WeatherBalloonData", function()
        local status = net.ReadString()
        print("\n" ..status)
    end)
    net.Receive("WeatherBalloonDataWeights", function()
        local status = net.ReadString()
        print("\n"..status)
    end)
end

function ENT:OnRemove()
end