AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2weatherbase"

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Hailstorm"  


ENT.IsWindy = true 
ENT.WindDir = Vector(0, 1, 0)
ENT.Force = 0
ENT.Weldf = 0
ENT.IsRaining = true 
ENT.IsHailing = true   
ENT.IsFoggy = true 
ENT.FogStart = 0
ENT.FogEnd = 100
ENT.FogDensity = 0.85
ENT.FogColor = Vector(127,127,127) 

ENT.HasLightning = true  
ENT.LightningChance = 100

if SERVER then
    include("autorun/server/autospawn.lua")
end

function ENT:Initialize()

    if SERVER then
        globalThunderstormCount = globalThunderstormCount + 1
        self.Force = math.random(0,20)
        self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetColor( Color( 0, 0, 0, 0 ) )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetSolid( SOLID_NONE )
        self:SetCollisionGroup( 1 )  
        print("Weather Windspeed "..tostring(self.Force)) 
    end

    self:SetNWFloat("RainType", math.random(2,3))
    if CLIENT then
        self.RainType = self:GetNWFloat("RainType", 2)
        
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
    print("guh3")
    if SERVER then
        globalThunderstormCount = globalThunderstormCount - 1
    end
end

