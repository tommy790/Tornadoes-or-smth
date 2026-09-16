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
ENT.HeightForceMultiplier = 6.5 --z tornadic force scaling (height)
ENT.GeneralForceMultiplier = 1.5 --x and y tornadic force scaling
ENT.isTornado = true

ENT.Spawnable = false 
ENT.AdminOnly = "false" 
ENT.PrintName = "Tornado" 
ENT.AnticyclonicFlag = false

function ENT:Initialize()

    if SERVER then

        local MinWindSpeed = 65
        local MaxWindSpeed = 320 -- Debris threshold height don't stress about this too much its not actually a max windspeed cap. I copy pasted this from the base for autospawn and repurposed it.
        local ef0Windspeed = 85  -- MAX windspeed for EF-0 (Baseline)
        local ef3Windspeed = 165 -- MAX Windspeed for EF-3
        local ef5Windspeed = 225 -- Minimum windspeed for EF-5
        local ef3Value = 10 -- 
    
        function self:ForceMultiplierFunctionRandomTornado(baselineValue, maxValue)
            -- Check for windspeed below EF-0 Maximum
            if self.Force <= ef0Windspeed then
                return baselineValue
            -- Check for windspeed above EF-5 minimum
            elseif self.Force >= ef5Windspeed then
                return maxValue
            -- Calculate for windspeeds within the EF-0 to EF-3 range using an exponential function
            elseif self.Force <= ef3Windspeed then
                local expScale = math.log(ef3Value / baselineValue) / (ef3Windspeed - ef0Windspeed)
                local value = baselineValue * math.exp(expScale * (self.Force - ef0Windspeed))
                return value
            -- Calculate for windspeeds within the EF-3 to EF-5 range
            else
                local slope = (maxValue - ef3Value) / (ef5Windspeed - ef3Windspeed)
                local value = ef3Value + slope * (self.Force - ef3Windspeed)
                return value
            end
        end

        WindspeedVal = math.floor(math.pow(math.random(), 4.5) * 285 + 65)
        self.Force = WindspeedVal

        local function Picksize()
            local picknum = math.random(0,6)
            self.AnticyclonicFlag = false

            if picknum == 0 then
                self.TornadoParticle = {"5TonyEF0", "5TonyEF02", "5TonyEF03", "5TonyEF019", "PGYT_EF_0k" , "PGYT_EF_0l" , "PGYT_EF_0m" , "PGYT_EF_0n" , "PGYT_EF_0o" , "PGYT_EF_0p" , "PGYT_EF_0q" , "PGYT_EF_0r" , "PGYT_EF_0s", "PGYT_EF_0t" , "PGYT_EF_0u" , "PGYT_EF_0v" , "PGYT_EF_0w" , "PGYT_EF_0x" , "PGYT_EF_0y" , "PGYT_EF_0z", "5TonyEF020", "5TonyEF021", "5TonyEF022", "PGYT_EF_0g" , "5TonyEF018", "5TonyEF017", "5TonyEF019", "5TonyEF016", "PGYT_EF_0h" , "PGYT_EF_0i" , "PGYT_EF_0j", "PGYT_EF_0f", "5TonyEF014", "5TonyEF015", "5TonyEF011", "5TonyEF012", "5TonyEF06", "5TonyEF013", "5TonyEF07", "5TonyEF08", "PGYT_EF_0" , "PGYT_EF_0b" , "PGYT_EF_0c" , "PGYT_EF_0d" , "PGYT_EF_0e", "5TonyEF09", "5TonyEF010", "5TonyEF04", "5TonyEF05", "v1_f0", "v2_f0", "v4_f0", "v6_f0", "v8_f0", "v9_f0", "v10_f0", "v12_f0", "v3_f0"}
                self.rotforce = -54
                self.range = 2200
                if math.random(1,20) == 1 then
                    self.TornadoParticle = {"5TonyEF027"}
                    self.rotforce = 54
                    self.AnticyclonicFlag = true
                end
            end
        
            if picknum == 1 then
                self.TornadoParticle = {"Twister_EF1", "5TonyEF1", "5TonyEF12", "5TonyEF13", "5TonyEF16", "5TonyEF118", "5TonyEF120", "PGYT_EF_1k" , "PGYT_EF_1l" , "PGYT_EF_1m" , "PGYT_EF_1n" , "PGYT_EF_1o" , "PGYT_EF_1p" , "PGYT_EF_1q" , "PGYT_EF_1r" , "PGYT_EF_1s" , "PGYT_EF_1t" , "PGYT_EF_1u", "5TonyEF121", "5TonyEF122", "5TonyEF119", "5TonyEF117", "5TonyEF116", "PGYT_EF_1f" , "PGYT_EF_1g" ,  "5TonyEF112", "5TonyEF114",  "PGYT_EF_1h" , "PGYT_EF_1i" , "PGYT_EF_1j", "5TonyEF115", "5TonyEF113", "5TonyEF17", "5TonyEF18", "5TonyEF19", "5TonyEF111", "5TonyEF110", "PGYT_EF_1", "PGYT_EF_1" , "PGYT_EF_1b" , "PGYT_EF_1c" , "PGYT_EF_1d", "PGYT_EF_1e", "5TonyEF14", "5TonyEF15", "5TonyEF16", "v1_f1", "v2_f1", "v3_f1", "v6_f1", "v7_f1", "v8_f1", "v11_f1", "v16_f1", "v21_f1", "v14_f1", "v20_f1", "v4_f1", "v9_f1", "v10_f1", "v13_f1", "v15_f1", "v18_f1", "v19_f1", "v22_f1", "v5_f1", "v17_f1", "v17_f1"}
                self.rotforce = -70
                self.range = 3200
                if math.random(1,20) == 1 then
                    self.TornadoParticle = {"5TonyEF127"}
                    self.rotforce = 70
                    self.AnticyclonicFlag = true
                end
            end
        
            if picknum == 2 then -- Drillbits
                self.range = 3500
                self.TornadoParticle = {"RDT1_EF5", "RDTX2_Drillbit1", "5TonyEF515", "v14_f5", "v22_f5"}
                self.rotforce = -77
            end

            if picknum == 3 then
                self.TornadoParticle = {"Twister_EF2", "5TonyEF2", "5TonyEF211", "5TonyEF22", "5TonyEF216", "5TonyEF217", "5TonyEF220", "PGYT_EF_2k" , "PGYT_EF_2l" , "PGYT_EF_2" , "PGYT_EF_2m" , "PGYT_EF_2n" , "PGYT_EF_2o" , "PGYT_EF_2p" , "PGYT_EF_2q" , "PGYT_EF_2r", "5TonyEF221", "5TonyEF222", "5TonyEF218", "5TonyEF219", "PGYT_EF_2f" , "PGYT_EF_2g", "PGYT_EF_2h" , "PGYT_EF_2i" , "PGYT_EF_2j", "5TonyEF23", "5TonyEF214", "5TonyEF215", "5TonyEF24", "5TonyEF212", "5TonyEF25",  "5TonyEF213", "5TonyEF26", "5TonyEF27", "5TonyEF28", "5TonyEF29", "5TonyEF210", "PGYT_EF_2" , "PGYT_EF_2b" , "PGYT_EF_2c" , "PGYT_EF_2d" , "PGYT_EF_2e", "v6_f2", "v10_f2", "v15_f2", "v16_f2", "v17_f2", "v20_f2", "v21_f2", "v22_f2", "v1_f2", "v2_f2", "v5_f2", "v11_f2", "v12_f2", "v13_f2", "v14_f2", "v3_f2", "v4_f2", "v9_f2", "v7_f2", "v18_f2"}
                self.rotforce = -77
                self.range = 4200
                if math.random(1,20) == 1 then
                    self.TornadoParticle = {"5TonyEF227", "v19_f2", "v8_f2"}
                    self.rotforce = 77
                    self.AnticyclonicFlag = true
                end
            end
        
            if picknum == 4 then
                self.TornadoParticle = {"Twister_EF3", "5TonyEF3", "5TonyEF32", "5TonyEF33", "5TonyEF36", "5TonyEF320", "5TonyEF321", "5TonyEF322", "5TonyEF318", "5TonyEF319", "5TonyEF37", "5TonyEF317", "5TonyEF316", "PGYT_EF_3c", "5TonyEF314", "5TonyEF315", "5TonyEF38", "5TonyEF312", "PGYT_EF_3d", "5TonyEF313",  "5TonyEF311", "5TonyEF39", "5TonyEF310", "5TonyEF34", "5TonyEF35", "v1_f3", "v4_f3", "v5_f3", "v7_f3", "v11_f3", "v13_f3", "v17_f3", "v6_f3", "v8_f3", "v9_f3", "v12_f3", "v15_f3", "v16_f3", "v2_f3", "v3_f3", "v20_f3", "v21_f3", "v23_f3", "v24_f3", "v10_f3"}
                self.rotforce = -110
                self.range = 7200
                if math.random(1,20) == 1 then
                    self.TornadoParticle = {"5TonyEF327", "v18_f3", "v19_f3", "v22_f3"}
                    self.rotforce = 110
                    self.AnticyclonicFlag = true
                end
            end
        
            if picknum == 5 then
                self.TornadoParticle = {"Twister_EF4", "5TonyEF4", "5TonyEF42", "5TonyEF411", "5TonyEF43", "5TonyEF418", "PGYT_EF_4c" , "PGYT_EF_4d" , "PGYT_EF_4e" , "PGYT_EF_4f" , "PGYT_EF_4g" , "PGYT_EF_4h" , "PGYT_EF_4i" , "PGYT_EF_4j", "5TonyEF420", "5TonyEF421", "5TonyEF422", "5TonyEF419", "5TonyEF416", "PGYT_EF_4", "PGYT_EF_4b", "5TonyEF417", "5TonyEF44", "5TonyEF414",  "5TonyEF415", "5TonyEF45", "5TonyEF412", "5TonyEF413", "5TonyEF46", "5TonyEF47", "5TonyEF48", "5TonyEF49", "5TonyEF410", "v1_f4", "v2_f4", "v3_f4", "v4_f4", "v5_f4", "v6_f4", "v7_f4", "v8_f4", "v9_f4", "v10_f4", "v11_f4", "v12_f4", "v13_f4", "v14_f4", "v15_f4", "v17_f4", "v18_f4", "v19_f4", "v20_f4", "v21_f4", "v22_f4", "v23_f4", "v24_f4", "v25_f4", "v26_f4", "v27_f4", "v28_f4", "v29_f4", "v30_f4", "v31_f4"}
                self.rotforce = -160
                self.range = 8800
                if math.random(1,30) == 1 then
                    self.TornadoParticle = {"5TonyEF427", "v16_f4"}
                    self.rotforce = 160
                    self.AnticyclonicFlag = true
                end
            end
        
            if picknum == 6 then
                self.TornadoParticle = {"Twister_EF5", "5TonyEF5", "5TonyEF511", "5TonyEF52", "5TonyEF520", "5TonyEF521", "PGYT_EF_5d", "5TonyEF522", "PGYT_EF_5b", "PGYT_EF_5c","5TonyEF516", "5TonyEF518", "5TonyEF519", "5TonyEF53", "5TonyEF517", "5TonyEF54", "5TonyEF514", "5TonyEF55", "5TonyEF513",  "5TonyEF56", "5TonyEF57", "5TonyEF58", "5TonyEF59", "5TonyEF510", "v1_f5", "v2_f5", "v3_f5", "v4_f5", "v5_f5", "v6_f5", "v7_f5", "v8_f5", "v9_f5", "v10_f5", "v11_f5", "v12_f5", "v13_f5", "v14_f5", "v15_f5", "v16_f5", "v17_f5", "v18_f5", "v19_f5", "v20_f5", "v21_f5", "v22_f5", "v23_f5", "v24_f5", "v25_f5", "v26_f5", "v27_f5", "v28_f5", "v29_f5", "v30_f5", "v14_f3"}
                self.rotforce = -190
                self.range = math.random(11000,9100)
                if math.random(1,60) == 1 then
                    self.TornadoParticle = {"5TonyEF527"}
                    self.rotforce = 190
                    self.AnticyclonicFlag = true
                end
            end
            self.GeneralForceMultiplier = self:ForceMultiplierFunctionRandomTornado(1.3, 1.9)
            self.HeightForceMultiplier = self:ForceMultiplierFunctionRandomTornado(4.8, 25)
            self.range = self.range + math.floor(math.pow(math.random(), 4.5) * 999 + 1)
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
        
        Picksize()
        GetFujita()

        self.rotforce = math.min(self.Force/1.25, 200)
        self.rotforce = -(self.rotforce)
        if self.AnticyclonicFlag == true then
            self.rotforce = -(self.rotforce)
        end
        
        self:startx()
            
        timer.Simple(GetConVar("xt2_tlifetime"):GetInt(), function()
            if !self:IsValid() then return
            end
            self:Remove()
        end)

        self:testing2()

        for k, v in ipairs(self.TornadoParticle) do  
            PrecacheParticleSystem(v)       
        end
        
        local u = table.Random(self.TornadoParticle)

        print(u)

        self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetColor( Color( 0, 0, 0, 0 ) )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetSolid( SOLID_NONE )
        self:SetCollisionGroup( 1 )

        print("This tornado's windspeed is " .. self.Force )
        print("This tornado is an EF" .. self.sFScale )
        timer.Simple(0.5, function()    
        if !self:IsValid() then return end
            ParticleEffectAttach(u,PATTACH_ABSORIGIN_FOLLOW,self,0)
        end)
    end

end

function ENT:OnRemove()
    self:OnRemoveX()
end

