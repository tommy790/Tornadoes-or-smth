AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 1
ENT.range = math.random(4000,6500)
ENT.Force = 0
ENT.weldf = math.random(8199, 9499)
ENT.rotforce = -70
ENT.f0 =  {"TGustnado", "TGustnado2", "TGustnado3", "TGustnado4", "TGustnado5", "trt_vG_1", "trt_vG_2"}
ENT.HasLightning = false  
ENT.Subvorts = false 
ENT.Tornadic = false 
ENT.isderp = false
ENT.speedmult = 0.45

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Gustnado" 




function ENT:Initialize()

    if SERVER then

    self.Force = math.random(60, 110)

    local function GetFujita()

		self.windsizerand = self.Force
	
		if self.windsizerand < 65 then
			self.sFScale = 0
            self.Subvorts = false 
            self.weldf = 800
		end
	
		if self.windsizerand >= 65 and self.windsizerand <= 85 then
			self.sFScale = 0
            self.Subvorts = false
            self.weldf = math.random(5199, 6499)  
		end
	
		if self.windsizerand >= 86 and self.windsizerand <= 110 then
			self.sFScale = 1
            self.Subvorts = false
            self.weldf = 3999
		end
	
		if self.windsizerand >= 111 and self.windsizerand <= 135 then
			self.sFScale = 2
            self.Subvorts = false
            self.weldf = 3099 
		end
	
		if self.windsizerand >= 136 and self.windsizerand <= 165 then
			self.sFScale = 3
            self.Subvorts = true 
            self.weldf = 2299
		end
	
		if self.windsizerand >= 166 and self.windsizerand <= 200 then
			self.sFScale = 4
            self.Subvorts = true 
            self.weldf = 209
		end
	
		if self.windsizerand >= 201 then
			self.sFScale = 5
            self.Subvorts = true 
            self.weldf = 50
		end
	
	end
    
	GetFujita()
	print("This Gustnado is an equivalent to a EF" .. self.sFScale .." Tornado")
    print("This Gustnado's windspeed is " .. tostring(self.Force) )
    
    self:startx()
        
    timer.Simple((math.random(50,160))*(GetConVar("xt2_tlifetime"):GetInt() / 400), function()
            
        if !self:IsValid() then return
            
        end
            
        self:Remove()
            
    end)

    self:testing2()

    for k, v in ipairs(self.f0) do  

        PrecacheParticleSystem(v)       
     
    end
    
    local u = table.Random(self.f0)

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

