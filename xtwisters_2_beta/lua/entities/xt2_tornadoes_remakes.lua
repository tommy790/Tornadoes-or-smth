AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 0
ENT.range = 0
ENT.Force = 0
ENT.weldf = math.random(5199, 6499)
ENT.rotforce = 0
ENT.HasLightning = true 
ENT.Subvorts = false  
ENT.isderp = false
ENT.speedmult = 0.6
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Media Tornadoes Remade" 

function ENT:Initialize()

    if SERVER then

        local MediaPicker = math.random(1,4)

        if MediaPicker == 1 or MediaPicker == 2 then
            self.Scale = 1
        else
            self.Scale = 0
        end

        if MediaPicker == 1 then
            print("GMSC Tornadoes Remade")
            local EFPicker = math.random(1,3)
            if EFPicker == 1 then
                self.f3 = {"GMSC_EF1_r"}
                self.Force = math.random(73, 112)
                self.rotforce = -70
                self.range = 3200
            end
            if EFPicker == 2 then
                self.f3 = {"GMSC_EF3_r"}
                self.Force = math.random(158, 206)
                self.rotforce = -110
                self.range = 7200
            end
            if EFPicker == 3 then
                self.f3 = {"GMSC_EF5_r"}
                self.Force = math.random(216, 319) -- jesus christ the f-scale is insane.
                self.rotforce = -190
                self.range = 9100
            end
        end

        if MediaPicker == 2 then
            print("Tornado Research & Rescue")
            local EFPicker = math.random(1,5)
            if EFPicker == 1 then
                self.f3 = {"trt_rr_f1"}
                self.Force = math.random(40, 112)
                self.rotforce = -70
                self.range = 3200
            end
            if EFPicker == 2 then
                self.f3 = {"trt_rr_f2"}
                self.Force = math.random(113, 157)
                self.rotforce = -77
                self.range = 4200
            end
            if EFPicker == 3 then
                self.f3 = {"trt_rr_f3"}
                self.Force = math.random(158, 206)
                self.rotforce = -110
                self.range = 7200
            end
            if EFPicker == 4 then
                self.f3 = {"trt_rr_f4"}
                self.Force = math.random(207, 261)
                self.rotforce = -160
                self.range = 8800
            end
            if EFPicker == 5 then
                self.f3 = {"trt_rr_f5"}
                self.Force = math.random(262, 319) -- jesus christ the f-scale is insane.
                self.rotforce = -190
                self.range = 9100
            end
        end

        if MediaPicker == 3 then
            print("Into The Storm")
            local EFPicker = math.random(1,5)

            if EFPicker == 1 then
                self.f3 = {"its_ef2"}
                self.Force = math.random(135, 200)
                self.rotforce = -70
                self.range = 3200
            end
            if EFPicker == 2 then
                self.f3 = {"its_ef3"}
                self.Force = math.random(136, 165)
                self.rotforce = -77
                self.range = 4200
            end
            if EFPicker == 3 then
                self.f3 = {"its_ef4"}
                self.Force = math.random(166, 200)
                self.rotforce = -160
                self.range = 7200
            end
            if EFPicker == 4 then
                self.f3 = {"its_ef5"}
                self.Force = math.random(300, 320)
                self.rotforce = -280
                self.range = 18000
            end
            if EFPicker == 5 then
                self.f3 = {"its_drillbit_1", "its_drillbit_1"}
                self.Force = math.random(190, 200)
                self.rotforce = -77
                self.range = 4200
            end
            
        end

        if MediaPicker == 4 then
            print("Minecraft")
            local EFPicker = math.random(1,5)

            if EFPicker == 1 then
                self.f3 = {"trt_minecraft_f1"}
                self.Force = math.random(135, 200)
                self.rotforce = 85
                self.range = 3200
            end
            if EFPicker == 2 then
                self.f3 = {"trt_minecraft_f2"}
                self.Force = math.random(136, 165)
                self.rotforce = 120
                self.range = 4000
            end
            if EFPicker == 3 then
                self.f3 = {"trt_minecraft_f3"}
                self.Force = math.random(166, 200)
                self.rotforce = 145
                self.range = 5000
            end
            if EFPicker == 4 then
                self.f3 = {"trt_minecraft_f4"}
                self.Force = math.random(300, 320)
                self.rotforce = 160
                self.range = 6000
            end
            if EFPicker == 5 then
                self.f3 = {"trt_minecraft_f5"}
                self.Force = math.random(190, 200)
                self.rotforce = 200
                self.range = 7000
            end
            
        end

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
    self:OnRemoveX()
end

