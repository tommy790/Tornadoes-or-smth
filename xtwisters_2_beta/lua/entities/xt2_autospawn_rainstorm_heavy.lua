AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2weatherbase"

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Rainstorm"  

ENT.IsWindy = true 
ENT.WindDir = Vector(0, 1, 0)
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
ENT.HasLightning = false  
ENT.LightningChance = 1

if SERVER then
    include("autorun/server/autospawn.lua")
end

function ENT:Initialize()

    if SERVER then
		globalRainstormCount = globalRainstormCount + 1
        self.Force = math.random(0,15)
        self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetColor( Color( 0, 0, 0, 0 ) )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetSolid( SOLID_NONE )
        self:SetCollisionGroup( 1 )    
    end

    self:startx()

end

function ENT:OnRemove()
    self:OnRemoveX()
    if SERVER then
		globalRainstormCount = globalRainstormCount - 1
    end
end

