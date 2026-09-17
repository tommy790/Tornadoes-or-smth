
AddCSLuaFile()

SWEP.PrintName = "Lightning gun"
SWEP.Author = "Rainy"
SWEP.Purpose = "SMITE THEM"
SWEP.Category = "XTwisters_Sweps" 
SWEP.Slot = 1
SWEP.SlotPos = 2

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_smg1.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_smg1.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true 
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.AdminOnly = true


local ShootSound = Sound( "weapons/physcannon/superphys_small_zap1.wav" )

function SWEP:Initialize()

	self:SetHoldType( "smg" )

end

function SWEP:Reload()
end

function SWEP:CanBePickedUpByNPCs()
	return true
end

function SWEP:PrimaryAttack()
	local Owner = self:GetOwner()

	self:SetNextPrimaryFire( CurTime() + 0.5 )

	self:EmitSound( ShootSound )
	self:ShootEffects( self )

	if ( CLIENT ) then return end

	SuppressHostEvents( NULL ) -- Do not suppress the flechette effects

	local ent = ents.Create( "lightning_bolt" )
	if ( !IsValid( ent ) ) then return end


	ent:SetAngles( self.Owner:EyeAngles() )
	ent:SetOwner( self.Owner )
	ent:Spawn()
	ent:Activate()
	ent:SetPos( Owner:GetEyeTrace().HitPos or Owner:GetShootPos() )

end

function SWEP:SecondaryAttack()
	local Owner = self:GetOwner()

	self:SetNextSecondaryFire( CurTime() + 0.05 )

	self:EmitSound( ShootSound )
	self:ShootEffects( self )

	if ( CLIENT ) then return end

	SuppressHostEvents( NULL ) -- Do not suppress the flechette effects

	local ent = ents.Create( "lightning_bolt" )
	if ( !IsValid( ent ) ) then return end


	ent:SetAngles( self.Owner:EyeAngles() )
	ent:SetOwner( self.Owner )
	ent:Spawn()
	ent:Activate()
	ent:SetPos( Owner:GetEyeTrace().HitPos or Owner:GetShootPos() )

end

function SWEP:ShouldDropOnDie()

	return false

end

function SWEP:GetNPCRestTimes()


	return 0.3, 0.6

end

function SWEP:GetNPCBurstSettings()


	return 1, 6, 0.1

end

function SWEP:GetNPCBulletSpread( proficiency )

	
	return 1

end
