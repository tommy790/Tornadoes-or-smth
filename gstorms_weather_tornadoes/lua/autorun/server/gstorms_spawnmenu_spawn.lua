if CLIENT then return end

include("gstorms_funcs/gstorms_shared.lua")
include("gstorms_funcs/gstorms_shared_tools.lua")
include("autorun/gstorms_groundposition.lua")

local gsAdminOnly = {
	["gstorms_weather_*"] = true,
	["gstorms_earthquake*"] = true,
	["gstorms_volcano"] = true,
	["gstorms_lightning_entity"] = true,
}

local gsAdminOnlyCache = {}

local function GSSpawnMatch(glob, str)

	local cached = gsAdminOnlyCache[glob]

	if cached == nil then
		local p = "^" .. string.PatternSafe(glob):gsub("%%%*", ".*") .. "$"
		gsAdminOnlyCache[glob] = p
		cached = p
	end

	return str:find(cached) ~= nil

end

local function GSIsAdminOnlyClass(class)
	if gsAdminOnly[class] then return true end

	for rule, enabled in pairs(gsAdminOnly) do
		if enabled and isstring(rule) and rule:find("*", 1, true) and GSSpawnMatch(rule, class) then return true end
	end

	return false
end

hook.Add("PlayerSpawnSENT", "GStorms_AdminOnly_SENTS", function(ply, class)
	if GSIsAdminOnlyClass(class) and !ply:IsAdmin() then
		GSTipToClient(ply, "You Need To Be An Admin To Spawn That")
		return false
	end
end)

local spawnRandRadius = 35000
local spawnRandRadiusMin = 7500
local spawnRandRadiusMinSqr = spawnRandRadiusMin * spawnRandRadiusMin
local maxChecks = 50

local function GSCanUsePathing(ent)
	return IsValid(ent) and !ent.Autospawn and GSIsGStormsWeatherClass(ent:GetClass())
end

function GSApplySpawnPathing(ply, ent)
	if !GSCanUsePathing(ent) or !GSPathingToolBuildSpawnFollowData then return false end

	local follow, nodePos = GSPathingToolBuildSpawnFollowData(ply, ent:GetPos(), ply:GetInfoNum("gstorms_pathing_tool_random_path_selection", 0) == 1)
	if !follow or !nodePos then return false end

	local groundPos = GSGetGroundPosition(nodePos)
	local newPos = groundPos and Vector(groundPos.x, groundPos.y, groundPos.z + 8) or Vector(nodePos.x, nodePos.y, nodePos.z)

	ent.PathingData = follow
	ent.Position = newPos
	ent.HeightLerpZ = nil
	ent.HeightLerpTargetZ = nil
	ent.HeightLerpLastTime = nil
	ent.ChangedDirection = false
	ent:SetPos(newPos)

	if GSPathingToolSendPreviewFlash then GSPathingToolSendPreviewFlash(ply, follow.pathIndex, follow.nodeIndex) end

	return true
end

local function GSApplyRandomSpawnPos(ply, ent)
	if !GetConVar("gstorms_sim_spawn_random_position"):GetBool() then return end
	if !IsValid(ply) or !IsValid(ent) then return end

	local position = ent:GetPos()
	local baseZ = (gs_heightPositionFromServerLoad and gs_heightPositionFromServerLoad.server and gs_heightPositionFromServerLoad.server.z) or position.z

	for i = 1, maxChecks do
		local randX = math.random(-spawnRandRadius, spawnRandRadius)
		local randY = math.random(-spawnRandRadius, spawnRandRadius)

		if randX * randX + randY * randY >= spawnRandRadiusMinSqr then
			local newPos = Vector(randX + position.x, randY + position.y, baseZ - 10)
			if util.IsInWorld(newPos) then position = newPos break end
		end
	end

	ent:SetPos(position)
end

hook.Add("PlayerSpawnedSENT", "GStorms_RandomSpawnPos_SENTS", function(ply, ent) 
	if !IsValid(ply) or !IsValid(ent) then return end

	local class = ent:GetClass()
	if class:sub(1, 15) ~= "gstorms_weather" and class:sub(1, 18) ~= "gstorms_earthquake" then return end

	ent:SetOwner(ply)
	ent:SetCreator(ply)
	
	if !GSApplySpawnPathing(ply, ent) then GSApplyRandomSpawnPos(ply, ent) end
end)

net.Receive("gs_spawn_entity", function(_, ply) -- Forces menu spawning at any distance for entities
	local class = net.ReadString()
	if !IsValid(ply) then return end
	if hook.Run("PlayerSpawnSENT", ply, class) == false then return end

	local tr = ply:GetEyeTraceNoCursor()
	if !tr or !tr.HitPos then return end

	local ent = ents.Create(class)
	if !IsValid(ent) then return end

	ent:SetPos(tr.HitPos + tr.HitNormal * 16)
	ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
	ent:Spawn()
	ent:Activate()

	hook.Run("PlayerSpawnedSENT", ply, ent)

	ply:AddCleanup("sents", ent)

	undo.Create(class)
		undo.AddEntity(ent)
		undo.SetPlayer(ply)
	undo.Finish(class)
end)