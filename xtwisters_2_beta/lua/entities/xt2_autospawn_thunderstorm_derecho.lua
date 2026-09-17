AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2weatherbase"

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Derecho"  

ENT.IsWindy = true 
ENT.WindDir = Vector(1, 0, 0)
ENT.Force = 0
ENT.Weldf = 0
ENT.IsRaining = true 
ENT.IsHailing = false  
ENT.IsFoggy = true 
ENT.FogStart = 0
ENT.FogEnd = 100
ENT.FogDensity = 0.9
ENT.FogColor = Vector(127,127,127) 
ENT.RainType = 3
ENT.HasLightning = true 
ENT.LightningChance = 50
ENT.IsAutospawnWeather = true

if SERVER then
    include("autorun/server/autospawn.lua")
end

function ENT:Initialize()

    self.Force = math.random(60,140)

    if CLIENT then

    end

    if SERVER then
        self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetColor( Color( 0, 0, 0, 0 ) )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetSolid( SOLID_NONE )
        self:SetCollisionGroup( 1 )
        globalThunderstormCount = globalThunderstormCount + 1
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

