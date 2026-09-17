AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_nextbot"

ENT.PrintName = "Shark" 
 
ENT.Spawnable = false
ENT.FakeHealth = 400

function ENT:Initialize()
 
    self.FakeHealth = math.random(100, 600)

    if SERVER then
    self:SetModel("models/crysis_shark/shark_a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetModelScale(self:GetModelScale() * math.random(30,90)/100,0.00001)
   
    if math.random(1,300) == 1 then
        self:SetModelScale(6,0.00001)
    end

    local phys = self:GetPhysicsObject()
   
    if phys:IsValid() then
        phys:Wake()
        phys:SetMass(700*(math.random(10,600)/100))
        phys:AddVelocity(Vector(math.random(-10000, 10000), math.random(-10000, 10000), math.random(0, 6000)))
    end
end
	--ParticleEffectAttach("fire_large_01",PATTACH_ABSORIGIN_FOLLOW,self,0)
end

function ENT:Explode()
    if !self:GetPhysicsObject():IsValid() then return end

    self:EmitSound("ambient/explosions/explode_" .. math.random(1, 9) .. ".wav", 1500)
    ParticleEffect( "RDTEXP_Sharkplosion", self:GetPos(), Angle( 0, 0, 0 ) )  

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

function ENT:PhysicsCollide( data, physobj )
    if !self:GetPhysicsObject():IsValid() then return end
    self:Remove()
    self:Explode()
end

function ENT:OnTakeDamage(dmginfo)
    if !self:GetPhysicsObject():IsValid() then return end
    self.FakeHealth = self.FakeHealth - dmginfo:GetDamage()

    if self.FakeHealth <= 0 then
        self:Remove()
        self:Explode()
    end
end


function ENT:Think() 
    local phys = self:GetPhysicsObject()

    if phys:IsValid() then
        phys:SetAngleVelocity(Vector(255, 255, 255))
    end

    self:NextThink(CurTime() + 0.02) 
end





