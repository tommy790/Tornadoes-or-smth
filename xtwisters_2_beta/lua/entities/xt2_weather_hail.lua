AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Hailstone" 
 
ENT.Spawnable = false

local function rnd(mi, ma) return math.random(1000) / 1000 * (ma - mi) + mi end
ENT.AlreadyImpacted = false 
ENT.scale = rnd(0.1,2)
ENT.Transparency = 200

function ENT:Initialize()
 
    self:SetModel("models/props_junk/rock001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetColor( Color( 255, 255, 255, 240 ) )
    self:SetMaterial("phoenix_storms/fender_white")
    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self:SetModelScale( self:GetModelScale() / math.random(1, 3), 0 )
   
    local phys = self:GetPhysicsObject()
   
    if phys:IsValid() then
        phys:SetMass( math.random(10,20))
        phys:Wake()
        phys:AddVelocity( Vector(0, 0, -1000) )
        phys:AddAngleVelocity(Vector(rnd(-360,360), rnd(-360,360), rnd(-360,360) ))
    end
end

function ENT:Think() 
    if SERVER then
        if !self:IsValid() then return end

        if !util.IsInWorld( self:GetPos() ) then
            self:Remove()
        end

        timer.Simple(7.5, function()
            if !self:IsValid() then return end
         
            self:Melt()
        end)

        self:NextThink( CurTime() + 0.1 )
    end
    return true
end

function ENT:PhysicsCollide( data, physobj, ply )
    if SERVER then
    if !self:IsValid() then return end

        --[
        if data.Speed <= 200  then         
            self.f = CreateSound(self, Sound("Weather/ENVShared/Ice/HailstoneImpact" .. math.random(1,7) .. ".wav"))
            self.f:SetSoundLevel( rnd(80,100) )
            self.f:ChangeVolume( 1 )
            --self.f:Play()
        end
        --]]

        local v = data.HitEntity
        
        if data.Speed <= 200 and math.random(1,10) == 1 and GetConVar("xt2_unweldprops"):GetInt() == 1 then
            if ( constraint.HasConstraints( v )) and !v:IsVehicle() then	
                local Phys = v:GetPhysicsObject()	
                Phys:Wake()
                Phys:EnableMotion(true)    

                v:EmitSound("break" .. math.random(1, 4) .. ".mp3", 100)
                constraint.RemoveAll(v)
            end
        end

        if math.random(1,10) ~= 1 and self.AlreadyImpacted == false then
            self:Remove()
            ParticleEffect( "RDTW_HailImpact", self:GetPos(), Angle( 0, 0, 0 ) )
        end
        self.AlreadyImpacted = true 
        --self:Remove()   
    end 
end


function ENT:Melt()
    self:SetModelScale( self:GetModelScale() / 5.25, 1 )

    if self:GetModelScale() <= 0.1 then

        self:Remove()

    end
end