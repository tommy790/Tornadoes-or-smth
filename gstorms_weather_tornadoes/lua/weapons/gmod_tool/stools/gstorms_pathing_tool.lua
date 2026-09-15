if CLIENT then include("autorun/client/gstorms_config_menu.lua") end
if SERVER then include("gstorms_funcs/gstorms_shared.lua") end

include("gstorms_funcs/gstorms_shared_tools.lua")

TOOL.Tab = "GStorms"
TOOL.Category = "99_gstorms_tools"
TOOL.Mode = "gstorms_pathing_tool"

local gsMode = TOOL.Mode

local gsPathPreviewOffset = Vector(0, 0, 8)
local gsPathPointPixels = 14
local gsPathSelectDegrees = 1.15
local gsPathBoundsInset = 32
local gsPathGroundSamples = 6
local gsPathCurveSteps = 8

local gsSelectedPointColor = Color(255, 255, 255)
local gsPathPreview = {}
local gsPathRenderPoints = {}
local gsSelectedPath = 0
local gsSelectedNode = 0
local gsDefaultPathColor = Color(40, 220, 80)

local gsPathColorMixer
local gsPathDirectionButton

local gsPathDirAny = 0
local gsPathDirForwards = 1
local gsPathDirBackwards = 2

TOOL.Name = "#tool." .. gsMode .. ".name"
TOOL.ClientConVar = {
	path_r = tostring(gsDefaultPathColor.r),
	path_g = tostring(gsDefaultPathColor.g),
	path_b = tostring(gsDefaultPathColor.b),
	path_direction = tostring(gsPathDirAny),
	random_path_selection = "0"
}

local function GSClampColorChannel(n) return math.Clamp(math.floor(tonumber(n) or 0), 0, 255) end
local function GSBuildPathColor(r, g, b) return Color(GSClampColorChannel(r), GSClampColorChannel(g), GSClampColorChannel(b)) end
local function GSColorToTable(color) return {r = color.r, g = color.g, b = color.b} end

local function GSNormalizePathDirection(dir)
	dir = math.floor(tonumber(dir) or gsPathDirAny)

	if dir ~= gsPathDirForwards and dir ~= gsPathDirBackwards then return gsPathDirAny end

	return dir
end

local function GSPathDirectionToString(dir)
	dir = GSNormalizePathDirection(dir)

	if dir == gsPathDirForwards then return "Move Forwards" end
	if dir == gsPathDirBackwards then return "Move Backwards" end

	return "Move Any"
end

local function GSClearSelection(state)
	state.selectedPath = 0
	state.selectedNode = 0
end

local function GSPathRefreshClosed(path)
	path.closed = #path.points >= 3 and GSPathHasLink(path, 1, #path.points) and true or false
	return path.closed
end

local function GSWriteNetPath(path)
	local color = path.color or gsDefaultPathColor
	local points = path.points
	local count = #points
	local links = GSPathEnsureLinks(path)
	local edgeCount = 0

	net.WriteUInt(color.r, 8)
	net.WriteUInt(color.g, 8)
	net.WriteUInt(color.b, 8)
	net.WriteUInt(GSNormalizePathDirection(path.direction), 2)
	net.WriteUInt(count, 12)

	for j = 1, count do net.WriteVector(points[j]) end

	for a = 1, count do
		for b in pairs(links[a]) do
			if b > a then edgeCount = edgeCount + 1 end
		end
	end

	net.WriteUInt(edgeCount, 21)

	for a = 1, count do
		for b in pairs(links[a]) do
			if b > a then
				net.WriteUInt(a, 12)
				net.WriteUInt(b, 12)
			end
		end
	end
end

local function GSReadNetPath()
	local path = {color = GSBuildPathColor(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)), direction = GSNormalizePathDirection(net.ReadUInt(2)), points = {}, links = {}}
	local pointCount = net.ReadUInt(12)

	for j = 1, pointCount do
		path.points[j] = net.ReadVector()
		path.links[j] = {}
	end

	local edgeCount = net.ReadUInt(21)

	for i = 1, edgeCount do
		local a = net.ReadUInt(12)
		local b = net.ReadUInt(12)

		if a >= 1 and a <= pointCount and b >= 1 and b <= pointCount and a != b then
			path.links[a][b] = true
			path.links[b][a] = true
		end
	end

	GSPathRefreshClosed(path)

	return path, pointCount
end

local function GSWriteNetPaths(paths)
	net.WriteUInt(#paths, 8)
	for i = 1, #paths do GSWriteNetPath(paths[i]) end
end

local function GSPathsToTables(paths)
	local out = {}

	for i = 1, #paths do
		local path = paths[i]
		local color = path.color or gsDefaultPathColor

		out[i] = {color = GSColorToTable(color), direction = GSNormalizePathDirection(path.direction), closed = GSPathRefreshClosed(path), links = GSPathLinksToTables(path), points = GSPathPointsToTables(path.points or {})}
	end

	return out
end

local function GSNormalizePresetPaths(paths)
	local out = {}

	for i = 1, #(paths or {}) do
		local path = paths[i]

		if istable(path) then
			local points = GSNormalizePresetPoints(path.points)
			local pointCount = #points

			if pointCount > 0 then
				local color = path.color or gsDefaultPathColor
				local newPath = {color = GSBuildPathColor(color.r, color.g, color.b), direction = GSNormalizePathDirection(path.direction), points = points, links = GSNormalizePathLinks(path.links, pointCount, path.closed == true or path.closed == 1 or path.closed == "1")}

				GSPathRefreshClosed(newPath)
				out[#out + 1] = newPath
			end
		end
	end

	return out
end

local GSHandleLeftClick, GSRemoveLookedAtPathPoint, GSClearPathPoints
local GSSyncSelectedPathControls

if SERVER then

	local gsPathDataByPly = {}

	local function GSGetPathState(ply)
		local state = gsPathDataByPly[ply]
		if state then return state end

		state = {paths = {}, selectedPath = 0, selectedNode = 0}
		gsPathDataByPly[ply] = state

		return state
	end

	local function GSFindNearestPathNode(paths, pos)
		local px, py = pos.x, pos.y
		local bestPath, bestNode = 0, 0
		local bestDistSqr = nil

		for pathIndex = 1, #paths do
			local points = paths[pathIndex].points

			for nodeIndex = 1, #points do
				local node = points[nodeIndex]
				local dx = node.x - px
				local dy = node.y - py
				local distSqr = dx * dx + dy * dy

				if !bestDistSqr or distSqr < bestDistSqr then
					bestDistSqr = distSqr
					bestPath = pathIndex
					bestNode = nodeIndex
				end
			end
		end

		return bestPath, bestNode
	end

	local function GSPointInWorldXY(pos)
		local world = game.GetWorld()
		if !world:IsValid() then return true end

		local mins, maxs = world:GetModelBounds()

		return pos.x >= mins.x + gsPathBoundsInset and pos.x <= maxs.x - gsPathBoundsInset and pos.y >= mins.y + gsPathBoundsInset and pos.y <= maxs.y - gsPathBoundsInset
	end

	local function GSResolvePathPoint(trace)
		local hitPos = trace.HitPos
		local hitNormal = trace.HitNormal

		if !GSPointInWorldXY(hitPos) then return nil end

		hitPos = hitPos + (hitNormal * 8)

		local groundPos = GSGetGroundPosition(hitPos)
		if !groundPos then return nil end

		groundPos = Vector(groundPos.x, groundPos.y, groundPos.z + 8)

		if !GSPointInWorldXY(groundPos) then return nil end

		return groundPos
	end

	local function GSCanLinkPath(a, b)
		for i = 1, gsPathGroundSamples do
			local t = i / gsPathGroundSamples
			local sample = LerpVector(t, a, b)

			if !GSPointInWorldXY(sample) or !GSGetGroundPosition(sample) then return false end
		end

		return true
	end

	local function GSSanitizeSelection(state)
		local selectedPath = state.selectedPath
		local selectedNode = state.selectedNode

		if selectedPath <= 0 or selectedPath > #state.paths then GSClearSelection(state) return end

		local path = state.paths[selectedPath]
		if !path or selectedNode <= 0 or selectedNode > #path.points then GSClearSelection(state) end
	end

	local function GSSyncPathData(ply)
		if !ply:IsValid() then return end

		local state = GSGetPathState(ply)
		local paths = state.paths

		GSSanitizeSelection(state)

		net.Start("gs_pathing_tool_path_sync")
		net.WriteUInt(state.selectedPath or 0, 8)
		net.WriteUInt(state.selectedNode or 0, 12)
		GSWriteNetPaths(paths)
		net.Send(ply)
	end

	local function GSGetPlayerSelectedPathColor(ply) return 
        GSBuildPathColor(ply:GetInfoNum(gsMode .. "_path_r", gsDefaultPathColor.r), ply:GetInfoNum(gsMode .. "_path_g", gsDefaultPathColor.g), ply:GetInfoNum(gsMode .. "_path_b", gsDefaultPathColor.b)) 
    end

	local function GSChooseInitialLinkedNode(path, nodeIndex)
		local direction = GSNormalizePathDirection(path.direction)
		local links = GSPathEnsureLinks(path)
		local candidates = {}
	
		for other in pairs(links[nodeIndex] or {}) do
			if GSPathDirectionAllowsNode(path, nodeIndex, other, direction) then candidates[#candidates + 1] = other end
		end
	
		if #candidates == 0 then return nil end
	
		return candidates[math.random(#candidates)]
	end

	local function GSFindLookedAtPathNode(ply, paths)
		local eyePos = ply:EyePos()
		local aimVec = ply:GetAimVector()
		local cosThreshold = math.cos(math.rad(gsPathSelectDegrees))
		local bestPath, bestNode = nil, nil
		local bestDot, bestDist = cosThreshold, nil

		for pathIndex = 1, #paths do
			local path = paths[pathIndex]

			for nodeIndex = 1, #path.points do
				local dir = path.points[nodeIndex] - eyePos
				local len = dir:Length()

				if len > 0 then
					dir:Div(len)

					local dot = dir:Dot(aimVec)

					if dot >= bestDot and (!bestDist or len < bestDist or dot > bestDot) then
						bestDot = dot
						bestDist = len
						bestPath = pathIndex
						bestNode = nodeIndex
					end
				end
			end
		end

		return bestPath, bestNode
	end

    local function GSCreatePathWithPoint(ply, trace)
        local state = GSGetPathState(ply)
        local point = GSResolvePathPoint(trace)
        if !point then return false end
    
        state.paths[#state.paths + 1] = {color = GSGetPlayerSelectedPathColor(ply), direction = GSNormalizePathDirection(ply:GetInfoNum(gsMode .. "_path_direction", gsPathDirAny)), points = {point}, links = {[1] = {}}, closed = false}
        state.selectedPath = #state.paths
        state.selectedNode = 1
    
        GSSyncPathData(ply)
    
        return true
    end

    local function GSAddPointFromSelectedNode(ply, trace)
        local state = GSGetPathState(ply)
        GSSanitizeSelection(state)
    
        local path = state.paths[state.selectedPath]
        if !path or state.selectedNode <= 0 then return GSCreatePathWithPoint(ply, trace) end
    
        local point = GSResolvePathPoint(trace)
        if !point then return false end
    
        local fromNode = state.selectedNode
        local fromPos = path.points[fromNode]
        if !fromPos or !GSCanLinkPath(fromPos, point) then return false end
    
        local newIndex = #path.points + 1
        path.points[newIndex] = point
        path.links = GSPathCopyLinks(GSPathEnsureLinks(path), #path.points)
        path.links[newIndex] = {}
        GSPathAddLink(path, fromNode, newIndex)
        GSPathRefreshClosed(path)
    
        GSClearSelection(state)
        GSSyncPathData(ply)
    
        return true
    end

	local function GSMergePaths(srcPath, dstPath)
		local merged = {color = GSBuildPathColor(dstPath.color.r, dstPath.color.g, dstPath.color.b), direction = GSNormalizePathDirection(dstPath.direction), points = GSCopyPathPoints(srcPath.points), links = GSPathCopyLinks(GSPathEnsureLinks(srcPath), #srcPath.points), closed = false}
		local offset = #merged.points

		for i = 1, #dstPath.points do
			local p = dstPath.points[i]
			merged.points[#merged.points + 1] = Vector(p.x, p.y, p.z)
			merged.links[offset + i] = {}
		end

		local dstLinks = GSPathEnsureLinks(dstPath)

		for a = 1, #dstPath.points do
			for b in pairs(dstLinks[a]) do
				if b > a then GSPathAddLink(merged, offset + a, offset + b) end
			end
		end

		GSPathRefreshClosed(merged)

		return merged, offset
	end

    local function GSLinkSelectedToNode(ply, pathIndex, nodeIndex)
        local state = GSGetPathState(ply)
        GSSanitizeSelection(state)
    
        if state.selectedPath == 0 or state.selectedNode == 0 then
            state.selectedPath = pathIndex
            state.selectedNode = nodeIndex
            GSSyncPathData(ply)
            return true
        end
    
        if state.selectedPath == pathIndex and state.selectedNode == nodeIndex then
            GSClearSelection(state)
            GSSyncPathData(ply)
            return true
        end
    
        local selectedPathIndex = state.selectedPath
        local selectedNodeIndex = state.selectedNode
        local srcPath = state.paths[selectedPathIndex]
        local dstPath = state.paths[pathIndex]
    
        if !srcPath or !dstPath then
            GSClearSelection(state)
            GSSyncPathData(ply)
            return false
        end
    
        local srcPoint = srcPath.points[selectedNodeIndex]
        local dstPoint = dstPath.points[nodeIndex]
        if !srcPoint or !dstPoint or !GSCanLinkPath(srcPoint, dstPoint) then return false end
    
        if selectedPathIndex == pathIndex then
            if !GSPathHasLink(srcPath, selectedNodeIndex, nodeIndex) then GSPathAddLink(srcPath, selectedNodeIndex, nodeIndex) end
            GSPathRefreshClosed(srcPath)
    
            GSClearSelection(state)
            GSSyncPathData(ply)
            return true
        end
    
        local merged, offset = GSMergePaths(srcPath, dstPath)
        local mergedNodeIndex = offset + nodeIndex
    
        GSPathAddLink(merged, selectedNodeIndex, mergedNodeIndex)
        GSPathRefreshClosed(merged)
    
        state.paths[selectedPathIndex] = merged
        table.remove(state.paths, pathIndex)
    
        GSClearSelection(state)
        GSSyncPathData(ply)
    
        return true
    end

	GSHandleLeftClick = function(ply, trace)
		local state = GSGetPathState(ply)
		local pathIndex, nodeIndex = GSFindLookedAtPathNode(ply, state.paths)

		if pathIndex and nodeIndex then return GSLinkSelectedToNode(ply, pathIndex, nodeIndex) end

		GSSanitizeSelection(state)

		if state.selectedPath > 0 and state.selectedNode > 0 then return GSAddPointFromSelectedNode(ply, trace) end

		return GSCreatePathWithPoint(ply, trace)
	end

	GSRemoveLookedAtPathPoint = function(ply)
		local state = GSGetPathState(ply)
		local pathIndex, nodeIndex = GSFindLookedAtPathNode(ply, state.paths)
		if !pathIndex or !nodeIndex then return false end

		local path = state.paths[pathIndex]
		if !path then return false end

		if !GSPathRemoveNode(path, nodeIndex) then return false end

		if state.selectedPath == pathIndex then
			if #path.points == 0 then
				GSClearSelection(state)
			elseif state.selectedNode > nodeIndex then
				state.selectedNode = state.selectedNode - 1
			elseif state.selectedNode == nodeIndex then
				state.selectedNode = math.min(nodeIndex, #path.points)

				if state.selectedNode < 1 then GSClearSelection(state) end
			end
		elseif state.selectedPath > pathIndex and #path.points == 0 then
			state.selectedPath = state.selectedPath - 1
		end

		if #path.points == 0 then
			table.remove(state.paths, pathIndex)

			if state.selectedPath > pathIndex then state.selectedPath = state.selectedPath - 1 end
		end

		GSSanitizeSelection(state)
		GSSyncPathData(ply)

		return true
	end

	GSClearPathPoints = function(ply)
		local state = GSGetPathState(ply)

		if #state.paths == 0 then return false end

		state.paths = {}

		GSClearSelection(state)
		GSSyncPathData(ply)

		return true
	end

	local function GSSetPathData(ply, paths)
		local state = GSGetPathState(ply)
		local newPaths = {}

		for i = 1, #paths do
			local srcPath = paths[i]

			if istable(srcPath) then
				local color = srcPath.color or gsDefaultPathColor
				local newPath = {color = GSBuildPathColor(color.r, color.g, color.b), direction = GSNormalizePathDirection(srcPath.direction), points = {}, links = {}, closed = false}

				for j = 1, #(srcPath.points or {}) do
					local pos = srcPath.points[j]

					if isvector(pos) and GSPointInWorldXY(pos) then newPath.points[#newPath.points + 1] = Vector(pos.x, pos.y, pos.z) end
				end

				if #newPath.points > 0 then
					newPath.links = GSNormalizePathLinks(srcPath.links, #newPath.points, srcPath.closed)
					GSPathRefreshClosed(newPath)
					newPaths[#newPaths + 1] = newPath
				end
			end
		end

		state.paths = newPaths

		GSClearSelection(state)
		GSSyncPathData(ply)

		return true
	end

	local function GSResolveUpdatePath(ply)
		local state = GSGetPathState(ply)
		GSSanitizeSelection(state)
	
		if state.selectedPath > 0 and state.selectedNode > 0 and state.paths[state.selectedPath] then return state, state.selectedPath end
	
		local pathIndex, nodeIndex = GSFindLookedAtPathNode(ply, state.paths)
		if !pathIndex or !nodeIndex then return state, nil end
	
		state.selectedPath = pathIndex
		state.selectedNode = nodeIndex
	
		return state, pathIndex
	end

	local function GSUpdateSelectedPath(ply, color, direction)
		local state, pathIndex = GSResolveUpdatePath(ply)
		local path = pathIndex and state.paths[pathIndex]
		if !path then return false end
	
		local newColor = GSBuildPathColor(color.r, color.g, color.b)
		local newDirection = GSNormalizePathDirection(direction)
		local oldColor = path.color or gsDefaultPathColor
		local oldDirection = GSNormalizePathDirection(path.direction)
		if oldColor.r == newColor.r and oldColor.g == newColor.g and oldColor.b == newColor.b and oldDirection == newDirection then return false end
	
		path.color = newColor
		path.direction = newDirection
	
		GSSyncPathData(ply)
	
		return true
	end

	net.Receive("gs_pathing_tool_path_update", function(_, ply)
		if !ply:IsValid() then return end

		local color = Color(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8))
		local direction = net.ReadUInt(2)

		GSUpdateSelectedPath(ply, color, direction)
	end)

	net.Receive("gs_pathing_tool_path_set", function(_, ply)
		if !ply:IsValid() then return end

		local pathCount = net.ReadUInt(8)
		local totalPoints = 0
		local paths = {}

		if pathCount > 128 then return end

		for i = 1, pathCount do
			local path, pointCount = GSReadNetPath()

			totalPoints = totalPoints + pointCount

			if pointCount > 2048 or totalPoints > 4096 then return end

			paths[#paths + 1] = path
		end

		GSSetPathData(ply, paths)
	end)

	local function GSRandomPathNodeHasLink(path, nodeIndex)
		local direction = GSNormalizePathDirection(path.direction)
		local links = GSPathEnsureLinks(path)

		for other in pairs(links[nodeIndex] or {}) do
			if GSPathDirectionAllowsNode(path, nodeIndex, other, direction) then return true end
		end

		return false
	end

	local function GSChooseRandomPathNode(paths)
		local pathCandidates = {}
		local nodeCandidates = {}

		for pathIndex = 1, #paths do
			local path = paths[pathIndex]
			local nodes = {}

			for nodeIndex = 1, #path.points do
				if GSRandomPathNodeHasLink(path, nodeIndex) then nodes[#nodes + 1] = nodeIndex end
			end

			if #nodes > 0 then
				pathCandidates[#pathCandidates + 1] = pathIndex
				nodeCandidates[#nodeCandidates + 1] = nodes
			end
		end

		if #pathCandidates == 0 then return nil, nil end

		local i = math.random(#pathCandidates)
		local nodes = nodeCandidates[i]

		return pathCandidates[i], nodes[math.random(#nodes)]
	end

	GSPathingToolBuildSpawnFollowData = function(ply, spawnPos, randomSelection)
		local state = GSGetPathState(ply)
		local paths = state.paths
		if #paths == 0 then return nil end

		local pathIndex, nodeIndex

		if randomSelection then
			pathIndex, nodeIndex = GSChooseRandomPathNode(paths)
		else
			pathIndex, nodeIndex = GSFindNearestPathNode(paths, spawnPos)
		end

		if !pathIndex or !nodeIndex then return nil end

		local srcPath = paths[pathIndex]
		if !srcPath or !srcPath.points[nodeIndex] then return nil end

		local snapshot = {color = GSBuildPathColor(srcPath.color.r, srcPath.color.g, srcPath.color.b), direction = GSNormalizePathDirection(srcPath.direction), points = GSCopyPathPoints(srcPath.points), links = GSPathCopyLinks(GSPathEnsureLinks(srcPath), #srcPath.points), closed = GSPathRefreshClosed(srcPath)}
		local nextNode = GSChooseInitialLinkedNode(snapshot, nodeIndex)

		if !nextNode then return nil end

        local prevIndex = GSGetCurveNeighbor(snapshot, nodeIndex, nextNode, nextNode, false)
        local nextIndex = GSGetCurveNeighbor(snapshot, nextNode, nodeIndex, nodeIndex, true)
        local edgePoints = GSBuildPathEdgeCurve(snapshot.points, nodeIndex, nextNode, prevIndex, nextIndex, gsPathCurveSteps)

		if #edgePoints == 0 then return nil end

        return {
            points = snapshot.points,
            links = snapshot.links,
            direction = snapshot.direction,
            pathIndex = pathIndex,
            nodeIndex = nodeIndex,
            prevNode = 0,
            curNode = nodeIndex,
            nextNode = nextNode,
            edgePoints = edgePoints,
            edgePointIndex = math.min(2, #edgePoints),
            curveSteps = gsPathCurveSteps
        }, snapshot.points[nodeIndex]
	end

	GSPathingToolSendPreviewFlash = function(ply, pathIndex, nodeIndex)
		if !IsValid(ply) then return end

		net.Start("gs_pathing_tool_preview_flash")
		net.WriteUInt(pathIndex or 0, 8)
		net.WriteUInt(nodeIndex or 0, 12)
		net.Send(ply)
	end

	hook.Add("PlayerDisconnected", "GS_PathingToolCleanup", function(ply) gsPathDataByPly[ply] = nil end)
end

if CLIENT then
	language.Add("tool." .. gsMode .. ".name", GSSortText(2, "Pathing Tool"))
	language.Add("tool." .. gsMode .. ".desc", "Creates and manages multiple linked tornado movement paths.")
	language.Add("tool." .. gsMode .. ".0", "Left click: Select / link / add point | Right click: Remove looked at point | Reload: Clear all pathing")
	language.Add("tool." .. gsMode .. ".1", "Added.")
	language.Add("tool." .. gsMode .. ".2", "Removed.")

	local gsPathPointMat = Material("other/icons/gstorms_map_icon")
	local gsPathDirectionMat = Material("other/icons/gstorms_direction_icon")
	local gsPathPreviewFlashStart = 0
	local gsPathPreviewFlashEnd = 0
	local gsPathPreviewFocusPath = 0
	local gsPathPreviewFocusNode = 0
	local gsToolDeployPreviewUntil = 0
	local gsToolDeployPreviewClass

	local function GSPathShouldReverseArrow(path, a, b)
		local direction = GSNormalizePathDirection(path.direction)
		if direction == gsPathDirAny then return nil end
	
		local wrap = path.closed and a == 1 and b == #path.points
	
		if direction == gsPathDirForwards then return wrap end
	
		return !wrap
	end

	local function GSGetPathColor(path) return path.color or gsDefaultPathColor end

	GSSyncSelectedPathControls = function()
		local path = gsPathPreview[gsSelectedPath]
	
		if !path then
			if IsValid(gsPathDirectionButton) then
				gsPathDirectionButton:SetText(GSPathDirectionToString(GSNormalizePathDirection(GetConVar(gsMode .. "_path_direction"):GetInt())))
			end
			return
		end
	
		local color = GSGetPathColor(path)
		local direction = GSNormalizePathDirection(path.direction)
	
		RunConsoleCommand(gsMode .. "_path_r", tostring(color.r))
		RunConsoleCommand(gsMode .. "_path_g", tostring(color.g))
		RunConsoleCommand(gsMode .. "_path_b", tostring(color.b))
		RunConsoleCommand(gsMode .. "_path_direction", tostring(direction))
	
		if IsValid(gsPathColorMixer) then gsPathColorMixer:SetColor(color) end
		if IsValid(gsPathDirectionButton) then gsPathDirectionButton:SetText(GSPathDirectionToString(direction)) end
	end

	local function GSRebuildRenderPaths()
		gsPathRenderPoints = {}
	
		for i = 1, #gsPathPreview do
			local path = gsPathPreview[i]
			local links = GSPathEnsureLinks(path)
			local segments = {}
	
			for a = 1, #path.points do
				for b in pairs(links[a]) do
					if b > a then
						local prevIndex = GSGetCurveNeighbor(path, a, b, b, false)
						local nextIndex = GSGetCurveNeighbor(path, b, a, a, true)
	
						segments[#segments + 1] = {
							a = a,
							b = b,
							points = GSBuildPathEdgeCurve(path.points, a, b, prevIndex, nextIndex, gsPathCurveSteps)
						}
					end
				end
			end
	
			gsPathRenderPoints[i] = segments
		end
	end

	net.Receive("gs_pathing_tool_path_sync", function()
		gsPathPreview = {}
		gsSelectedPath = net.ReadUInt(8)
		gsSelectedNode = net.ReadUInt(12)

		local pathCount = net.ReadUInt(8)

		for i = 1, pathCount do gsPathPreview[i] = GSReadNetPath() end

		GSRebuildRenderPaths()
		GSSyncSelectedPathControls()
	end)

	net.Receive("gs_pathing_tool_preview_flash", function()
		gsPathPreviewFocusPath = net.ReadUInt(8)
		gsPathPreviewFocusNode = net.ReadUInt(12)
		gsPathPreviewFlashStart = CurTime()
		gsPathPreviewFlashEnd = gsPathPreviewFlashStart + 2.15
	end)

	local function GSIsPathPreviewEntity(class) return GSIsGStormsWeatherClass(class) end
	local function GSIsPathPreviewOwnedByLocal(ent, ply) return IsValid(ent) and GSIsPathPreviewEntity(ent:GetClass()) and ent:GetNWEntity("GSPathingOwner") == ply end

	local function GSGetToolDeployPreviewClass(wep)
		if !IsValid(wep) or wep:GetClass() ~= "gmod_tool" or !wep.GetToolObject then return nil end

		local tool = wep:GetToolObject()
		if !tool then return nil end

		if IsValid(tool.GhostEntity) then return tool.GhostEntity:GetClass() end

		if tool.GetEnt then
			for i = 1, 8 do
				local ent = tool:GetEnt(i)
				if IsValid(ent) then return ent:GetClass() end
			end
		end

		return nil
	end

	hook.Add("Think", "GS_PathingToolDeployPreview", function()
		local ply = LocalPlayer()

		if !ply:IsValid() then gsToolDeployPreviewUntil = 0 return end

		local wep = ply:GetActiveWeapon()

		if !IsValid(wep) or wep:GetClass() ~= "gmod_tool" then gsToolDeployPreviewUntil = 0 return end

		local mode = ply:GetInfo("gmod_toolmode")
		if mode ~= "creator" and mode ~= "duplicator" then gsToolDeployPreviewUntil = 0 return end

		local class = GSGetToolDeployPreviewClass(wep) or gsToolDeployPreviewClass

		if GSIsPathPreviewEntity(class) then gsToolDeployPreviewUntil = CurTime() + 0.15 end
	end)

	hook.Add("SpawnmenuIconMenuOpen", "GS_PathingToolTrackDeployClass", function(menu, icon, contentType)
		if !IsValid(icon) or !icon.GetSpawnName then return end

		local class = icon:GetSpawnName()

		if GSIsPathPreviewEntity(class) then
			gsToolDeployPreviewClass = class
		else
			gsToolDeployPreviewClass = nil
		end
	end)

	local function GSGetPathPreviewState()
		local ply = LocalPlayer()
		if !ply:IsValid() then return false end

		local curTime = CurTime()

		if curTime < gsPathPreviewFlashEnd then
			local alphaFrac = curTime <= gsPathPreviewFlashStart + 0.15 and 1 or math.Clamp((gsPathPreviewFlashEnd - curTime) / 2, 0, 1)
			return true, alphaFrac, gsPathPreviewFocusPath, gsPathPreviewFocusNode, false
		end

		if curTime < gsToolDeployPreviewUntil then return true, 1, 0, 0, false end

		local tr = ply:GetEyeTrace()
		local ent = tr and tr.Entity
		if GSIsPathPreviewOwnedByLocal(ent, ply) then return true, 1, 0, 0, false end

		local wep = ply:GetActiveWeapon()
		if !wep:IsValid() or wep:GetClass() ~= "gmod_tool" then return false end

		local mode = ply:GetInfo("gmod_toolmode")
		if mode == gsMode then return true, 1, 0, 0, true end
		if mode == "gstorms_custom_tornado" then return true, 1, 0, 0, false end

		return false
	end

	local function GSColorWithAlpha(color, alpha) return Color(color.r, color.g, color.b, math.Clamp(math.floor(alpha or 255), 0, 255)) end
	local function GSGetPathPointWorldSize(dist, fovTan, screenH) return math.max(4, 2 * dist * fovTan * (gsPathPointPixels / screenH)) end

	local gsPathUpVec = Vector(0, 0, 1)

	hook.Add("PostDrawTranslucentRenderables", "GS_PathingToolPreview", function(depth, skybox)
		local shouldDraw, alphaFrac, focusPath, focusNode, showSelected = GSGetPathPreviewState()
		if depth or skybox or !shouldDraw then return end
	
		local preview = gsPathPreview
		if #preview == 0 then return end
	
		local ply = LocalPlayer()
		local eyePos = EyePos()
		local fovTan = math.tan(math.rad(ply:GetFOV() * 0.5))
		local screenH = ScrH()
		local renderPaths = gsPathRenderPoints
		local alpha = 255 * alphaFrac
		local flashActive = focusPath > 0 and focusNode > 0
	
		cam.IgnoreZ(true)
	
		for i = 1, #renderPaths do
			local segments = renderPaths[i]
			local baseColor = GSGetPathColor(preview[i])
			local lineColor = GSColorWithAlpha(baseColor, alpha)
	
			if flashActive and i == focusPath then lineColor = GSColorWithAlpha(gsSelectedPointColor, alpha) end
	
			for s = 1, #segments do
				local renderPoints = segments[s].points
	
				for j = 1, #renderPoints - 1 do
					render.DrawLine(renderPoints[j] + gsPathPreviewOffset, renderPoints[j + 1] + gsPathPreviewOffset, lineColor, true)
				end
			end
		end
	
		render.SetMaterial(gsPathDirectionMat)
	
		for i = 1, #renderPaths do
			local path = preview[i]
			local direction = GSNormalizePathDirection(path.direction)
			if direction == gsPathDirAny then continue end
	
			local segments = renderPaths[i]
			local arrowColor = GSColorWithAlpha(GSGetPathColor(path), alpha)
	
			if flashActive and i == focusPath then arrowColor = GSColorWithAlpha(gsSelectedPointColor, alpha) end
	
			for s = 1, #segments do
				local seg = segments[s]
				local renderPoints = seg.points
				local mid = math.floor(#renderPoints * 0.5)
	
				if mid < 1 then mid = 1 end
				if mid >= #renderPoints then mid = #renderPoints - 1 end
				if mid < 1 then continue end
	
				local p1 = renderPoints[mid]
				local p2 = renderPoints[mid + 1]
	
				if GSPathShouldReverseArrow(path, seg.a, seg.b) then p1, p2 = p2, p1 end
	
				local pos = ((p1 + p2) * 0.5) + gsPathPreviewOffset
				local dir = p2 - p1
				local size = GSGetPathPointWorldSize(eyePos:Distance(pos), fovTan, screenH) * 1.15
	
				render.DrawQuadEasy(pos, gsPathUpVec, size, size, arrowColor, math.deg(math.atan2(dir.y, dir.x)) - 0)
			end
		end
	
		render.SetMaterial(gsPathPointMat)
	
		for i = 1, #preview do
			local path = preview[i]
			local pointColor = GSColorWithAlpha(GSGetPathColor(path), alpha)
	
			for j = 1, #path.points do
				local pos = path.points[j] + gsPathPreviewOffset
				local dist = eyePos:Distance(pos)
				local size = GSGetPathPointWorldSize(dist, fovTan, screenH)
	
				if flashActive and i == focusPath and j == focusNode then
					render.DrawSprite(pos, size * 1.5, size * 1.5, GSColorWithAlpha(gsSelectedPointColor, alpha))
				elseif showSelected and i == gsSelectedPath and j == gsSelectedNode then
					render.DrawSprite(pos, size * 1.35, size * 1.35, GSColorWithAlpha(gsSelectedPointColor, alpha))
				else
					render.DrawSprite(pos, size, size, pointColor)
				end
			end
		end
	
		cam.IgnoreZ(false)
	end)

	local function GSGetMapPresetFolder() return "gstorms/gstorms_paths/" .. string.lower(game.GetMap() or "unknown") end
	local function GSNormalizePresetData(data) return {paths = GSNormalizePresetPaths(data and data.paths or {})} end
	local function GSReadCurrentToolPreset() return {paths = GSPathsToTables(gsPathPreview)} end

	local function GSSendPathsToServer(paths)
		net.Start("gs_pathing_tool_path_set")
		GSWriteNetPaths(paths)
		net.SendToServer()
	end

	local function GSApplyPresetToPath(data)
		local preset = GSNormalizePresetData(data)
		local paths = {}

		for i = 1, #preset.paths do
			local srcPath = preset.paths[i]

			paths[i] = {color = GSBuildPathColor(srcPath.color.r, srcPath.color.g, srcPath.color.b), direction = GSNormalizePathDirection(srcPath.direction), closed = srcPath.closed, points = GSCopyPathPoints(srcPath.points), links = GSPathCopyLinks(srcPath.links, #srcPath.points)}
		end

		GSSendPathsToServer(paths)
	end

	local function GSAddPathingPresetControls(option)
		local gsPresetDir = GSGetMapPresetFolder()

		GSAddFilePresetControls(option, {
			baseFolder = gsPresetDir,
			treeName = "Pathing Presets - " .. game.GetMap(),

			readPreset = GSReadCurrentToolPreset,
			normalizePreset = GSNormalizePresetData,
			applyPreset = GSApplyPresetToPath,

			saveTooltip = "Saves all current path sets for this map",
			createFolderTooltip = "Creates a folder for organizing pathing presets on this map",
			importTooltip = "Imports a pathing preset or folder from a copied JSON string",
			exportTooltip = "Copies the selected pathing preset or folder as a JSON string so it can be shared",
			deletePresetTooltip = "Deletes the selected preset for this map",
			deleteFolderTooltip = "Deletes the selected folder and everything inside it for this map",
			browserHelpText = "Single click a folder to choose where presets save. Double click a preset to load it.",

			deletePresetQueryText = function(name) return "Delete preset '" .. name .. "' for map '" .. game.GetMap() .. "'?" end,
			deleteFolderQueryText = function(name) return "Delete folder '" .. name .. "' and everything inside it for map '" .. game.GetMap() .. "'?" end,
		})
	end

	function TOOL.BuildCPanel(panel)
		GSAddCollapsibleSection(panel, "Presets", true, function(option)
			GSAddPathingPresetControls(option)

			gsPathColorMixer = vgui.Create("DColorMixer", option)
			gsPathColorMixer:Dock(TOP)
			gsPathColorMixer:SetTall(180)
			gsPathColorMixer:SetPalette(true)
			gsPathColorMixer:SetAlphaBar(false)
			gsPathColorMixer:SetWangs(true)

			local cvR = GetConVar(gsMode .. "_path_r")
			local cvG = GetConVar(gsMode .. "_path_g")
			local cvB = GetConVar(gsMode .. "_path_b")

			gsPathColorMixer:SetColor(Color(cvR and cvR:GetInt() or gsDefaultPathColor.r, cvG and cvG:GetInt() or gsDefaultPathColor.g, cvB and cvB:GetInt() or gsDefaultPathColor.b))
			option:AddItem(gsPathColorMixer)

			gsPathColorMixer.ValueChanged = function(_, color)
				RunConsoleCommand(gsMode .. "_path_r", tostring(GSClampColorChannel(color.r)))
				RunConsoleCommand(gsMode .. "_path_g", tostring(GSClampColorChannel(color.g)))
				RunConsoleCommand(gsMode .. "_path_b", tostring(GSClampColorChannel(color.b)))
			end

			GSCheckBox(option, "Enable Random Path Selection", gsMode .. "_random_path_selection"):SetTooltip("Spawns owned tornadoes onto a random path and random node instead of the nearest one")

			gsPathDirectionButton = option:Button("")
			gsPathDirectionButton:SetTooltip("Cycles how the selected path moves: first to last, last to first, or either")

			local function UpdateDirectionButtonText()
				if !IsValid(gsPathDirectionButton) then return end
				gsPathDirectionButton:SetText(GSPathDirectionToString(GetConVar(gsMode .. "_path_direction"):GetInt()))
			end

			UpdateDirectionButtonText()

			gsPathDirectionButton.DoClick = function()
				local directionValue = (GSNormalizePathDirection(GetConVar(gsMode .. "_path_direction"):GetInt()) + 1) % 3
				RunConsoleCommand(gsMode .. "_path_direction", tostring(directionValue))
				if IsValid(gsPathDirectionButton) then gsPathDirectionButton:SetText(GSPathDirectionToString(directionValue)) end
			end

			local applyButton = option:Button("Update Path")
			applyButton:SetTooltip("Applies the current color and path movement direction settings to the selected path")
			applyButton.DoClick = function()
				if gsSelectedPath <= 0 or !gsPathPreview[gsSelectedPath] then
					LocalPlayer():ChatPrint("You first need to select a path before you can update the move direction type")
					return
				end
			
				local color = gsPathColorMixer:GetColor()
			
				net.Start("gs_pathing_tool_path_update")
				net.WriteUInt(GSClampColorChannel(color.r), 8)
				net.WriteUInt(GSClampColorChannel(color.g), 8)
				net.WriteUInt(GSClampColorChannel(color.b), 8)
				net.WriteUInt(GSNormalizePathDirection(GetConVar(gsMode .. "_path_direction"):GetInt()), 2)
				net.SendToServer()
			end

			GSSyncSelectedPathControls()
		end)
	end
end

function TOOL:LeftClick(trace)
	if CLIENT then return true end
	if !trace.Hit then return false end
	return GSHandleLeftClick(self:GetOwner(), trace)
end

function TOOL:RightClick(trace)
	if CLIENT then return true end
	return GSRemoveLookedAtPathPoint(self:GetOwner())
end

function TOOL:Reload(trace)
	if CLIENT then return true end
	return GSClearPathPoints(self:GetOwner())
end