AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2weatherbase"

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Supercell Thunderstorm"  


ENT.IsWindy = true 
ENT.WindDir = Vector(0, 1, 0)
ENT.Force = 0
ENT.Weldf = 0
ENT.IsRaining = true 
ENT.IsHailing = false  
ENT.IsFoggy = true 
ENT.FogStart = 0
ENT.FogEnd = 100
ENT.FogDensity = 0.85
ENT.FogColor = Vector(127,127,127) 

ENT.HasLightning = true  
ENT.LightningChance = 100
ENT.SpawnedTornado = nil 

if SERVER then
    include("autorun/server/autospawn.lua")
end

function ENT:Initialize()
    self:SetNWFloat("RainType", math.random(1,3))

    if SERVER then
		globalThunderstormCount = globalThunderstormCount + 1
        self.RainType = self:GetNWFloat("RainType", 1)
        self.Force = math.random(60,120)
        self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetColor( Color( 0, 0, 0, 0 ) )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetSolid( SOLID_NONE )
        self:SetCollisionGroup( 1 )   
        print("Weather Windspeed "..tostring(self.Force)) 

        if math.random(1,3) == 1 and self:GetNWFloat("RainType", 1) >= 2 then
            self.IsHailing = true 
        end

        if math.random(1,2) == 1 then
            print("Tornadic")
            timer.Simple(math.random(10,30), function()  
                if !self:IsValid() then return end
                local t = ents.Create("xt2_tornadoes_ef-u")
                if t:IsValid() then
                    local stv = Vector(math.random(-10000, 10000), math.random(-10000, 10000), 0)
                    local dontgoon = util.TraceLine({ start = stv, mask = MASK_SOLID_BRUSHONLY, endpos = stv - Vector(0, 0, 100000) })
                    t:SetPos(dontgoon.HitPos)
                    t:Spawn()
                    self.SpawnedTornado = t
                end
            end)
        end
    end

    if CLIENT then
        self.RainType = self:GetNWFloat("RainType", 1)
        
        if self.RainType == 1 and math.random(1,2) == 1 then
            self.IsRaining = false 
            self.FogDensity = 0.5
            self.FogEnd = 1000
        end

        if self.RainType == 1 then
            self.FogDensity = 0.5
        elseif self.RainType == 2 then
            self.FogDensity = 0.85     
        elseif self.RainType == 3 then
            self.FogDensity = 1
        end
    end

    self:startx()
end

function ENT:OnRemove()
    self:OnRemoveX()
    if self.SpawnedTornado ~= nil  then
        self.SpawnedTornado:Remove()
    end
    if SERVER then
		globalThunderstormCount = globalThunderstormCount - 1
	end
    print("guh3")
end

