AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 69
ENT.range = 4000
ENT.Force = 6969
ENT.weldf = 2299
ENT.rotforce = -110
ENT.F12 = {"RDTX7_F35LF"}
ENT.HasLightning = false  
ENT.Subvorts = false  
ENT.isderp = false
ENT.speedmult = 2
ENT.IsFirenado = true 
ENT.PlayerNPCForceMult = 0.2
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "F35 Lightning" 

function ENT:Initialize()

    if SERVER then

    print("This tornado's windspeed is " .. self.Force )
	print("This tornado is an F" .. self.sFScale )

    self:startx()

    timer.Simple(GetConVar("xt2_tlifetime"):GetInt(), function()
            
        if !self:IsValid() then return
            
        end
            
        self:Remove()
            
    end)

    self:testing2()  
    
    for k, v in ipairs(self.F12) do  

        PrecacheParticleSystem(v)

    end
    
    local u = table.Random(self.F12)

    print(u)

    self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetColor( Color( 0, 0, 0, 0 ) )
    self:SetRenderMode( RENDERMODE_TRANSALPHA )
    self:SetMoveType( MOVETYPE_FLY )
	self:SetSolid( SOLID_NONE )
    self:SetCollisionGroup( 1 )

    local thing = math.random(1000000, 0)
    hook.Add( "Think", "F35Meteor"..thing, function()
        if self:IsValid() then

            if math.random(1,20) == 1 then
                local Shark = ents.Create("xt2_space_smallmeteor")
                
                if Shark ~= nil then
                    Shark:SetPos(self:GetPos() + Vector(math.random(-140, 140), math.random(-140, 140), math.random(1000, 30)))
                    Shark.IsProjectile = true 
                    local phys = self:GetPhysicsObject()
                    if phys:IsValid() then
                      --  phys:AddVelocity(Vector(math.random(-10000, 10000), math.random(-10000, 10000), math.random(1000, 6000)))
                    end
                    Shark:Spawn()
                end
            end
        else
            hook.Remove( "Think", "F35Meteor"..thing )
        end
    end )


    timer.Simple(0.5, function()
            
        if !self:IsValid() then return end
                
            ParticleEffectAttach(u,PATTACH_ABSORIGIN_FOLLOW,self,0)

        end)

    end

    if CLIENT then

        local thing = math.random(1000000, 0)
        hook.Add( "Think", "F35Yapping"..thing, function()
            if self:IsValid() then
                if math.random(1, 20) == 1 then
                    local crack = {
                        "Toni DID NOT FUCKING CREATE THIS MOD.",
                        "I'm LOOKSMAXXING",
                        "Ambatukam",
                        "XTwisters 3 when",
                        "FortyFourty is a fucking",
                        "Rainbow has 4 wives",
                        "I'm Schizo.",
                        ":3",
                        "I love neco arc",
                        "Buru Nyuu",
                        "Nya",
                        "APRIL 27TH 2011",
                        "WHERE ARE THE MINORS!?",
                        "You're BLACKLISTED FROM XTWISTERS 2",
                        "I'm mewing.",
                        "EF4 200 CONFIRMED",
                        "Skibidi Toliet Ohio Gyatt Rizzler Sigma",
                        "Hazbin Hotel is a good show.",
                        "DOMINATING!!!!!",
                        "Clearly, you aren't dominating enough men."
                    }
                    for i, ply in ipairs( player.GetAll() ) do
                        ply:ChatPrint( table.Random(crack) )
                    end
                end
            else
                hook.Remove( "Think", "F35Yapping"..thing )
            end
        end )
    end

end

function ENT:OnRemove()
    self:OnRemoveX()
end

