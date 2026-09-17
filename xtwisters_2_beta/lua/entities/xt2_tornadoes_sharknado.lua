AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 3
ENT.range = 7200
ENT.Force = 0
ENT.weldf = 2299
ENT.rotforce = -110
ENT.f3 = {"trt_sharknado_a", "trt_sharknado_c", "trt_sharknado_d", "trt_sharknado_e"}
ENT.HasLightning = true 
ENT.Subvorts = true 
ENT.isderp = true 
ENT.derptype = 1
ENT.CustomAudio = true   
ENT.speedmult = 0.6
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "SHARKNADO!!!" 

function ENT:Initialize()
    if CLIENT then

        if !self:IsValid() then return end
        self.TheBallad = CreateSound(self, Sound("theballadofsharknado.wav"))
        self.TheBallad:SetSoundLevel( 0 )
        self.TheBallad:ChangeVolume( 1 )
        self.TheBallad:ChangePitch(250)

        self.Roar = CreateSound(self, Sound("twisterroar.wav"))
        self.Roar:SetSoundLevel( 19000 )
        self.Roar:ChangeVolume( 1 )

        for i, ply in ipairs( player.GetAll() ) do

            self.TheBallad:Play()
            self.Roar:Play()

        end

    end

    if SERVER then

    self.Force = math.random(90, 300)

    if math.random(1,5) == 1 then
        self.rotforce = 110
        self.f3 = {"trt_sharknado_b"}
    end

    local function GetFujita()

		local Windspeed = self.Force
	
		if Windspeed < 65 then
			self.sFScale = 0
            self.Subvorts = false 
            self.weldf = 800
		end
	
		if Windspeed >= 65 and Windspeed <= 85 then
			self.sFScale = 0
            self.Subvorts = false
            self.weldf = math.random(5199, 6499)  
		end
	
		if Windspeed >= 86 and Windspeed <= 110 then
			self.sFScale = 1
            self.Subvorts = false
            self.weldf = 3999
		end
	
		if Windspeed >= 111 and Windspeed <= 135 then
			self.sFScale = 2
            self.Subvorts = false
            self.weldf = 3099 
		end
	
		if Windspeed >= 136 and Windspeed <= 165 then
			self.sFScale = 3
            self.Subvorts = true 
            self.weldf = 2299
		end
	
		if Windspeed >= 166 and Windspeed <= 200 then
			self.sFScale = 4
            self.Subvorts = true 
            self.weldf = 209
		end
	
		if Windspeed >= 201 then
			self.sFScale = 5
            self.Subvorts = true 
            self.weldf = 50
		end
	
	end
    
	GetFujita()

    print("This tornado's windspeed is " .. self.Force )
	print("This tornado is an EF" .. self.sFScale )

    self:startx()

    timer.Simple(GetConVar("xt2_tlifetime"):GetInt(), function()
            
        if !self:IsValid() then return
            
        end
            
        self:Remove()
            
    end)

    self:testing2()  
    
    for k, v in ipairs(self.f3) do  

        PrecacheParticleSystem(v)

    end
    
    local u = table.Random(self.f3)

    print(u)

    self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetColor( Color( 0, 0, 0, 0 ) )
    self:SetRenderMode( RENDERMODE_TRANSALPHA )
    self:SetMoveType( MOVETYPE_FLY )
	self:SetSolid( SOLID_NONE )
    self:SetCollisionGroup( 1 )

    timer.Simple(0.5, function()
            
        if !self:IsValid() then return end
                
            ParticleEffectAttach(u,PATTACH_ABSORIGIN_FOLLOW,self,0)

        end)

    end

end

function ENT:OnRemove()
    if self.TheBallad ~= nil then
        self.TheBallad:Stop()
    end
    
    if self.Roar ~= nil then 
        self.Roar:Stop()
    end

end

