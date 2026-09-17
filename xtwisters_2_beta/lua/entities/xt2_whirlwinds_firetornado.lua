AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 2
ENT.range = 4200
ENT.Force = 0
ENT.weldf = 3099
ENT.rotforce = -77
ENT.f2 = {"its_firenado" }
ENT.HasLightning = true  
ENT.Subvorts = false  
ENT.isderp = false
ENT.IsFirenado = true
ENT.speedmult = 0.55   

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Fire Tornado" 

function ENT:Initialize()
    if SERVER then
    
    self.Force = math.random(120, 201)    
    
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


    print("This fire tornado's windspeed is " .. self.Force )
	print("This fire tornado is an  EF" .. self.sFScale )
    self:startx()

    timer.Simple((math.random(100,250))*(GetConVar("xt2_tlifetime"):GetInt() / 400), function()
            
        if !self:IsValid() then return
            
        end
            
        self:Remove()
            
    end)

    self:testing2()  
    
    for k, v in ipairs(self.f2) do  

        PrecacheParticleSystem(v)

    end
    
    local u = table.Random(self.f2)

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
    self:OnRemoveX()
end

