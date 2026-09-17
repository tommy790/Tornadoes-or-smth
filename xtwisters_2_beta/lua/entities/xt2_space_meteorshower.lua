AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Meteor Shower" 
 
ENT.Spawnable = false

function ENT:Initialize()
 
    if SERVER then
        self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetColor( Color( 0, 0, 0, 0 ) )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetSolid( SOLID_NONE )
        self:SetCollisionGroup( 1 )
    end
	--	ParticleEffectAttach("fire_large_01",PATTACH_ABSORIGIN_FOLLOW,self,0)
end

function ENT:Explode()
    if !self:GetPhysicsObject():IsValid() then return end
    local entities = ents.FindInSphere(self:GetPos(),700)
    for _, ent in ipairs(entities) do
        local phys = ent:GetPhysicsObject()
        if phys and phys:IsValid() then
            constraint.RemoveAll(ent) phys:Wake() phys:EnableMotion(true) 
            local phys = ent:GetPhysicsObject()
            local force = (phys:GetPos() - self:GetPos()):GetNormalized() * 911300 
            if phys:IsValid() then
                phys:SetVelocity(force)
            end

            if ent:IsPlayer() then
              if ent:Alive() then
                if ent:GetVelocity().z < 100 then

                    ents.GetAll()
                    local ents = ent:GetPos()
                    local force2 = (ent:GetPos() - self:GetPos()):GetNormalized() * 9400

                    ent:SetVelocity(force2)
                    ent:ViewPunch(math.Rand(10, 20) * Angle(2, 2, 0))  
                    ent:TakeDamage( math.Rand(10, 130), ent, self)

                   end
                end
            end
        end
    end
end

function ENT:Think() 

    if SERVER then
        if math.random(1, 2) == 1 then
            local t = ents.Create("xt2_space_smallmeteor")
            if t:IsValid() then
                local goon = util.TraceLine( { start = self:GetPos(), mask = MASK_SOLID_BRUSHONLY, endpos = Vector(0, 0, 100000) } )
                local stv = Vector( math.random(-32768, 32768), math.random(-22768, 22768), goon.HitPos )

                local dontgoon = util.TraceLine( { start = stv, mask = MASK_SOLID_BRUSHONLY, endpos = Vector(0, 0, -100000) } )
                t:SetPos( dontgoon.HitPos )
                t:Spawn()
            end
        end
    end

    self:NextThink(CurTime() + 0.05) 

end





