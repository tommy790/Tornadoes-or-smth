AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "xtwisters2base"

ENT.sFScale = 0
ENT.range = 0
ENT.Force = 66
ENT.weldf = 5000
ENT.rotforce = -54
ENT.HasLightning = true
ENT.Subvorts = false
ENT.isderp = false
ENT.speedmult = 0.6
ENT.PlayerNPCForceMult = 0.2

ENT.Spawnable = false
ENT.AdminOnly = "false"
ENT.PrintName = "xt2_tornadoes_dynamic"
ENT.IsAnticyclonic = false
ENT.MaxWinds = 80
ENT.IsMaxWinds = false
ENT.JustInitialized = true
ENT.isTornado = true
ENT.IsDynamicTornado = true
ENT.ForceAdderDynamic = 2
ENT.ForceSubtracterDynamic = 2
ENT.Tornadic = true

-- NOT IMPORTANT, THIS STUFF JUST GETS FED TO THE BASE AND IS ONLY LOCALIZED TO AUTOSPAWN ENTS, DO NOT TOUCH UNLESS U KNOW WHAT UR DOING.
ENT.CurrentAutospawnParticleTypeFlags = {}
ENT.CurrentAutospawnPhaseFlags = {}
ENT.CurrentAutospawnWallcloudColor = "white"
ENT.oldConditions = {}
ENT.PrecachedParticlesAutospawn = {}

function ENT:Initialize()
    if SERVER then
        self.ForceAdderDynamic = (math.random(3, 7) / 4) * (400 / GetConVar("xt2_tlifetime"):GetInt())
        self.ForceSubtracterDynamic = (math.random(3, 7) / 4) * (400 / GetConVar("xt2_tlifetime"):GetInt())
        self.range = math.random(1500, 8000)
        self.anticyclonicChanceDice = math.random(1,20)
        if self.anticyclonicChanceDice == 20 then
            self.anticycloniccheck = true
        elseif self.anticyclonicChanceDice ~= 20 then
            self.anticycloniccheck = false
        else
            self.anticycloniccheck = false
        end
        if self.anticycloniccheck == true then
            self.MaxWinds = math.random(75, 134)
            self.IsAnticyclonic = true
            self.CurrentAutospawnParticleTypeFlags = {"NORMAL"}
            self.CurrentAutospawnWallcloudColor = "anticyclonic"
        elseif self.anticycloniccheck == false then
            self.MaxWinds = math.random(65, 200)
            if math.random(1, 6) == 1 then
                self.MaxWinds = math.random(201, 320)
            end
            self.IsAnticyclonic = false
            local randomFactor = math.random(1, 20)
            if randomFactor <= 10 then
                self.CurrentAutospawnWallcloudColor = "white"
            elseif randomFactor <= 18 then
                self.CurrentAutospawnWallcloudColor = "black"
            else
                self.CurrentAutospawnWallcloudColor = "brown"
            end
        end
            
        self:SetModel( "models/props_junk/garbage_metalcan001a.mdl" )
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        self:SetColor( Color( 0, 0, 0, 0 ) )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:SetMoveType( MOVETYPE_FLY )
        self:SetSolid( SOLID_NONE )
        self:SetCollisionGroup( 1 )        
		self:testing2()
        self:startx()
    end
end

function ENT:OnRemove()
    self:OnRemoveX()
end