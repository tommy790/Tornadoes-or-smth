-- This is the shared file for tools such as gstorms_custom_tornado.lua & gstorms_pathing_tool.lua

function GSIsGStormsWeatherClass(class) return isstring(class) and class:sub(1, 15) == "gstorms_weather" and !class:find("sandstorm", 1, true) and !class:find("pyroclastic", 1, true) end
function GSBool(n) return (tonumber(n) or 0) == 1 end

local function GSMapPresetPoints(points, mapFn, skipInvalid)
	local out = {}

	for i = 1, #(points or {}) do
		local p = points[i]

		if !skipInvalid or istable(p) or isvector(p) then
			local mapped = mapFn(p, i)

			if skipInvalid then
				if mapped != nil then out[#out + 1] = mapped end
			else
				out[i] = mapped
			end
		end
	end

	return out
end

function GSCopyPathPoints(points) return GSMapPresetPoints(points, function(p) return Vector(p.x, p.y, p.z) end) end
function GSPathPointsToTables(points) return GSMapPresetPoints(points, function(p) return {x = p.x, y = p.y, z = p.z} end) end
function GSNormalizePresetPoints(points) return GSMapPresetPoints(points, function(p) return {x = tonumber(p.x) or 0, y = tonumber(p.y) or 0, z = tonumber(p.z) or 0} end, true) end

local function GSResolvePresetFolder(baseDir, presetDir, presetFile)
	if presetDir == nil and presetFile == nil then return isfunction(baseDir) and baseDir() or baseDir end

	local path = isfunction(presetFile) and presetFile() or presetFile

	if isstring(path) and path != "" then return path:sub(-5) == ".json" and path:sub(1, -6) or path end
	return isstring(presetDir) and presetDir != "" and presetDir or (baseDir or "")
end

local function GSSanitizePresetName(name, fallback)
	name = string.Trim(tostring(name or fallback or ""))
	name = name:gsub("%.json$", "")
	name = name:gsub("[\\/:*?\"<>|]", "_")
	name = name:gsub("%s+", " ")
	name = string.Trim(name)

	if name == "" then name = fallback or "unnamed_preset" end

	return name
end

local function GSJoinPresetPath(a, b)
	if !a or a == "" then return b or "" end
	if !b or b == "" then return a end
	return a .. "/" .. b
end

function GSEnsurePresetDir(baseDir, presetDir, presetFile)
	local path = presetFile != nil and GSResolvePresetFolder(baseDir, presetDir, presetFile) or (presetDir != nil and presetDir or baseDir)
	if !path or path == "" then return end

	local parts = string.Explode("/", path, false)
	local cur = ""

	for i = 1, #parts do
		local part = parts[i]

		if part != "" then
			cur = cur == "" and part or (cur .. "/" .. part)
			if !file.Exists(cur, "DATA") then file.CreateDir(cur) end
		end
	end
end

local function GSGetPresetParentFolder(path)
	if !isstring(path) then return nil end
	local idx = path:find("/[^/]*$", 1)
	return idx and path:sub(1, idx - 1) or ""
end

local function GSGetPresetLeafName(path) return isstring(path) and ((path:match("([^/]+)$") or path):gsub("%.json$", "")) or "" end
local function GSNormalizePresetData(data, normalizeFn) data = data or {} return normalizeFn and normalizeFn(data) or data end
local function GSBuildPresetPayload(name, data, normalizeFn) return {name = name, data = GSNormalizePresetData(data, normalizeFn)} end

local function GSResolvePresetFilePath(path, rootFolder)
	if !isstring(path) or path == "" then return nil end

	if path:sub(-5) == ".json" and file.Exists(path, "DATA") then return path end

	local jsonPath = path .. ".json"
	if file.Exists(jsonPath, "DATA") then return jsonPath end

	local leaf = GSGetPresetLeafName(path)
	if leaf == "" or !rootFolder or rootFolder == "" then return nil end

	local directPath = GSJoinPresetPath(rootFolder, leaf .. ".json")
	if file.Exists(directPath, "DATA") then return directPath end

	return nil
end

local function GSGetUniquePresetPath(folder, name, isFolder, ignorePath)
	GSEnsurePresetDir(folder)

	local clean = GSSanitizePresetName(name, isFolder and "New Folder" or "unnamed_preset")
	local suffix = isFolder and "" or ".json"
	local path = GSJoinPresetPath(folder, clean .. suffix)

	while file.Exists(path, "DATA") and path != ignorePath do
		clean = clean .. "_copy"
		path = GSJoinPresetPath(folder, clean .. suffix)
	end

	return path, clean
end

local function GSReadPresetFile(path)
	if !path or !file.Exists(path, "DATA") then return nil end

	local raw = file.Read(path, "DATA")
	if !raw or raw == "" then return nil end

	local tbl = util.JSONToTable(raw)
	if !istable(tbl) then return nil end

	if tbl.data == nil then tbl.data = {} end
	if tbl.name == nil or string.Trim(tostring(tbl.name)) == "" then tbl.name = GSGetPresetLeafName(path) end

	return tbl
end

local function GSWritePresetFile(folder, name, data, normalizeFn)
	local path, clean = GSGetUniquePresetPath(folder, name, false)

	file.Write(path, util.TableToJSON(GSBuildPresetPayload(clean, data, normalizeFn), true))

	return true, path, "preset", clean
end

local function GSCreatePresetFolder(folder, name)
	local path, clean = GSGetUniquePresetPath(folder, name, true)
	GSEnsurePresetDir(path)
	return true, path, clean
end

local function GSRenamePresetPath(path, name, normalizeFn)
	if !path or !file.Exists(path, "DATA") then return false end

	local parent = GSGetPresetParentFolder(path)
	local isFolder = path:sub(-5) != ".json"
	local clean = GSSanitizePresetName(name, GSGetPresetLeafName(path))
	local current = GSGetPresetLeafName(path)

	if clean == current then
		if !isFolder then
			local tbl = GSReadPresetFile(path)
			if !tbl then return false end
			file.Write(path, util.TableToJSON(GSBuildPresetPayload(clean, tbl.data, normalizeFn), true))
		end

		return true, path, clean, isFolder and "folder" or "preset"
	end

	if isFolder then
		local json = GSExportPresetFolderShared(path, normalizeFn)
		local tbl = util.JSONToTable(json or "")
		if !istable(tbl) then return false end

		tbl.name = clean

		local ok, newPath, kind = GSImportPresetShared(parent, util.TableToJSON(tbl, true), normalizeFn)
		if !ok or !newPath then return false end
		if !GSDeletePresetPath(path) then return false end

		return true, newPath, GSGetPresetLeafName(newPath), kind
	end

	local tbl = GSReadPresetFile(path)
	if !tbl then return false end

	local newPath, unique = GSGetUniquePresetPath(parent, clean, false, path)
	file.Write(newPath, util.TableToJSON(GSBuildPresetPayload(unique, tbl.data, normalizeFn), true))

	if newPath != path then file.Delete(path) end

	return true, newPath, unique, "preset"
end

local function GSDeletePresetPath(path)
	if !path or !file.Exists(path, "DATA") then return false end

	if path:sub(-5) == ".json" then
		file.Delete(path)
		return !file.Exists(path, "DATA")
	end

	local files, folders = file.Find(path .. "/*", "DATA")

	for i = 1, #files do
		file.Delete(path .. "/" .. files[i])
	end

	for i = 1, #folders do
		GSDeletePresetPath(path .. "/" .. folders[i])
	end

	file.Delete(path)

	return !file.Exists(path, "DATA")
end

local function GSListPresetFolder(folder)
	GSEnsurePresetDir(folder)

	local files, folders = file.Find(folder .. "/*", "DATA")
	local outFolders = {}
	local outPresets = {}

	table.sort(folders, function(a, b) return string.lower(a) < string.lower(b) end)
	table.sort(files, function(a, b) return string.lower(a) < string.lower(b) end)

	for i = 1, #folders do
		local name = folders[i]
		outFolders[#outFolders + 1] = {name = name, path = folder .. "/" .. name}
	end

	for i = 1, #files do
		local fileName = files[i]

		if fileName:sub(-5) == ".json" then
			local path = folder .. "/" .. fileName
			local tbl = GSReadPresetFile(path)
			local name = tbl and GSSanitizePresetName(tbl.name, GSGetPresetLeafName(path)) or GSGetPresetLeafName(path)

			outPresets[#outPresets + 1] = {name = name, path = path}
		end
	end

	return outFolders, outPresets
end

function GSSaveNamedPresetShared(baseDir, presetDir, presetFile, name, readFn, normalizeFn, folderOverride)
	local folder = folderOverride or GSResolvePresetFolder(baseDir, presetDir, presetFile)
	return GSWritePresetFile(folder, name, readFn and readFn() or {}, normalizeFn)
end

function GSExportPresetShared(path, normalizeFn)
	local tbl = GSReadPresetFile(path)
	return tbl and util.TableToJSON(GSBuildPresetPayload(tbl.name, tbl.data, normalizeFn), true) or nil
end

local function GSBuildFolderExport(path, normalizeFn)
	local folders, presets = GSListPresetFolder(path)
	local out = {name = GSGetPresetLeafName(path), presets = {}, folders = {}}

	for i = 1, #presets do
		local tbl = GSReadPresetFile(presets[i].path)

		if tbl then
			out.presets[#out.presets + 1] = GSBuildPresetPayload(tbl.name, tbl.data, normalizeFn)
		end
	end

	for i = 1, #folders do
		out.folders[#out.folders + 1] = GSBuildFolderExport(folders[i].path, normalizeFn)
	end

	return out
end

function GSExportPresetFolderShared(path, normalizeFn)
	return path and file.Exists(path, "DATA") and util.TableToJSON(GSBuildFolderExport(path, normalizeFn), true) or nil
end

local function GSImportPresetNode(parentFolder, entry, normalizeFn)
	if !istable(entry) then return nil end

	if entry.data != nil or (!entry.presets and !entry.folders) then
		return select(2, GSWritePresetFile(parentFolder, entry.name or "Imported Preset", entry.data or {}, normalizeFn))
	end

	local _, folderPath = GSCreatePresetFolder(parentFolder, entry.name or "Imported Folder")
	local presets = entry.presets or {}
	local folders = entry.folders or {}

	for i = 1, #presets do
		GSImportPresetNode(folderPath, presets[i], normalizeFn)
	end

	for i = 1, #folders do
		GSImportPresetNode(folderPath, folders[i], normalizeFn)
	end

	return folderPath
end

function GSImportPresetShared(folder, json, normalizeFn)
	local tbl = util.JSONToTable(json or "")
	if !istable(tbl) then return false, "Invalid preset JSON." end

	GSEnsurePresetDir(folder)

	local isPreset = tbl.data != nil or (!tbl.presets and !tbl.folders)
	local path = GSImportPresetNode(folder, isPreset and {name = tbl.name, data = tbl.data != nil and tbl.data or tbl} or tbl, normalizeFn)

	return path and true or false, path, isPreset and "preset" or "folder"
end

local function GSMovePresetPath(path, targetFolder)
	if !path or !targetFolder or !file.Exists(path, "DATA") or !file.Exists(targetFolder, "DATA") or path == targetFolder or GSGetPresetParentFolder(path) == targetFolder then return false end
	if path:sub(-5) != ".json" and targetFolder:sub(1, #path + 1) == path .. "/" then return false end

	local function CopyPath(src, dstFolder)
		local leaf = GSGetPresetLeafName(src)
		if leaf == "" then return false end

		if src:sub(-5) == ".json" then
			local raw = file.Read(src, "DATA")
			if raw == nil then return false end

			local newPath = select(1, GSGetUniquePresetPath(dstFolder, leaf, false))
			file.Write(newPath, raw)

			return file.Exists(newPath, "DATA"), newPath, "preset"
		end

		local ok, newPath = GSCreatePresetFolder(dstFolder, leaf)
		if !ok or !newPath then return false end

		local folders, presets = GSListPresetFolder(src)

		for i = 1, #folders do
			if !select(1, CopyPath(folders[i].path, newPath)) then
				GSDeletePresetPath(newPath)
				return false
			end
		end

		for i = 1, #presets do
			if !select(1, CopyPath(presets[i].path, newPath)) then
				GSDeletePresetPath(newPath)
				return false
			end
		end

		return true, newPath, "folder"
	end

	local ok, newPath, kind = CopyPath(path, targetFolder)
	if !ok or !newPath then return false end
	if !GSDeletePresetPath(path) then return false end

	return true, newPath, kind
end


function GSAddFilePresetControls(option, cfg)
	local state = {selectedType = "folder", selectedPath = nil, selectedName = nil, expandedFolders = {}}
	local browser
	local RefreshPresetList

	local rowSelectedColor = Color(90, 140, 190, 60)
	local rowHoverColor = Color(255, 255, 255, 14)
	local rowOutlineColor = Color(0, 0, 0, 40)
	local browserBackColor = Color(235, 243, 252)
	local topButtons = {}
	local cancelText = cfg.cancelText or "Cancel"

	local function GetRootFolder() return cfg.baseFolder != nil and GSResolvePresetFolder(cfg.baseFolder) or GSResolvePresetFolder(cfg.baseDir, cfg.presetDir, cfg.presetFile) end
	local function GetSelectedFolder() return state.selectedType == "preset" and GSGetPresetParentFolder(state.selectedPath) or (state.selectedPath or GetRootFolder()) end

	local function SetSelected(nodeType, path, name)
		state.selectedType = nodeType
		state.selectedPath = path
		state.selectedName = name
	end

	local function InvalidateBrowser()
		if !IsValid(browser) then return end

		local canvas = browser:GetCanvas()
		if IsValid(canvas) then canvas:InvalidateChildren(true) end
	end

	local function ClearSelected()
		SetSelected(nil, nil, nil)
		InvalidateBrowser()
	end

	local function GetDraggedInfo(panels)
		local pnl = istable(panels) and panels[1]
		return IsValid(pnl) and pnl.GSPresetInfo or nil
	end

	local function IsFolderExpanded(path)
		local expanded = state.expandedFolders[path]
		return expanded == nil and true or expanded
	end

	local function EnsureExpandedToPath(path, nodeType)
		local rootFolder = GetRootFolder()
		local folder = nodeType == "preset" and GSGetPresetParentFolder(path) or path

		while folder and folder != "" and folder != rootFolder do
			state.expandedFolders[folder] = true
			folder = GSGetPresetParentFolder(folder)
		end
	end

	local function LoadPreset(path)
		local presetPath = GSResolvePresetFilePath(path, GetRootFolder())
		if !presetPath then return end

		local tbl = GSReadPresetFile(presetPath)
		if !tbl then return end

		cfg.applyPreset(tbl.data or {})
		SetSelected("preset", presetPath, tbl.name)
		RefreshPresetList(presetPath, "preset")
	end

	local function RunStringRequest(title, text, value, onAccept) Derma_StringRequest(title, text, isfunction(value) and value() or (value or ""), onAccept) end

	local function RenameSelected()
		local rootFolder = GetRootFolder()
		local isPreset = state.selectedType == "preset" and state.selectedPath
		local isFolder = state.selectedType == "folder" and state.selectedPath and state.selectedPath != rootFolder

		if !isPreset and !isFolder then return end

		RunStringRequest(
			isPreset and (cfg.renamePresetDialogTitle or "Rename Preset") or (cfg.renameFolderDialogTitle or "Rename Folder"),
			isPreset and (cfg.renamePresetDialogText or "New Name:") or (cfg.renameFolderDialogText or "New Name:"),
			function() return state.selectedName or GSGetPresetLeafName(state.selectedPath) end,
			function(input)
				local ok, path, _, kind = GSRenamePresetPath(state.selectedPath, input, cfg.normalizePreset)
				if ok then RefreshPresetList(path, kind or state.selectedType) end
			end
		)
	end

	local function BuildPromptAction(title, text, value, onAccept, selectType)
		return function()
			RunStringRequest(title, text, value, function(input)
				local ok, path, kind = onAccept(input)
				if ok then RefreshPresetList(path, kind or selectType) end
			end)
		end
	end

	local function AddTopButton(parent, text, icon, tip, onClick)
		surface.SetFont("DermaDefaultBold")
		local textW = select(1, surface.GetTextSize(text))
		local contentW = 20 + textW

		local button = vgui.Create("DButton", parent)
		button:SetText("")
		button:SetTooltip(tip)
		button.DoClick = onClick
		button.ContentWidth = contentW

		local content = vgui.Create("DPanel", button)
		content:SetWide(contentW)
		content:SetTall(16)
		content.Paint = nil
		content:SetMouseInputEnabled(false)

		local image = vgui.Create("DImage", content)
		image:Dock(LEFT)
		image:SetWide(16)
		image:SetImage("icon16/" .. icon .. ".png")
		image:SetMouseInputEnabled(false)

		local label = vgui.Create("DLabel", content)
		label:Dock(FILL)
		label:DockMargin(4, 0, 0, 0)
		label:SetText(text)
		label:SetTextColor(Color(0, 0, 0))
		label:SetContentAlignment(4)
		label:SetMouseInputEnabled(false)

		button.PerformLayout = function(self, w, h)
			local cw = math.min(self.ContentWidth, math.max(w - 8, 0))
			content:SetWide(cw)
			content:SetPos(math.floor((w - cw) * 0.5), math.floor((h - 16) * 0.5))
		end

		topButtons[#topButtons + 1] = button

		return button
	end

	local rowSpecs = {
		folder = {
			nodeType = "folder",
			icon = "icon16/folder.png",
			textColor = Color(0, 0, 0),
			deleteTooltip = cfg.deleteFolderTooltip or "Delete this folder",
			queryText = cfg.deleteFolderQueryText or function(name) return "Delete folder '" .. name .. "' and everything inside it?" end,
			dialogTitle = cfg.deleteFolderDialogTitle or "Delete Folder",
			confirmText = cfg.deleteFolderConfirmText or "Delete",
			indent = 0,
			addLeftControls = function(row, info)
				local expanded = IsFolderExpanded(info.path)
				local button = vgui.Create("DImageButton", row)
				button:Dock(LEFT)
				button:SetWide(20)
				button:SetTall(20)
				button:DockMargin(2, 3, 2, 2)
				button:SetImage(expanded and "icon16/bullet_toggle_minus.png" or "icon16/bullet_toggle_plus.png")
				button:SetTooltip(expanded and (cfg.collapseFolderTooltip or "Collapse folder") or (cfg.expandFolderTooltip or "Expand folder"))
				button.DoClick = function()
					state.expandedFolders[info.path] = !expanded
					RefreshPresetList(info.path, "folder", true)
				end
			end,
		},
		preset = {
			nodeType = "preset",
			icon = "icon16/page_white.png",
			textColor = Color(75, 75, 75),
			deleteTooltip = cfg.deletePresetTooltip or "Delete this preset",
			queryText = cfg.deletePresetQueryText or function(name) return "Delete preset '" .. name .. "'?" end,
			dialogTitle = cfg.deletePresetDialogTitle or "Delete Preset",
			confirmText = cfg.deletePresetConfirmText or "Delete",
			indent = function(depth) return depth > 0 and 10 or 0 end,
		},
	}

	local function AddBrowserRow(parent, info, depth, spec)
		local row = vgui.Create("DPanel", parent)
		row:Dock(TOP)
		row:SetTall(20)
		row:DockMargin(depth * 14 + (isfunction(spec.indent) and spec.indent(depth, info) or spec.indent), 0, 0, 0)
		row:SetMouseInputEnabled(true)
		row:SetCursor("hand")
		row.GSPresetInfo = info
		row:Droppable("gstorms_preset_browser_item")
		row.Paint = function(self, w, h)
			if state.selectedType == spec.nodeType and state.selectedPath == info.path then
				surface.SetDrawColor(rowSelectedColor)
				surface.DrawRect(0, 0, w, h)
			elseif self:IsHovered() then
				surface.SetDrawColor(rowHoverColor)
				surface.DrawRect(0, 0, w, h)
			end

			surface.SetDrawColor(rowOutlineColor)
			surface.DrawOutlinedRect(0, 0, w, h, 1)
		end

		local oldOnMousePressed = row.OnMousePressed
		row.OnMousePressed = function(self, code)
			if code == MOUSE_LEFT then
				SetSelected(spec.nodeType, info.path, info.name)
				InvalidateBrowser()
			end

			if oldOnMousePressed then oldOnMousePressed(self, code) end
		end

		if spec.nodeType == "folder" then
			row:Receiver("gstorms_preset_browser_item", function(self, panels, dropped)
				if !dropped then return end

				local dragged = GetDraggedInfo(panels)
				if !dragged or dragged.path == info.path then return end

				local ok, newPath, kind = GSMovePresetPath(dragged.path, info.path)
				if ok then RefreshPresetList(newPath, kind) end
			end)
		end

		if spec.addLeftControls then spec.addLeftControls(row, info) end

		local icon = vgui.Create("DImage", row)
		icon:Dock(LEFT)
		icon:SetWide(16)
		icon:DockMargin(2, 2, 4, 2)
		icon:SetImage(spec.icon)
		icon:SetMouseInputEnabled(false)

		local deleteButton = vgui.Create("DImageButton", row)
		deleteButton:Dock(RIGHT)
		deleteButton:SetWide(12)
		deleteButton:SetTall(12)
		deleteButton:DockMargin(2, 4, 2, 4)
		deleteButton:SetImage("icon16/delete.png")
		deleteButton:SetTooltip(spec.deleteTooltip)
		deleteButton.DoClick = function()
			Derma_Query(isfunction(spec.queryText) and spec.queryText(info.name) or spec.queryText, spec.dialogTitle, spec.confirmText,
				function()
					local folder = GSGetPresetParentFolder(info.path)
					if GSDeletePresetPath(info.path) then RefreshPresetList(folder, "folder") end
				end,
				cancelText
			)
		end

		local label = vgui.Create("DLabel", row)
		label:Dock(FILL)
		label:SetText(info.name)
		label:SetTextColor(spec.textColor)
		label:SetContentAlignment(4)
		label:SetMouseInputEnabled(false)
	end

	local function AddFolderContents(parent, folderPath, depth)
		local folders, presets = GSListPresetFolder(folderPath)

		for i = 1, #folders do
			local info = folders[i]
			AddBrowserRow(parent, info, depth, rowSpecs.folder)

			if IsFolderExpanded(info.path) then
				AddFolderContents(parent, info.path, depth + 1)
			end
		end

		for i = 1, #presets do
			AddBrowserRow(parent, presets[i], depth, rowSpecs.preset)
		end
	end

	RefreshPresetList = function(selectPath, selectType, skipExpandToPath)
		local rootFolder = GetRootFolder()
		if !rootFolder or rootFolder == "" then return end

		GSEnsurePresetDir(rootFolder)

		local canvas = browser:GetCanvas()
		canvas:Clear()

		selectType = selectType or state.selectedType or "folder"
		selectPath = selectPath or state.selectedPath or rootFolder

		if selectType == "preset" then
			if !selectPath or !file.Exists(selectPath, "DATA") then
				selectType = "folder"
				selectPath = GSGetPresetParentFolder(selectPath) or rootFolder
			end
		elseif !selectPath or !file.Exists(selectPath, "DATA") then
			selectPath = rootFolder
		end

		if !skipExpandToPath then
			EnsureExpandedToPath(selectPath, selectType)
		end

		if selectType == "preset" then
			local tbl = GSReadPresetFile(selectPath)
			SetSelected("preset", selectPath, tbl and tbl.name or GSGetPresetLeafName(selectPath))
		else
			SetSelected("folder", selectPath, selectPath == rootFolder and "" or GSGetPresetLeafName(selectPath))
		end

		AddFolderContents(canvas, rootFolder, 0)
	end

	local wrapper = vgui.Create("DPanel", option)
	wrapper:Dock(TOP)
	wrapper:SetTall(cfg.treeHeight or 300)
	wrapper:DockMargin(0, 0, 0, 4)
	wrapper.Paint = nil
	option:AddItem(wrapper)

	local topBar = vgui.Create("DPanel", wrapper)
	topBar:Dock(TOP)
	topBar:SetTall(24)
	topBar.Paint = nil
	topBar.PerformLayout = function(self, w, h)
		local count = #topButtons
		if count == 0 then self:SetTall(0) return end

		local spacing = 4
		local buttonH = 24
		local minButtonW = 96
		local cols = math.max(1, math.min(count, math.floor((w + spacing) / (minButtonW + spacing))))
		local rows = math.ceil(count / cols)

		for row = 0, rows - 1 do
			local first = row * cols + 1
			local last = math.min(first + cols - 1, count)
			local rowCount = last - first + 1
			local rowW = w - spacing * (rowCount - 1)
			local buttonW = math.floor(rowW / rowCount)
			local extra = rowW - buttonW * rowCount
			local x = 0
			local y = row * (buttonH + spacing)

			for i = first, last do
				local thisW = buttonW

				if i == last then thisW = thisW + extra end

				local button = topButtons[i]
				button:SetPos(x, y)
				button:SetSize(thisW, buttonH)

				x = x + thisW + spacing
			end
		end

		self:SetTall(rows * buttonH + (rows - 1) * spacing)
	end

	local buttonSpecs = {
		{
			text = cfg.saveButtonText or "Save Preset",
			icon = "database_save",
			tip = cfg.saveTooltip or "Saves the current settings as a local preset",
			onClick = BuildPromptAction(
				cfg.saveDialogTitle or "Save Preset",
				cfg.saveDialogText or "Preset Name:",
				function() return state.selectedType == "preset" and (state.selectedName or "") or "" end,
				function(text) return GSSaveNamedPresetShared(cfg.baseDir, cfg.presetDir, cfg.presetFile, text, cfg.readPreset, cfg.normalizePreset, GetSelectedFolder()) end,
				"preset"
			),
		},
		{
			text = cfg.loadButtonText or "Load Preset",
			icon = "drive_disk",
			tip = cfg.loadTooltip or "Loads the selected preset",
			onClick = function()
				if state.selectedType == "preset" and state.selectedPath then LoadPreset(state.selectedPath) end
			end,
		},
		{
			text = cfg.newFolderButtonText or "New Folder",
			icon = "folder_add",
			tip = cfg.createFolderTooltip or "Create a folder in the selected location",
			onClick = BuildPromptAction(
				cfg.folderDialogTitle or "Create Folder",
				cfg.folderDialogText or "Folder Name:",
				"",
				function(text) return GSCreatePresetFolder(GetSelectedFolder(), text) end,
				"folder"
			),
		},
		{
			text = cfg.renameButtonText or "Rename",
			icon = "pencil",
			tip = cfg.renameTooltip or "Rename the selected preset or folder",
			onClick = RenameSelected,
		},
		{
			text = cfg.importButtonText or "Import",
			icon = "page_white_put",
			tip = cfg.importTooltip or "Import a preset or folder from JSON",
			onClick = BuildPromptAction(
				cfg.importDialogTitle or "Import Preset",
				cfg.importDialogText or "Paste Preset JSON:",
				"",
				function(text) return GSImportPresetShared(GetSelectedFolder(), text, cfg.normalizePreset) end
			),
		},
		{
			text = cfg.exportButtonText or "Export",
			icon = "page_white_get",
			tip = cfg.exportTooltip or "Copy the selected preset or folder as JSON",
			onClick = function()
				local json
				local rootFolder = GetRootFolder()

				if state.selectedType == "preset" then
					json = GSExportPresetShared(state.selectedPath, cfg.normalizePreset)
				elseif state.selectedType == "folder" and state.selectedPath and state.selectedPath != rootFolder then
					json = GSExportPresetFolderShared(state.selectedPath, cfg.normalizePreset)
				end

				if json then SetClipboardText(json) end
			end,
		},
	}

	for i = 1, #buttonSpecs do
		local spec = buttonSpecs[i]
		AddTopButton(topBar, spec.text, spec.icon, spec.tip, spec.onClick)
	end

	local browserWrap = vgui.Create("DPanel", wrapper)
	browserWrap:Dock(FILL)
	browserWrap:DockMargin(0, 4, 0, 0)
	browserWrap.Paint = function(self, w, h)
		surface.SetDrawColor(browserBackColor)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(0, 0, 0, 100)
		surface.DrawOutlinedRect(0, 0, w, h, 2)
	end

	browser = vgui.Create("DScrollPanel", browserWrap)
	browser:Dock(FILL)
	browser:DockMargin(1, 1, 1, 1)

	local function SetupRootTarget(pnl)
		local oldOnMousePressed = pnl.OnMousePressed

		pnl:SetMouseInputEnabled(true)
		pnl.OnMousePressed = function(self, code)
			if code == MOUSE_LEFT then ClearSelected() end
			if oldOnMousePressed then oldOnMousePressed(self, code) end
		end
		pnl:Receiver("gstorms_preset_browser_item", function(self, panels, dropped)
			if !dropped then return end

			local dragged = GetDraggedInfo(panels)
			local rootFolder = GetRootFolder()

			if !dragged or !rootFolder then return end

			local ok, newPath, kind = GSMovePresetPath(dragged.path, rootFolder)
			if ok then RefreshPresetList(newPath, kind) end
		end)
	end

	local canvas = browser:GetCanvas()
	canvas.Paint = function(self, w, h)
		surface.SetDrawColor(browserBackColor)
		surface.DrawRect(0, 0, w, h)
	end

	SetupRootTarget(browserWrap)
	SetupRootTarget(browser)
	SetupRootTarget(canvas)

	RefreshPresetList(GetRootFolder(), "folder")

	return browser, RefreshPresetList
end

local function GSPathExtrapolatePoint(a, b) return Vector(a.x + (a.x - b.x), a.y + (a.y - b.y), a.z + (a.z - b.z)) end

function GSCatmullRomPoint(p0, p1, p2, p3, t)
	local t2 = t * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (-p0 + p1 * 3 - p2 * 3 + p3) * (t2 * t)) * 0.5
end

local function GSPathBuildDefaultLinks(count, closed)
	local links = {}

	for i = 1, count do links[i] = {} end

	for i = 1, count - 1 do
		links[i][i + 1] = true
		links[i + 1][i] = true
	end

	if closed and count >= 3 then
		links[1][count] = true
		links[count][1] = true
	end

	return links
end

local function GSPathUpdateClosed(path, links, count)
	path.closed = count >= 3 and links[1] and links[1][count] and true or false
end

local function GSPathSetLink(path, a, b, enabled)
	if a == b then return false end

	local points = path.points or {}
	if !points[a] or !points[b] then return false end

	local links = GSPathEnsureLinks(path)
	local had = links[a] and links[a][b] and true or false

	if enabled then
		if had then return false end
		links[a][b] = true
		links[b][a] = true
	else
		if !had then return false end
		links[a][b] = nil
		links[b][a] = nil
	end

	GSPathUpdateClosed(path, links, #points)

	return true
end

function GSPathEnsureLinks(path)
	local points = path.points or {}
	local count = #points
	local links = path.links

	if !istable(links) then
		links = GSPathBuildDefaultLinks(count, path.closed)
		path.links = links
	else
		for i = 1, count do
			if !istable(links[i]) then links[i] = {} end
		end
	end

	GSPathUpdateClosed(path, links, count)

	return links
end

function GSPathHasLink(path, a, b)
	if a == b then return false end
	local links = GSPathEnsureLinks(path)
	return links[a] and links[a][b] or false
end

function GSPathAddLink(path, a, b) return GSPathSetLink(path, a, b, true) end

function GSPathCopyLinks(links, pointCount)
	local out = {}

	for i = 1, pointCount do
		local row = {}
		local src = links and links[i]

		if istable(src) then
			for other in pairs(src) do row[other] = true end
		end

		out[i] = row
	end

	return out
end

function GSPathLinksToTables(path)
	local links = GSPathEnsureLinks(path)
	local out = {}

	for i = 1, #path.points do
		local row = {}

		for other in pairs(links[i]) do row[#row + 1] = other end

		table.sort(row)
		out[i] = row
	end

	return out
end

function GSNormalizePathLinks(rawLinks, pointCount, closed)
	if !istable(rawLinks) then return GSPathBuildDefaultLinks(pointCount, closed) end

	local out = {}

	for i = 1, pointCount do out[i] = {} end

	for i = 1, pointCount do
		local row = rawLinks[i] or rawLinks[tostring(i)]

		if istable(row) then
			for key, value in pairs(row) do
				local other

				if isnumber(value) or (isstring(value) and tonumber(value)) then
					other = math.floor(tonumber(value) or 0)
				elseif value == true then
					other = math.floor(tonumber(key) or 0)
				end

				if other and other >= 1 and other <= pointCount and other != i then
					out[i][other] = true
					out[other][i] = true
				end
			end
		end
	end

	return out
end

function GSPathRemoveNode(path, nodeIndex)
	local points = path.points or {}
	local links = GSPathEnsureLinks(path)

	if nodeIndex < 1 or nodeIndex > #points then return false end

	table.remove(points, nodeIndex)
	table.remove(links, nodeIndex)

	for i = 1, #links do
		local newRow = {}

		for other in pairs(links[i]) do
			if other != nodeIndex then
				newRow[other > nodeIndex and other - 1 or other] = true
			end
		end

		links[i] = newRow
	end

	GSPathUpdateClosed(path, links, #points)

	return true
end

local function GSPathResolveCurveNeighbor(points, idx, otherIdx, neighborIdx) return neighborIdx and points[neighborIdx] or GSPathExtrapolatePoint(points[idx], points[otherIdx]) end

function GSBuildPathEdgeCurve(points, fromIndex, toIndex, prevIndex, nextIndex, steps)
	local p1 = points[fromIndex]
	local p2 = points[toIndex]
	if !p1 or !p2 then return {} end

	local p0 = GSPathResolveCurveNeighbor(points, fromIndex, toIndex, prevIndex)
	local p3 = GSPathResolveCurveNeighbor(points, toIndex, fromIndex, nextIndex)

	local out = {}

	for s = 0, steps - 1 do out[#out + 1] = GSCatmullRomPoint(p0, p1, p2, p3, s / steps) end

	out[#out + 1] = Vector(p2.x, p2.y, p2.z)

	return out
end

function GSPathDirectionAllowsNode(path, curNode, nextNode, directionMode)
	if directionMode == 0 then return true end

	local count = #(path.points or {})

	if directionMode == 1 then
		return nextNode > curNode or (path.closed and curNode == count and nextNode == 1)
	end

	return nextNode < curNode or (path.closed and curNode == 1 and nextNode == count)
end

function GSPathChooseNextNode(path, prevNode, curNode, incomingDir, directionMode)
	local links = GSPathEnsureLinks(path)
	local candidates = {}

	for nextNode in pairs(links[curNode] or {}) do
		if nextNode != prevNode and GSPathDirectionAllowsNode(path, curNode, nextNode, directionMode) then candidates[#candidates + 1] = nextNode end
	end

	if #candidates == 0 then return nil end

	return candidates[math.random(#candidates)]
end

function GSGetCurveNeighbor(path, nodeIndex, exclude, otherNodeIndex, preferForward)
	local links = GSPathEnsureLinks(path)[nodeIndex] or {}
	local node = path.points[nodeIndex]
	local other = path.points[otherNodeIndex]
	if !node or !other then return nil end

	local edgeX = other.x - node.x
	local edgeY = other.y - node.y
	local edgeLen = math.sqrt(edgeX * edgeX + edgeY * edgeY)
	if edgeLen <= 0 then return nil end

	local bestNode, bestScore = nil, nil

	for candidate in pairs(links) do
		if candidate != exclude then
			local p = path.points[candidate]
			if p then
				local dx = p.x - node.x
				local dy = p.y - node.y
				local len = math.sqrt(dx * dx + dy * dy)

				if len > 0 then
					local dot = (dx * edgeX + dy * edgeY) / (len * edgeLen)

					if preferForward then
						if !bestScore or dot > bestScore then
							bestScore = dot
							bestNode = candidate
						end
					else
						if !bestScore or dot < bestScore then
							bestScore = dot
							bestNode = candidate
						end
					end
				end
			end
		end
	end

	return bestNode
end