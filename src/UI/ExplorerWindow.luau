--!strict

local ROW_HEIGHT = 22
local ROW_POOL_SIZE = 48
local SEARCH_LIMIT = 500
local SEARCH_DELAY = 0.15

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
	Button: TextButton,
	NodeId: number?,
}

type WindowData = {
	Hierarchy: any,
	ScreenGui: ScreenGui,
	Main: Frame,
	TreeScroll: ScrollingFrame,
	SearchBox: TextBox,
	Properties: Frame,
	Status: TextLabel,
	Expanded: { [number]: boolean },
	VisibleRows: { VisibleRow },
	Rows: { RowView },
	SelectedId: number?,
	_connections: { RBXScriptConnection },
	_disconnectHierarchy: (() -> ())?,
	_rebuildQueued: boolean,
	_searchGeneration: number,
	_destroyed: boolean,
	_onClose: (() -> ())?,
}

export type Window = typeof(setmetatable({} :: WindowData, ExplorerWindow))

local function createLabel(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.Code
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

function ExplorerWindow._setPropertyRows(self: Window, values: { { string } })
	for _, child in ipairs(self.Properties:GetChildren()) do
		if child:GetAttribute("PascalCasePropertyRow") == true then
			child:Destroy()
		end
	end

	local y = 8
	for _, pair in ipairs(values) do
		local row = Instance.new("Frame")
		row.Name = "PropertyRow"
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, -16, 0, 24)
		row.Position = UDim2.fromOffset(8, y)
		row:SetAttribute("PascalCasePropertyRow", true)
		row.Parent = self.Properties

		local key = createLabel(row, pair[1], UDim2.new(0, 110, 1, 0), UDim2.fromOffset(0, 0))
		key.TextColor3 = Color3.fromRGB(150, 160, 174)

		local value = createLabel(
			row,
			pair[2],
			UDim2.new(1, -118, 1, 0),
			UDim2.fromOffset(118, 0)
		)
		value.TextWrapped = false
		value.TextTruncate = Enum.TextTruncate.AtEnd

		y += 26
	end
end

function ExplorerWindow._updateProperties(self: Window)
	local selectedId = self.SelectedId
	if selectedId == nil then
		self:_setPropertyRows({
			{ "Selection", "None" },
			{ "Hint", "Select an Instance from the tree." },
		})
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

	local parentName = "<root>"
	if node.ParentId ~= nil then
		local parentNode = self.Hierarchy.Tree:GetNode(node.ParentId)
		if parentNode ~= nil then
			parentName = parentNode.Name
		end
	end

	local fullName = node.Name
	local fullNameOk, result = pcall(function()
		return object:GetFullName()
	end)
	if fullNameOk then
		fullName = result
	end

	self:_setPropertyRows({
		{ "Name", node.Name },
		{ "ClassName", node.ClassName },
		{ "Parent", parentName },
		{ "Children", tostring(#node.Children) },
		{ "Node ID", tostring(node.Id) },
		{ "FullName", fullName },
	})
end

function ExplorerWindow._select(self: Window, id: number)
	self.SelectedId = id
	self.Hierarchy:RefreshId(id)
	self:_updateProperties()
	self:_renderRows()
end

function ExplorerWindow._toggle(self: Window, id: number)
	local node = self.Hierarchy.Tree:GetNode(id)
	if node == nil or #node.Children == 0 then
		return
	end

	self.Expanded[id] = not self.Expanded[id]
	self:_rebuildVisible()
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
		return string.lower(nodeA.Name) < string.lower(nodeB.Name)
	end)

	return rows
end

function ExplorerWindow._updateStatus(self: Window)
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
		else
			local node = self.Hierarchy.Tree:GetNode(rowData.Id)
			if node == nil then
				rowView.Frame.Visible = false
				rowView.NodeId = nil
			else
				rowView.Frame.Visible = true
				rowView.Frame.Position = UDim2.fromOffset(0, (visibleIndex - 1) * ROW_HEIGHT)
				rowView.Frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
				rowView.NodeId = rowData.Id

				local hasChildren = #node.Children > 0 and not rowData.SearchResult
				rowView.Toggle.Visible = hasChildren
				rowView.Toggle.Text = if self.Expanded[rowData.Id] then "▼" else "▶"
				rowView.Toggle.Position = UDim2.fromOffset(4 + rowData.Depth * 16, 1)

				local textOffset = 26 + rowData.Depth * 16
				if rowData.SearchResult then
					textOffset = 8
				end

				rowView.Button.Position = UDim2.fromOffset(textOffset, 1)
				rowView.Button.Size = UDim2.new(1, -textOffset - 4, 0, ROW_HEIGHT - 2)

				if rowData.SearchResult then
					rowView.Button.Text = string.format("%s  <%s>", node.Name, node.ClassName)
				else
					rowView.Button.Text = node.Name
				end

				if self.SelectedId == rowData.Id then
					rowView.Button.BackgroundColor3 = Color3.fromRGB(54, 82, 120)
					rowView.Button.BackgroundTransparency = 0
				else
					rowView.Button.BackgroundTransparency = 1
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
	task.defer(function()
		if self._destroyed then
			return
		end

		self._rebuildQueued = false
		self:_rebuildVisible()
	end)
end

function ExplorerWindow._createRows(self: Window)
	for _ = 1, ROW_POOL_SIZE do
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = self.TreeScroll

		local toggle = Instance.new("TextButton")
		toggle.Name = "Toggle"
		toggle.BackgroundTransparency = 1
		toggle.BorderSizePixel = 0
		toggle.Font = Enum.Font.Code
		toggle.Text = "▶"
		toggle.TextColor3 = Color3.fromRGB(175, 183, 195)
		toggle.TextSize = 12
		toggle.Size = UDim2.fromOffset(18, ROW_HEIGHT - 2)
		toggle.Parent = frame

		local button = Instance.new("TextButton")
		button.Name = "Node"
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Font = Enum.Font.Code
		button.TextColor3 = Color3.fromRGB(220, 224, 230)
		button.TextSize = 14
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.AutoButtonColor = false
		button.Parent = frame

		local rowView: RowView = {
			Frame = frame,
			Toggle = toggle,
			Button = button,
			NodeId = nil,
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
				if id ~= nil then
					self:_select(id)
				end
			end)
		)

		table.insert(self.Rows, rowView)
	end
end

function ExplorerWindow._enableDragging(self: Window, titleBar: Frame)
	local userInputService = game:GetService("UserInputService")
	local dragging = false
	local dragStart = Vector2.zero
	local startPosition = self.Main.Position

	table.insert(
		self._connections,
		titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPosition = self.Main.Position
			end
		end)
	)

	table.insert(
		self._connections,
		userInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
	)

	table.insert(
		self._connections,
		userInputService.InputChanged:Connect(function(input)
			if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			local delta = input.Position - dragStart
			self.Main.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
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
	screenGui.Parent = guiParent

	local main = Instance.new("Frame")
	main.Name = "Window"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.5)
	main.Size = UDim2.fromOffset(860, 560)
	main.BackgroundColor3 = Color3.fromRGB(27, 30, 36)
	main.BorderColor3 = Color3.fromRGB(72, 78, 88)
	main.BorderSizePixel = 1
	main.Parent = screenGui

	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Active = true
	titleBar.BackgroundColor3 = Color3.fromRGB(36, 40, 47)
	titleBar.BorderSizePixel = 0
	titleBar.Size = UDim2.new(1, 0, 0, 32)
	titleBar.Parent = main

	local version = if options ~= nil and options.Version ~= nil then options.Version else "dev"
	local title = createLabel(
		titleBar,
		"PascalCase Explorer  " .. version,
		UDim2.new(1, -44, 1, 0),
		UDim2.fromOffset(10, 0)
	)
	title.TextSize = 15

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.BackgroundTransparency = 1
	close.BorderSizePixel = 0
	close.Font = Enum.Font.Code
	close.Text = "×"
	close.TextColor3 = Color3.fromRGB(220, 224, 230)
	close.TextSize = 22
	close.Size = UDim2.fromOffset(36, 32)
	close.Position = UDim2.new(1, -36, 0, 0)
	close.Parent = titleBar

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "Search"
	searchBox.PlaceholderText = "Search name or class..."
	searchBox.ClearTextOnFocus = false
	searchBox.Font = Enum.Font.Code
	searchBox.Text = ""
	searchBox.TextColor3 = Color3.fromRGB(225, 228, 234)
	searchBox.PlaceholderColor3 = Color3.fromRGB(125, 133, 145)
	searchBox.TextSize = 14
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.BackgroundColor3 = Color3.fromRGB(21, 24, 29)
	searchBox.BorderColor3 = Color3.fromRGB(66, 72, 82)
	searchBox.Size = UDim2.new(0.58, -12, 0, 30)
	searchBox.Position = UDim2.fromOffset(8, 40)
	searchBox.Parent = main

	local treeScroll = Instance.new("ScrollingFrame")
	treeScroll.Name = "Tree"
	treeScroll.BackgroundColor3 = Color3.fromRGB(22, 25, 30)
	treeScroll.BorderColor3 = Color3.fromRGB(60, 66, 76)
	treeScroll.ScrollBarThickness = 8
	treeScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	treeScroll.CanvasSize = UDim2.fromOffset(0, 0)
	treeScroll.Size = UDim2.new(0.58, -12, 1, -112)
	treeScroll.Position = UDim2.fromOffset(8, 78)
	treeScroll.Parent = main

	local properties = Instance.new("Frame")
	properties.Name = "Properties"
	properties.BackgroundColor3 = Color3.fromRGB(22, 25, 30)
	properties.BorderColor3 = Color3.fromRGB(60, 66, 76)
	properties.Size = UDim2.new(0.42, -12, 1, -80)
	properties.Position = UDim2.new(0.58, 4, 0, 40)
	properties.Parent = main

	local propertyHeader = createLabel(
		properties,
		"Properties",
		UDim2.new(1, -16, 0, 26),
		UDim2.fromOffset(8, 0)
	)
	propertyHeader.Font = Enum.Font.Code
	propertyHeader.TextColor3 = Color3.fromRGB(235, 238, 243)
	propertyHeader:SetAttribute("PascalCasePropertyRow", false)

	local separator = Instance.new("Frame")
	separator.BackgroundColor3 = Color3.fromRGB(60, 66, 76)
	separator.BorderSizePixel = 0
	separator.Position = UDim2.fromOffset(8, 30)
	separator.Size = UDim2.new(1, -16, 0, 1)
	separator.Parent = properties

	local propertyContent = Instance.new("Frame")
	propertyContent.Name = "PropertyContent"
	propertyContent.BackgroundTransparency = 1
	propertyContent.BorderSizePixel = 0
	propertyContent.Position = UDim2.fromOffset(0, 34)
	propertyContent.Size = UDim2.new(1, 0, 1, -34)
	propertyContent.Parent = properties

	local status = createLabel(
		main,
		"Initializing...",
		UDim2.new(0.58, -12, 0, 24),
		UDim2.new(0, 8, 1, -28)
	)
	status.TextColor3 = Color3.fromRGB(145, 154, 168)
	status.TextSize = 12

	local self: Window = setmetatable({
		Hierarchy = hierarchy,
		ScreenGui = screenGui,
		Main = main,
		TreeScroll = treeScroll,
		SearchBox = searchBox,
		Properties = propertyContent,
		Status = status,
		Expanded = {
			[hierarchy.RootId] = true,
		},
		VisibleRows = {},
		Rows = {},
		SelectedId = nil,
		_connections = {},
		_disconnectHierarchy = nil,
		_rebuildQueued = false,
		_searchGeneration = 0,
		_destroyed = false,
		_onClose = if options ~= nil then options.OnClose else nil,
	}, ExplorerWindow)

	self:_createRows()
	self:_enableDragging(titleBar)

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

	self.ScreenGui:Destroy()
end

return ExplorerWindow
