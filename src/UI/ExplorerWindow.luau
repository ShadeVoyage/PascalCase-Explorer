--!strict

local Clipboard = require("../Runtime/Clipboard")
local PropertyInspector = require("../Runtime/PropertyInspector")

local ROW_HEIGHT = 20
local ROW_POOL_SIZE = 72
local SEARCH_LIMIT = 500
local SEARCH_DELAY = 0.15
local REBUILD_DELAY = 0.03
local DOUBLE_CLICK_SECONDS = 0.32
local DEFAULT_DOCK_WIDTH = 340
local MIN_DOCK_WIDTH = 280
local MAX_DOCK_WIDTH = 620
local DEFAULT_PANE_SPLIT = 0.58
local MIN_PANE_HEIGHT = 130

local ExplorerWindow = {}
ExplorerWindow.__index = ExplorerWindow

export type Options = {
	Version: string?,
	OnClose: (() -> ())?,
}

type VisibleRow = {
	Id: number,
	Depth: number,
	SearchResult: boolean,
}

type RowView = {
	Frame: Frame,
	Toggle: TextButton,
	Icon: TextLabel,
	Button: TextButton,
	NodeId: number?,
	SearchResult: boolean,
	LastClickAt: number,
	Hovering: boolean,
}

type WindowData = {
	Hierarchy: any,
	ScreenGui: ScreenGui,
	Main: Frame,
	ExplorerPane: Frame,
	PropertiesPane: Frame,
	Divider: Frame,
	TreeScroll: ScrollingFrame,
	SearchBox: TextBox,
	Properties: ScrollingFrame,
	PropertySearchBox: TextBox,
	PropertyHeader: TextLabel,
	Status: TextLabel,
	ContextDismiss: TextButton,
	ContextMenu: Frame,
	ContextNodeId: number?,
	Expanded: { [number]: boolean },
	VisibleRows: { VisibleRow },
	Rows: { RowView },
	SelectedId: number?,
	_connections: { RBXScriptConnection },
	_propertyConnections: { RBXScriptConnection },
	_disconnectHierarchy: (() -> ())?,
	_rebuildQueued: boolean,
	_searchGeneration: number,
	_statusGeneration: number,
	_statusOverride: string?,
	_paneSplit: number,
	_destroyed: boolean,
	_onClose: (() -> ())?,
}

export type Window = typeof(setmetatable({} :: WindowData, ExplorerWindow))

local CLASS_ICONS: { [string]: string } = {
	Folder = "F",
	Model = "M",
	Part = "P",
	MeshPart = "P",
	UnionOperation = "P",
	LocalScript = "LS",
	Script = "SC",
	ModuleScript = "MS",
	RemoteEvent = "RE",
	RemoteFunction = "RF",
	BindableEvent = "BE",
	BindableFunction = "BF",
	Sound = "♪",
	Animation = "A",
	Camera = "C",
	Tool = "T",
	Humanoid = "H",
	ScreenGui = "UI",
	Frame = "UI",
	TextLabel = "UI",
	TextButton = "UI",
	ImageLabel = "UI",
	ImageButton = "UI",
}

local function createLabel(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.SourceSans
	label.Text = text
	label.TextColor3 = Color3.fromRGB(220, 224, 230)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

local function getGuiParent(): Instance
	local players = game:GetService("Players")
	local player = players.LocalPlayer
	if player == nil then
		error("PascalCase Explorer requires a LocalPlayer", 2)
	end

	return player:WaitForChild("PlayerGui")
end

local function makeLuaPath(object: Instance, root: Instance): string
	if object == root then
		return "game"
	end

	local names: { string } = {}
	local current: Instance? = object

	while current ~= nil and current ~= root do
		table.insert(names, current.Name)
		current = current.Parent
	end

	if current ~= root then
		return object:GetFullName()
	end

	local path = "game"
	for index = #names, 1, -1 do
		path ..= "[" .. string.format("%q", names[index]) .. "]"
	end

	return path
end

local function iconFor(className: string, isRoot: boolean, isService: boolean): (string, Color3)
	if isRoot then
		return "G", Color3.fromRGB(242, 190, 74)
	end

	if isService then
		return "S", Color3.fromRGB(92, 184, 232)
	end

	local icon = CLASS_ICONS[className] or "·"

	if className == "LocalScript" or className == "Script" or className == "ModuleScript" then
		return icon, Color3.fromRGB(236, 187, 85)
	elseif className == "RemoteEvent" or className == "RemoteFunction" then
		return icon, Color3.fromRGB(232, 112, 132)
	elseif className == "Folder" or className == "Model" then
		return icon, Color3.fromRGB(120, 180, 240)
	elseif className == "Part" or className == "MeshPart" or className == "UnionOperation" then
		return icon, Color3.fromRGB(133, 205, 145)
	elseif string.find(className, "Gui", 1, true) ~= nil then
		return icon, Color3.fromRGB(188, 142, 238)
	end

	return icon, Color3.fromRGB(160, 170, 184)
end

function ExplorerWindow._displayName(self: Window, id: number, name: string): string
	if id == self.Hierarchy.RootId then
		return "game"
	end
	return name
end

function ExplorerWindow._clearPropertyRows(self: Window)
	for _, connection in ipairs(self._propertyConnections) do
		connection:Disconnect()
	end
	table.clear(self._propertyConnections)

	for _, child in ipairs(self.Properties:GetChildren()) do
		if child:GetAttribute("PascalCasePropertyRow") == true then
			child:Destroy()
		end
	end
end

function ExplorerWindow._setPropertyRows(self: Window, entries: { any })
	self:_clearPropertyRows()

	local query = string.lower(string.gsub(self.PropertySearchBox.Text, "^%s*(.-)%s*$", "%1"))
	local y = 4
	local currentCategory: string? = nil
	local visibleCount = 0

	for _, entry in ipairs(entries) do
		local matches = query == ""
			or string.find(string.lower(entry.Name), query, 1, true) ~= nil
			or string.find(string.lower(entry.Category), query, 1, true) ~= nil
			or string.find(string.lower(entry.ValueText), query, 1, true) ~= nil

		if not matches then
			continue
		end

		if currentCategory ~= entry.Category then
			currentCategory = entry.Category

			local header = createLabel(
				self.Properties,
				entry.Category,
				UDim2.new(1, -12, 0, 22),
				UDim2.fromOffset(6, y)
			)
			header.Name = "Category"
			header.BackgroundColor3 = Color3.fromRGB(42, 45, 51)
			header.BackgroundTransparency = 0
			header.TextColor3 = Color3.fromRGB(214, 218, 224)
			header.TextSize = 12
			header:SetAttribute("PascalCasePropertyRow", true)
			y += 23
		end

		visibleCount += 1

		local row = Instance.new("Frame")
		row.Name = "PropertyRow"
		row.BackgroundColor3 = Color3.fromRGB(26, 29, 35)
		row.BackgroundTransparency = if visibleCount % 2 == 0 then 0.35 else 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, -12, 0, 27)
		row.Position = UDim2.fromOffset(6, y)
		row:SetAttribute("PascalCasePropertyRow", true)
		row.Parent = self.Properties

		local key =
			createLabel(row, entry.Name, UDim2.new(0.43, -8, 1, 0), UDim2.fromOffset(6, 0))
		key.TextColor3 = Color3.fromRGB(145, 156, 172)
		key.TextSize = 13

		if entry.Editable then
			local editor = Instance.new("TextBox")
			editor.Name = "Editor"
			editor.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
			editor.BorderColor3 = Color3.fromRGB(61, 68, 79)
			editor.ClearTextOnFocus = false
			editor.Font = Enum.Font.SourceSans
			editor.Text = entry.ValueText
			editor.TextColor3 = Color3.fromRGB(225, 229, 235)
			editor.TextSize = 13
			editor.TextXAlignment = Enum.TextXAlignment.Left
			editor.Position = UDim2.new(0.43, 0, 0, 2)
			editor.Size = UDim2.new(0.57, -6, 1, -4)
			editor.Parent = row

			local propertyName = entry.Name
			local originalText = entry.ValueText
			table.insert(
				self._propertyConnections,
				editor.FocusLost:Connect(function()
					if self._destroyed or editor.Text == originalText then
						return
					end

					local selectedId = self.SelectedId
					local object = if selectedId ~= nil
						then self.Hierarchy:GetInstance(selectedId)
						else nil
					if object == nil then
						return
					end

					local success, message =
						PropertyInspector.SetProperty(object, propertyName, editor.Text)
					if success then
						self.Hierarchy:RefreshObject(object)
						self:_showStatus("Updated " .. propertyName)
						self:_rebuildVisible()
					else
						editor.Text = originalText
						self:_showStatus(message or ("Could not update " .. propertyName))
					end
				end)
			)
		else
			local value = createLabel(
				row,
				entry.ValueText,
				UDim2.new(0.57, -6, 1, 0),
				UDim2.new(0.43, 0, 0, 0)
			)
			value.TextWrapped = false
			value.TextTruncate = Enum.TextTruncate.AtEnd
			value.TextSize = 13
			value.TextColor3 = Color3.fromRGB(190, 197, 208)
		end

		y += 28
	end

	if visibleCount == 0 then
		local empty = createLabel(
			self.Properties,
			"No matching properties",
			UDim2.new(1, -12, 0, 28),
			UDim2.fromOffset(6, 6)
		)
		empty.TextColor3 = Color3.fromRGB(130, 140, 154)
		empty.TextSize = 13
		empty:SetAttribute("PascalCasePropertyRow", true)
		y = 38
	end

	self.Properties.CanvasSize = UDim2.fromOffset(0, y + 6)
end

function ExplorerWindow._showStatus(self: Window, message: string)
	self._statusGeneration += 1
	local generation = self._statusGeneration
	self._statusOverride = message
	self:_updateStatus()

	task.delay(2, function()
		if self._destroyed or generation ~= self._statusGeneration then
			return
		end

		self._statusOverride = nil
		self:_updateStatus()
	end)
end

function ExplorerWindow._updateProperties(self: Window)
	local selectedId = self.SelectedId
	if selectedId == nil then
		self.PropertyHeader.Text = "Properties"
		self:_clearPropertyRows()

		local hint = createLabel(
			self.Properties,
			"Select an Instance from the tree.",
			UDim2.new(1, -12, 0, 28),
			UDim2.fromOffset(6, 6)
		)
		hint.TextColor3 = Color3.fromRGB(130, 140, 154)
		hint.TextSize = 13
		hint:SetAttribute("PascalCasePropertyRow", true)
		self.Properties.CanvasSize = UDim2.fromOffset(0, 40)
		return
	end

	self.Hierarchy:RefreshId(selectedId)

	local node = self.Hierarchy.Tree:GetNode(selectedId)
	local object = self.Hierarchy:GetInstance(selectedId)
	if node == nil or object == nil then
		self.SelectedId = nil
		self:_updateProperties()
		return
	end

	local displayName = self:_displayName(selectedId, node.Name)
	self.PropertyHeader.Text = "Properties — " .. displayName

	local entries = PropertyInspector.GetProperties(object)
	table.insert(entries, {
		Name = "Children",
		Category = "Explorer",
		Value = #node.Children,
		ValueText = tostring(#node.Children),
		ValueType = "number",
		Editable = false,
	})
	table.insert(entries, {
		Name = "Node ID",
		Category = "Explorer",
		Value = node.Id,
		ValueText = tostring(node.Id),
		ValueType = "number",
		Editable = false,
	})

	local fullName = node.Name
	local fullNameOk, fullNameResult = pcall(function()
		return object:GetFullName()
	end)
	if fullNameOk then
		fullName = fullNameResult
	end

	local luaPath = makeLuaPath(object, self.Hierarchy.Root)
	table.insert(entries, {
		Name = "FullName",
		Category = "Explorer",
		Value = fullName,
		ValueText = fullName,
		ValueType = "string",
		Editable = false,
	})
	table.insert(entries, {
		Name = "Lua Path",
		Category = "Explorer",
		Value = luaPath,
		ValueText = luaPath,
		ValueType = "string",
		Editable = false,
	})

	for attributeName, attributeValue in pairs(object:GetAttributes()) do
		table.insert(entries, {
			Name = "@" .. attributeName,
			Category = "Attributes",
			Value = attributeValue,
			ValueText = PropertyInspector.FormatValue(attributeValue),
			ValueType = typeof(attributeValue),
			Editable = false,
		})
	end

	self:_setPropertyRows(entries)
end

function ExplorerWindow._findVisibleIndex(self: Window, id: number): number?
	for index, row in ipairs(self.VisibleRows) do
		if row.Id == id then
			return index
		end
	end
	return nil
end

function ExplorerWindow._scrollToId(self: Window, id: number)
	local index = self:_findVisibleIndex(id)
	if index == nil then
		return
	end

	local rowTop = (index - 1) * ROW_HEIGHT
	local rowBottom = rowTop + ROW_HEIGHT
	local currentTop = self.TreeScroll.CanvasPosition.Y
	local currentBottom = currentTop + self.TreeScroll.AbsoluteSize.Y

	if rowTop < currentTop then
		self.TreeScroll.CanvasPosition = Vector2.new(0, rowTop)
	elseif rowBottom > currentBottom then
		self.TreeScroll.CanvasPosition =
			Vector2.new(0, math.max(0, rowBottom - self.TreeScroll.AbsoluteSize.Y))
	end
end

function ExplorerWindow._select(self: Window, id: number)
	self.SelectedId = id
	self.Hierarchy:RefreshId(id)
	self:_updateProperties()
	self:_renderRows()
	self:_scrollToId(id)
end

function ExplorerWindow._toggle(self: Window, id: number)
	local node = self.Hierarchy.Tree:GetNode(id)
	if node == nil or #node.Children == 0 then
		return
	end

	self.Expanded[id] = not self.Expanded[id]
	self:_rebuildVisible()
	self:_scrollToId(id)
end

function ExplorerWindow._expandAncestors(self: Window, id: number)
	local node = self.Hierarchy.Tree:GetNode(id)
	while node ~= nil and node.ParentId ~= nil do
		self.Expanded[node.ParentId] = true
		node = self.Hierarchy.Tree:GetNode(node.ParentId)
	end
end

function ExplorerWindow._revealInTree(self: Window, id: number)
	self:_expandAncestors(id)
	self.SearchBox.Text = ""
	self.SelectedId = id
	self:_rebuildVisible()
	self:_scrollToId(id)
	self:_updateProperties()
end

function ExplorerWindow._buildTreeRows(self: Window): { VisibleRow }
	local rows: { VisibleRow } = {}
	local roots = self.Hierarchy.Tree:GetRoots()
	local stack: { { number } } = {}

	for index = #roots, 1, -1 do
		table.insert(stack, { roots[index].Id, 0 })
	end

	while #stack > 0 do
		local item = table.remove(stack)
		local id = item[1]
		local depth = item[2]
		local node = self.Hierarchy.Tree:GetNode(id)

		if node ~= nil then
			table.insert(rows, {
				Id = id,
				Depth = depth,
				SearchResult = false,
			})

			if self.Expanded[id] then
				for childIndex = #node.Children, 1, -1 do
					table.insert(stack, { node.Children[childIndex], depth + 1 })
				end
			end
		end
	end

	return rows
end

function ExplorerWindow._buildSearchRows(self: Window, query: string): { VisibleRow }
	local rows: { VisibleRow } = {}
	local lowered = string.lower(query)

	for id, object in pairs(self.Hierarchy.IdToInstance) do
		if #rows >= SEARCH_LIMIT then
			break
		end

		local name = string.lower(object.Name)
		local className = string.lower(object.ClassName)
		if string.find(name, lowered, 1, true) or string.find(className, lowered, 1, true) then
			table.insert(rows, {
				Id = id,
				Depth = 0,
				SearchResult = true,
			})
		end
	end

	table.sort(rows, function(a, b)
		local nodeA = self.Hierarchy.Tree:GetNode(a.Id)
		local nodeB = self.Hierarchy.Tree:GetNode(b.Id)
		if nodeA == nil then
			return false
		end
		if nodeB == nil then
			return true
		end

		local aName = string.lower(self:_displayName(nodeA.Id, nodeA.Name))
		local bName = string.lower(self:_displayName(nodeB.Id, nodeB.Name))
		local aExact = aName == lowered
		local bExact = bName == lowered

		if aExact ~= bExact then
			return aExact
		end

		local aPrefix = string.sub(aName, 1, #lowered) == lowered
		local bPrefix = string.sub(bName, 1, #lowered) == lowered
		if aPrefix ~= bPrefix then
			return aPrefix
		end

		return aName < bName
	end)

	return rows
end

function ExplorerWindow._updateStatus(self: Window)
	if self._statusOverride ~= nil then
		self.Status.Text = self._statusOverride
		return
	end

	local stats = self.Hierarchy:GetStats()
	local searchSuffix = ""
	if self.SearchBox.Text ~= "" then
		searchSuffix = string.format(" | %d search results", #self.VisibleRows)
	end

	self.Status.Text = string.format(
		"%d tracked | %d global connections | %d per-instance%s",
		stats.TrackedInstances,
		stats.ConnectionCount,
		stats.PerInstanceConnections,
		searchSuffix
	)
end

function ExplorerWindow._renderRows(self: Window)
	if self._destroyed then
		return
	end

	local firstIndex = math.floor(self.TreeScroll.CanvasPosition.Y / ROW_HEIGHT) + 1

	for poolIndex, rowView in ipairs(self.Rows) do
		local visibleIndex = firstIndex + poolIndex - 1
		local rowData = self.VisibleRows[visibleIndex]

		if rowData == nil then
			rowView.Frame.Visible = false
			rowView.NodeId = nil
			rowView.SearchResult = false
		else
			local node = self.Hierarchy.Tree:GetNode(rowData.Id)
			if node == nil then
				rowView.Frame.Visible = false
				rowView.NodeId = nil
				rowView.SearchResult = false
			else
				rowView.Frame.Visible = true
				rowView.Frame.Position = UDim2.fromOffset(0, (visibleIndex - 1) * ROW_HEIGHT)
				rowView.Frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
				rowView.NodeId = rowData.Id
				rowView.SearchResult = rowData.SearchResult

				local hasChildren = #node.Children > 0 and not rowData.SearchResult
				rowView.Toggle.Visible = hasChildren
				rowView.Toggle.Text = if self.Expanded[rowData.Id] then "▼" else "▶"
				rowView.Toggle.Position = UDim2.fromOffset(4 + rowData.Depth * 16, 1)

				local iconX = 24 + rowData.Depth * 16
				if rowData.SearchResult then
					iconX = 7
				end

				local object = self.Hierarchy:GetInstance(rowData.Id)
				local isService = object ~= nil and object.Parent == self.Hierarchy.Root
				local icon, iconColor =
					iconFor(node.ClassName, rowData.Id == self.Hierarchy.RootId, isService)
				rowView.Icon.Position = UDim2.fromOffset(iconX, 1)
				rowView.Icon.Text = icon
				rowView.Icon.TextColor3 = iconColor

				local textOffset = iconX + 24
				rowView.Button.Position = UDim2.fromOffset(textOffset, 1)
				rowView.Button.Size = UDim2.new(1, -textOffset - 4, 0, ROW_HEIGHT - 2)

				local displayName = self:_displayName(rowData.Id, node.Name)
				if rowData.SearchResult then
					rowView.Button.Text = string.format("%s  <%s>", displayName, node.ClassName)
				else
					rowView.Button.Text = displayName
				end

				rowView.Button.BackgroundTransparency = 1
				if self.SelectedId == rowData.Id then
					rowView.Frame.BackgroundColor3 = Color3.fromRGB(0, 112, 180)
					rowView.Frame.BackgroundTransparency = 0
				elseif rowView.Hovering then
					rowView.Frame.BackgroundColor3 = Color3.fromRGB(49, 53, 60)
					rowView.Frame.BackgroundTransparency = 0
				else
					rowView.Frame.BackgroundTransparency = 1
				end
			end
		end
	end
end

function ExplorerWindow._rebuildVisible(self: Window)
	if self._destroyed then
		return
	end

	local query = string.gsub(self.SearchBox.Text, "^%s*(.-)%s*$", "%1")
	if query == "" then
		self.VisibleRows = self:_buildTreeRows()
	else
		self.VisibleRows = self:_buildSearchRows(query)
	end

	self.TreeScroll.CanvasSize = UDim2.fromOffset(0, #self.VisibleRows * ROW_HEIGHT)
	self:_updateStatus()
	self:_updateProperties()
	self:_renderRows()
end

function ExplorerWindow._scheduleRebuild(self: Window)
	if self._destroyed or self._rebuildQueued then
		return
	end

	self._rebuildQueued = true
	task.delay(REBUILD_DELAY, function()
		if self._destroyed then
			self._rebuildQueued = false
			return
		end

		self:_rebuildVisible()
		self._rebuildQueued = false
	end)
end

function ExplorerWindow._hideContextMenu(self: Window)
	self.ContextMenu.Visible = false
	self.ContextDismiss.Visible = false
	self.ContextNodeId = nil
end

function ExplorerWindow._copyValue(self: Window, label: string, value: string)
	local success, message = Clipboard.Copy(value)
	self:_hideContextMenu()

	if success then
		self:_showStatus("Copied " .. label .. " to clipboard")
	else
		self:_showStatus(message or "Clipboard copy failed")
	end
end

function ExplorerWindow._openContextMenu(self: Window, id: number, position: Vector2)
	local node = self.Hierarchy.Tree:GetNode(id)
	local object = self.Hierarchy:GetInstance(id)
	if node == nil or object == nil then
		return
	end

	self:_select(id)
	self.ContextNodeId = id

	local camera = workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1920, 1080)
	local width = self.ContextMenu.Size.X.Offset
	local height = self.ContextMenu.Size.Y.Offset
	local x = math.clamp(position.X, 4, math.max(4, viewport.X - width - 4))
	local y = math.clamp(position.Y, 4, math.max(4, viewport.Y - height - 4))

	self.ContextMenu.Position = UDim2.fromOffset(x, y)
	self.ContextDismiss.Visible = true
	self.ContextMenu.Visible = true
end

function ExplorerWindow._createContextMenu(self: Window)
	local actions = {
		{
			Label = "Copy Name",
			Run = function(id: number)
				local node = self.Hierarchy.Tree:GetNode(id)
				if node ~= nil then
					self:_copyValue("Name", node.Name)
				end
			end,
		},
		{
			Label = "Copy Path",
			Run = function(id: number)
				local object = self.Hierarchy:GetInstance(id)
				if object ~= nil then
					self:_copyValue("Path", makeLuaPath(object, self.Hierarchy.Root))
				end
			end,
		},
		{
			Label = "Copy ClassName",
			Run = function(id: number)
				local node = self.Hierarchy.Tree:GetNode(id)
				if node ~= nil then
					self:_copyValue("ClassName", node.ClassName)
				end
			end,
		},
		{
			Label = "Reveal in Tree",
			Run = function(id: number)
				self:_hideContextMenu()
				self:_revealInTree(id)
			end,
		},
		{
			Label = "Refresh",
			Run = function(id: number)
				self:_hideContextMenu()
				self.Hierarchy:RefreshId(id)
				self:_rebuildVisible()
				self:_showStatus("Refreshed selected Instance")
			end,
		},
	}

	self.ContextMenu.Size = UDim2.fromOffset(168, #actions * 27 + 8)

	for index, action in ipairs(actions) do
		local button = Instance.new("TextButton")
		button.Name = "Action"
		button.AutoButtonColor = true
		button.BackgroundColor3 = Color3.fromRGB(45, 48, 54)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.SourceSans
		button.Text = "  " .. action.Label
		button.TextColor3 = Color3.fromRGB(224, 228, 234)
		button.TextSize = 13
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Position = UDim2.fromOffset(4, 4 + (index - 1) * 27)
		button.Size = UDim2.new(1, -8, 0, 25)
		button.ZIndex = 61
		button.Parent = self.ContextMenu

		table.insert(
			self._connections,
			button.MouseButton1Click:Connect(function()
				local id = self.ContextNodeId
				if id ~= nil then
					action.Run(id)
				end
			end)
		)
	end
end

function ExplorerWindow._createRows(self: Window)
	for _ = 1, ROW_POOL_SIZE do
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = Color3.fromRGB(49, 53, 60)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = self.TreeScroll

		local toggle = Instance.new("TextButton")
		toggle.Name = "Toggle"
		toggle.BackgroundTransparency = 1
		toggle.BorderSizePixel = 0
		toggle.Font = Enum.Font.SourceSans
		toggle.Text = "▶"
		toggle.TextColor3 = Color3.fromRGB(175, 183, 195)
		toggle.TextSize = 12
		toggle.Size = UDim2.fromOffset(18, ROW_HEIGHT - 2)
		toggle.Parent = frame

		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.BorderSizePixel = 0
		icon.Font = Enum.Font.SourceSans
		icon.Text = "·"
		icon.TextColor3 = Color3.fromRGB(160, 170, 184)
		icon.TextSize = 11
		icon.TextXAlignment = Enum.TextXAlignment.Center
		icon.Size = UDim2.fromOffset(22, ROW_HEIGHT - 2)
		icon.Parent = frame

		local button = Instance.new("TextButton")
		button.Name = "Node"
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Font = Enum.Font.SourceSans
		button.TextColor3 = Color3.fromRGB(220, 224, 230)
		button.TextSize = 14
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.AutoButtonColor = false
		button.Parent = frame

		local rowView: RowView = {
			Frame = frame,
			Toggle = toggle,
			Icon = icon,
			Button = button,
			NodeId = nil,
			SearchResult = false,
			LastClickAt = 0,
			Hovering = false,
		}

		table.insert(
			self._connections,
			toggle.MouseButton1Click:Connect(function()
				local id = rowView.NodeId
				if id ~= nil then
					self:_toggle(id)
				end
			end)
		)

		table.insert(
			self._connections,
			button.MouseButton1Click:Connect(function()
				local id = rowView.NodeId
				if id == nil then
					return
				end

				local now = os.clock()
				local doubleClick = now - rowView.LastClickAt <= DOUBLE_CLICK_SECONDS
				rowView.LastClickAt = now

				self:_select(id)

				if doubleClick then
					if rowView.SearchResult then
						self:_revealInTree(id)
					else
						self:_toggle(id)
					end
				end
			end)
		)

		table.insert(
			self._connections,
			button.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
					return
				end

				local id = rowView.NodeId
				if id ~= nil then
					self:_openContextMenu(id, Vector2.new(input.Position.X, input.Position.Y))
				end
			end)
		)

		table.insert(
			self._connections,
			button.MouseEnter:Connect(function()
				rowView.Hovering = true
				self:_renderRows()
			end)
		)

		table.insert(
			self._connections,
			button.MouseLeave:Connect(function()
				rowView.Hovering = false
				self:_renderRows()
			end)
		)

		table.insert(self.Rows, rowView)
	end
end

function ExplorerWindow._layoutPanes(self: Window)
	local height = self.Main.AbsoluteSize.Y
	if height <= 0 then
		return
	end

	local minSplit = math.clamp(MIN_PANE_HEIGHT / height, 0.18, 0.44)
	local maxSplit = 1 - minSplit
	self._paneSplit = math.clamp(self._paneSplit, minSplit, maxSplit)

	local dividerHeight = 5
	self.ExplorerPane.Position = UDim2.fromOffset(0, 0)
	self.ExplorerPane.Size = UDim2.new(1, 0, self._paneSplit, -math.ceil(dividerHeight / 2))
	self.Divider.Position =
		UDim2.new(0, 0, self._paneSplit, -math.floor(dividerHeight / 2))
	self.Divider.Size = UDim2.new(1, 0, 0, dividerHeight)
	self.PropertiesPane.Position =
		UDim2.new(0, 0, self._paneSplit, math.ceil(dividerHeight / 2))
	self.PropertiesPane.Size =
		UDim2.new(1, 0, 1 - self._paneSplit, -math.ceil(dividerHeight / 2))
end

function ExplorerWindow._enableDockWidthResize(self: Window, grip: GuiObject)
	local userInputService = game:GetService("UserInputService")
	local resizing = false
	local dragStartX = 0
	local startWidth = DEFAULT_DOCK_WIDTH

	table.insert(
		self._connections,
		grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true
				dragStartX = input.Position.X
				startWidth = self.Main.AbsoluteSize.X
			end
		end)
	)

	table.insert(
		self._connections,
		userInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = false
			end
		end)
	)

	table.insert(
		self._connections,
		userInputService.InputChanged:Connect(function(input)
			if not resizing or input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			local camera = workspace.CurrentCamera
			local viewportWidth = if camera ~= nil then camera.ViewportSize.X else 1920
			local maximum = math.max(
				MIN_DOCK_WIDTH,
				math.min(MAX_DOCK_WIDTH, viewportWidth - 120)
			)
			local width = math.clamp(
				startWidth + (dragStartX - input.Position.X),
				MIN_DOCK_WIDTH,
				maximum
			)

			self.Main.Size = UDim2.new(0, width, 1, 0)
			self:_layoutPanes()
			self:_renderRows()
		end)
	)
end

function ExplorerWindow._enablePaneSplitResize(self: Window, divider: GuiObject)
	local userInputService = game:GetService("UserInputService")
	local resizing = false
	local dragStartY = 0
	local startSplit = DEFAULT_PANE_SPLIT

	table.insert(
		self._connections,
		divider.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true
				dragStartY = input.Position.Y
				startSplit = self._paneSplit
			end
		end)
	)

	table.insert(
		self._connections,
		userInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = false
			end
		end)
	)

	table.insert(
		self._connections,
		userInputService.InputChanged:Connect(function(input)
			if not resizing or input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			local height = self.Main.AbsoluteSize.Y
			if height <= 0 then
				return
			end

			self._paneSplit = startSplit + (input.Position.Y - dragStartY) / height
			self:_layoutPanes()
			self:_renderRows()
		end)
	)
end

function ExplorerWindow.new(hierarchy: any, options: Options?): Window
	local guiParent = getGuiParent()
	local existing = guiParent:FindFirstChild("PascalCaseExplorerGui")
	if existing ~= nil then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PascalCaseExplorerGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 1000
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	hierarchy:IgnoreSubtree(screenGui)
	screenGui.Parent = guiParent

	local main = Instance.new("Frame")
	main.Name = "StudioDock"
	main.AnchorPoint = Vector2.new(1, 0)
	main.Position = UDim2.new(1, 0, 0, 0)
	main.Size = UDim2.new(0, DEFAULT_DOCK_WIDTH, 1, 0)
	main.BackgroundColor3 = Color3.fromRGB(31, 33, 38)
	main.BorderColor3 = Color3.fromRGB(64, 68, 76)
	main.BorderSizePixel = 1
	main.ClipsDescendants = true
	main.Parent = screenGui

	local widthGrip = Instance.new("TextButton")
	widthGrip.Name = "WidthGrip"
	widthGrip.Active = true
	widthGrip.AutoButtonColor = false
	widthGrip.BackgroundColor3 = Color3.fromRGB(72, 76, 84)
	widthGrip.BackgroundTransparency = 0.45
	widthGrip.BorderSizePixel = 0
	widthGrip.Text = ""
	widthGrip.Size = UDim2.new(0, 5, 1, 0)
	widthGrip.ZIndex = 20
	widthGrip.Parent = main

	local explorerPane = Instance.new("Frame")
	explorerPane.Name = "ExplorerPane"
	explorerPane.BackgroundColor3 = Color3.fromRGB(30, 32, 37)
	explorerPane.BorderSizePixel = 0
	explorerPane.Position = UDim2.fromOffset(0, 0)
	explorerPane.Size = UDim2.new(1, 0, DEFAULT_PANE_SPLIT, -3)
	explorerPane.ClipsDescendants = true
	explorerPane.Parent = main

	local explorerHeader = Instance.new("Frame")
	explorerHeader.Name = "Header"
	explorerHeader.BackgroundColor3 = Color3.fromRGB(37, 40, 46)
	explorerHeader.BorderSizePixel = 0
	explorerHeader.Size = UDim2.new(1, 0, 0, 25)
	explorerHeader.Parent = explorerPane

	local version = if options ~= nil and options.Version ~= nil then options.Version else "dev"
	local explorerTitle = createLabel(
		explorerHeader,
		"Explorer",
		UDim2.new(1, -94, 1, 0),
		UDim2.fromOffset(8, 0)
	)
	explorerTitle.TextSize = 14

	local versionLabel = createLabel(
		explorerHeader,
		version,
		UDim2.fromOffset(78, 25),
		UDim2.new(1, -170, 0, 0)
	)
	versionLabel.TextColor3 = Color3.fromRGB(132, 140, 151)
	versionLabel.TextSize = 11
	versionLabel.TextXAlignment = Enum.TextXAlignment.Right

	local refreshButton = Instance.new("TextButton")
	refreshButton.Name = "Refresh"
	refreshButton.AutoButtonColor = true
	refreshButton.BackgroundTransparency = 1
	refreshButton.BorderSizePixel = 0
	refreshButton.Font = Enum.Font.SourceSans
	refreshButton.Text = "↻"
	refreshButton.TextColor3 = Color3.fromRGB(205, 209, 216)
	refreshButton.TextSize = 17
	refreshButton.Position = UDim2.new(1, -76, 0, 0)
	refreshButton.Size = UDim2.fromOffset(25, 25)
	refreshButton.Parent = explorerHeader

	local collapseButton = Instance.new("TextButton")
	collapseButton.Name = "CollapseAll"
	collapseButton.AutoButtonColor = true
	collapseButton.BackgroundTransparency = 1
	collapseButton.BorderSizePixel = 0
	collapseButton.Font = Enum.Font.SourceSans
	collapseButton.Text = "−"
	collapseButton.TextColor3 = Color3.fromRGB(205, 209, 216)
	collapseButton.TextSize = 18
	collapseButton.Position = UDim2.new(1, -51, 0, 0)
	collapseButton.Size = UDim2.fromOffset(25, 25)
	collapseButton.Parent = explorerHeader

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AutoButtonColor = true
	close.BackgroundTransparency = 1
	close.BorderSizePixel = 0
	close.Font = Enum.Font.SourceSans
	close.Text = "×"
	close.TextColor3 = Color3.fromRGB(205, 209, 216)
	close.TextSize = 17
	close.Position = UDim2.new(1, -26, 0, 0)
	close.Size = UDim2.fromOffset(26, 25)
	close.Parent = explorerHeader

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "Search"
	searchBox.PlaceholderText = "Search"
	searchBox.ClearTextOnFocus = false
	searchBox.Font = Enum.Font.SourceSans
	searchBox.Text = ""
	searchBox.TextColor3 = Color3.fromRGB(226, 229, 234)
	searchBox.PlaceholderColor3 = Color3.fromRGB(137, 143, 153)
	searchBox.TextSize = 14
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.BackgroundColor3 = Color3.fromRGB(41, 44, 50)
	searchBox.BorderColor3 = Color3.fromRGB(64, 68, 76)
	searchBox.Position = UDim2.fromOffset(7, 31)
	searchBox.Size = UDim2.new(1, -14, 0, 26)
	searchBox.Parent = explorerPane

	local treeScroll = Instance.new("ScrollingFrame")
	treeScroll.Name = "Tree"
	treeScroll.BackgroundColor3 = Color3.fromRGB(30, 32, 37)
	treeScroll.BorderSizePixel = 0
	treeScroll.ScrollBarImageColor3 = Color3.fromRGB(104, 108, 117)
	treeScroll.ScrollBarThickness = 7
	treeScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	treeScroll.CanvasSize = UDim2.fromOffset(0, 0)
	treeScroll.Position = UDim2.fromOffset(4, 61)
	treeScroll.Size = UDim2.new(1, -8, 1, -82)
	treeScroll.Parent = explorerPane

	local status = createLabel(
		explorerPane,
		"Initializing...",
		UDim2.new(1, -12, 0, 19),
		UDim2.new(0, 7, 1, -20)
	)
	status.TextColor3 = Color3.fromRGB(128, 136, 148)
	status.TextSize = 11

	local divider = Instance.new("Frame")
	divider.Name = "PaneDivider"
	divider.Active = true
	divider.BackgroundColor3 = Color3.fromRGB(67, 71, 79)
	divider.BorderSizePixel = 0
	divider.Position = UDim2.new(0, 0, DEFAULT_PANE_SPLIT, -2)
	divider.Size = UDim2.new(1, 0, 0, 5)
	divider.ZIndex = 15
	divider.Parent = main

	local propertiesPane = Instance.new("Frame")
	propertiesPane.Name = "PropertiesPane"
	propertiesPane.BackgroundColor3 = Color3.fromRGB(30, 32, 37)
	propertiesPane.BorderSizePixel = 0
	propertiesPane.Position = UDim2.new(0, 0, DEFAULT_PANE_SPLIT, 3)
	propertiesPane.Size = UDim2.new(1, 0, 1 - DEFAULT_PANE_SPLIT, -3)
	propertiesPane.ClipsDescendants = true
	propertiesPane.Parent = main

	local propertiesHeader = Instance.new("Frame")
	propertiesHeader.Name = "Header"
	propertiesHeader.BackgroundColor3 = Color3.fromRGB(37, 40, 46)
	propertiesHeader.BorderSizePixel = 0
	propertiesHeader.Size = UDim2.new(1, 0, 0, 25)
	propertiesHeader.Parent = propertiesPane

	local propertyHeader = createLabel(
		propertiesHeader,
		"Properties",
		UDim2.new(1, -16, 1, 0),
		UDim2.fromOffset(8, 0)
	)
	propertyHeader.TextColor3 = Color3.fromRGB(226, 229, 234)
	propertyHeader.TextSize = 14

	local propertySearchBox = Instance.new("TextBox")
	propertySearchBox.Name = "PropertySearch"
	propertySearchBox.PlaceholderText = "Filter Properties"
	propertySearchBox.ClearTextOnFocus = false
	propertySearchBox.Font = Enum.Font.SourceSans
	propertySearchBox.Text = ""
	propertySearchBox.TextColor3 = Color3.fromRGB(225, 228, 234)
	propertySearchBox.PlaceholderColor3 = Color3.fromRGB(137, 143, 153)
	propertySearchBox.TextSize = 13
	propertySearchBox.TextXAlignment = Enum.TextXAlignment.Left
	propertySearchBox.BackgroundColor3 = Color3.fromRGB(41, 44, 50)
	propertySearchBox.BorderColor3 = Color3.fromRGB(64, 68, 76)
	propertySearchBox.Position = UDim2.fromOffset(7, 31)
	propertySearchBox.Size = UDim2.new(1, -14, 0, 26)
	propertySearchBox.Parent = propertiesPane

	local propertyContent = Instance.new("ScrollingFrame")
	propertyContent.Name = "PropertyContent"
	propertyContent.BackgroundColor3 = Color3.fromRGB(30, 32, 37)
	propertyContent.BorderSizePixel = 0
	propertyContent.ScrollBarImageColor3 = Color3.fromRGB(104, 108, 117)
	propertyContent.ScrollBarThickness = 7
	propertyContent.ScrollingDirection = Enum.ScrollingDirection.Y
	propertyContent.CanvasSize = UDim2.fromOffset(0, 0)
	propertyContent.Position = UDim2.fromOffset(0, 61)
	propertyContent.Size = UDim2.new(1, 0, 1, -61)
	propertyContent.Parent = propertiesPane

	local contextDismiss = Instance.new("TextButton")
	contextDismiss.Name = "ContextDismiss"
	contextDismiss.BackgroundTransparency = 1
	contextDismiss.BorderSizePixel = 0
	contextDismiss.Text = ""
	contextDismiss.AutoButtonColor = false
	contextDismiss.Visible = false
	contextDismiss.Size = UDim2.fromScale(1, 1)
	contextDismiss.ZIndex = 50
	contextDismiss.Parent = screenGui

	local contextMenu = Instance.new("Frame")
	contextMenu.Name = "ContextMenu"
	contextMenu.BackgroundColor3 = Color3.fromRGB(37, 40, 46)
	contextMenu.BorderColor3 = Color3.fromRGB(78, 83, 92)
	contextMenu.BorderSizePixel = 1
	contextMenu.Visible = false
	contextMenu.ZIndex = 60
	contextMenu.Parent = screenGui

	local self: Window = setmetatable({
		Hierarchy = hierarchy,
		ScreenGui = screenGui,
		Main = main,
		ExplorerPane = explorerPane,
		PropertiesPane = propertiesPane,
		Divider = divider,
		TreeScroll = treeScroll,
		SearchBox = searchBox,
		Properties = propertyContent,
		PropertySearchBox = propertySearchBox,
		PropertyHeader = propertyHeader,
		Status = status,
		ContextDismiss = contextDismiss,
		ContextMenu = contextMenu,
		ContextNodeId = nil,
		Expanded = {
			[hierarchy.RootId] = true,
		},
		VisibleRows = {},
		Rows = {},
		SelectedId = nil,
		_connections = {},
		_propertyConnections = {},
		_disconnectHierarchy = nil,
		_rebuildQueued = false,
		_searchGeneration = 0,
		_statusGeneration = 0,
		_statusOverride = nil,
		_paneSplit = DEFAULT_PANE_SPLIT,
		_destroyed = false,
		_onClose = if options ~= nil then options.OnClose else nil,
	}, ExplorerWindow)

	self:_createRows()
	self:_createContextMenu()
	self:_enableDockWidthResize(widthGrip)
	self:_enablePaneSplitResize(divider)
	self:_layoutPanes()

	table.insert(
		self._connections,
		main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_layoutPanes()
			self:_renderRows()
		end)
	)

	table.insert(
		self._connections,
		treeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			self:_renderRows()
		end)
	)

	table.insert(
		self._connections,
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			self._searchGeneration += 1
			local generation = self._searchGeneration

			task.delay(SEARCH_DELAY, function()
				if not self._destroyed and generation == self._searchGeneration then
					self.TreeScroll.CanvasPosition = Vector2.zero
					self:_rebuildVisible()
				end
			end)
		end)
	)

	table.insert(
		self._connections,
		searchBox.FocusLost:Connect(function(enterPressed)
			if enterPressed and self.SearchBox.Text ~= "" and #self.VisibleRows > 0 then
				self:_revealInTree(self.VisibleRows[1].Id)
			end
		end)
	)

	table.insert(
		self._connections,
		propertySearchBox:GetPropertyChangedSignal("Text"):Connect(function()
			self:_updateProperties()
		end)
	)

	table.insert(
		self._connections,
		refreshButton.MouseButton1Click:Connect(function()
			local id = self.SelectedId or self.Hierarchy.RootId
			self.Hierarchy:RefreshId(id)
			self:_rebuildVisible()
			self:_showStatus("Explorer refreshed")
		end)
	)

	table.insert(
		self._connections,
		collapseButton.MouseButton1Click:Connect(function()
			table.clear(self.Expanded)
			self.Expanded[self.Hierarchy.RootId] = true
			self.TreeScroll.CanvasPosition = Vector2.zero
			self:_rebuildVisible()
		end)
	)

	table.insert(
		self._connections,
		contextDismiss.MouseButton1Click:Connect(function()
			self:_hideContextMenu()
		end)
	)

	table.insert(
		self._connections,
		close.MouseButton1Click:Connect(function()
			local onClose = self._onClose
			if onClose ~= nil then
				onClose()
			else
				self:Destroy()
			end
		end)
	)

	self._disconnectHierarchy = hierarchy:Subscribe(function(change)
		if change.Kind == "Removed" and change.Ids ~= nil and self.SelectedId ~= nil then
			for _, removedId in ipairs(change.Ids) do
				if removedId == self.SelectedId then
					self.SelectedId = nil
					break
				end
			end
		end

		self:_scheduleRebuild()
	end)

	self:_rebuildVisible()

	return self
end

function ExplorerWindow.IsOpen(self: Window): boolean
	return not self._destroyed
end

function ExplorerWindow.Destroy(self: Window)
	if self._destroyed then
		return
	end

	self._destroyed = true

	if self._disconnectHierarchy ~= nil then
		self._disconnectHierarchy()
		self._disconnectHierarchy = nil
	end

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)

	for _, connection in ipairs(self._propertyConnections) do
		connection:Disconnect()
	end
	table.clear(self._propertyConnections)

	self.ScreenGui:Destroy()
end

return ExplorerWindow
