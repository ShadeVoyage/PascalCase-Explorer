--!strict

local TreeStore = require("../Core/TreeStore")
local RobloxSnapshot = require("./RobloxSnapshot")

type Store = typeof(TreeStore.new())

export type ChangeKind = "Added" | "Removed" | "Renamed" | "Moved"

export type Change = {
	Kind: ChangeKind,
	Id: number,
	Ids: { number }?,
	Object: Instance?,
	OldName: string?,
	NewName: string?,
	OldParentId: number?,
	NewParentId: number?,
}

export type ChangeListener = (change: Change) -> ()

local LiveHierarchy = {}
LiveHierarchy.__index = LiveHierarchy

type LiveHierarchyData = {
	Root: Instance,
	Tree: Store,
	RootId: number,
	InstanceToId: { [Instance]: number },
	IdToInstance: { [number]: Instance },
	_connections: { [Instance]: { RBXScriptConnection } },
	_rootConnections: { RBXScriptConnection },
	_listeners: { [number]: ChangeListener },
	_nextListenerId: number,
	_destroyed: boolean,
}

export type LiveHierarchy = typeof(setmetatable({} :: LiveHierarchyData, LiveHierarchy))

function LiveHierarchy._emit(self: LiveHierarchy, change: Change)
	for _, listener in pairs(self._listeners) do
		local success, message = pcall(listener, change)
		if not success then
			warn("PascalCase Explorer listener failed:", message)
		end
	end
end

function LiveHierarchy._disconnectObject(self: LiveHierarchy, object: Instance)
	local connections = self._connections[object]
	if connections == nil then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end

	self._connections[object] = nil
end

function LiveHierarchy._connectObject(self: LiveHierarchy, object: Instance)
	if self._destroyed or self._connections[object] ~= nil then
		return
	end

	local connections: { RBXScriptConnection } = {}
	self._connections[object] = connections

	table.insert(
		connections,
		object:GetPropertyChangedSignal("Name"):Connect(function()
			self:_reconcileObject(object)
		end)
	)

	if object ~= self.Root then
		table.insert(
			connections,
			object.AncestryChanged:Connect(function()
				self:_reconcileObject(object)
			end)
		)
	end
end

function LiveHierarchy._ensureTracked(self: LiveHierarchy, object: Instance): number?
	local existingId = self.InstanceToId[object]
	if existingId ~= nil then
		return existingId
	end

	if object == self.Root then
		return self.RootId
	end

	if not object:IsDescendantOf(self.Root) then
		return nil
	end

	local parent = object.Parent
	if parent == nil then
		return nil
	end

	local parentId = self:_ensureTracked(parent)
	if parentId == nil then
		return nil
	end

	local id = self.Tree:AddNode(object.Name, object.ClassName, parentId)
	self.InstanceToId[object] = id
	self.IdToInstance[id] = object
	self:_connectObject(object)

	self:_emit({
		Kind = "Added",
		Id = id,
		Object = object,
		NewParentId = parentId,
	})

	if not object:IsDescendantOf(self.Root) then
		self:_untrackSubtree(object)
		return nil
	end

	return id
end

function LiveHierarchy._untrackSubtree(self: LiveHierarchy, object: Instance)
	local id = self.InstanceToId[object]
	if id == nil or id == self.RootId then
		return
	end

	local removedIds = self.Tree:GetSubtreeIds(id)
	if #removedIds == 0 then
		return
	end

	for _, removedId in ipairs(removedIds) do
		local removedObject = self.IdToInstance[removedId]
		if removedObject ~= nil then
			self:_disconnectObject(removedObject)
			self.InstanceToId[removedObject] = nil
		end

		self.IdToInstance[removedId] = nil
	end

	self.Tree:RemoveNode(id)

	self:_emit({
		Kind = "Removed",
		Id = id,
		Ids = removedIds,
		Object = object,
	})
end

function LiveHierarchy._reconcileObject(self: LiveHierarchy, object: Instance)
	if self._destroyed then
		return
	end

	if object ~= self.Root and not object:IsDescendantOf(self.Root) then
		self:_untrackSubtree(object)
		return
	end

	local id = self:_ensureTracked(object)
	if id == nil then
		return
	end

	local node = self.Tree:GetNode(id)
	if node == nil then
		return
	end

	if node.Name ~= object.Name then
		local oldName = node.Name
		self.Tree:RenameNode(id, object.Name)

		self:_emit({
			Kind = "Renamed",
			Id = id,
			Object = object,
			OldName = oldName,
			NewName = object.Name,
		})
	end

	if object == self.Root then
		return
	end

	local parent = object.Parent
	if parent == nil then
		self:_untrackSubtree(object)
		return
	end

	local newParentId = self:_ensureTracked(parent)
	if newParentId == nil then
		self:_untrackSubtree(object)
		return
	end

	node = self.Tree:GetNode(id)
	if node ~= nil and node.ParentId ~= newParentId then
		local oldParentId = node.ParentId
		self.Tree:MoveNode(id, newParentId)

		self:_emit({
			Kind = "Moved",
			Id = id,
			Object = object,
			OldParentId = oldParentId,
			NewParentId = newParentId,
		})
	end
end

function LiveHierarchy._trackAddedObject(self: LiveHierarchy, object: Instance)
	local wasTracked = self.InstanceToId[object] ~= nil
	self:_reconcileObject(object)

	if wasTracked then
		return
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		self:_reconcileObject(descendant)
	end
end

function LiveHierarchy.Start(root: Instance): LiveHierarchy
	local snapshot = RobloxSnapshot.Capture(root)

	local self: LiveHierarchy = setmetatable({
		Root = root,
		Tree = snapshot.Tree,
		RootId = snapshot.RootId,
		InstanceToId = snapshot.InstanceToId,
		IdToInstance = snapshot.IdToInstance,
		_connections = {},
		_rootConnections = {},
		_listeners = {},
		_nextListenerId = 1,
		_destroyed = false,
	}, LiveHierarchy)

	table.insert(
		self._rootConnections,
		root.DescendantAdded:Connect(function(object)
			self:_trackAddedObject(object)
		end)
	)

	table.insert(
		self._rootConnections,
		root.DescendantRemoving:Connect(function(object)
			self:_reconcileObject(object)
		end)
	)

	local capturedObjects: { Instance } = {}
	for object in pairs(self.InstanceToId) do
		table.insert(capturedObjects, object)
	end

	for _, object in ipairs(capturedObjects) do
		if object == root or object:IsDescendantOf(root) then
			self:_connectObject(object)
		else
			self:_untrackSubtree(object)
		end
	end

	self:_reconcileObject(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		self:_reconcileObject(descendant)
	end

	return self
end

function LiveHierarchy.Subscribe(self: LiveHierarchy, listener: ChangeListener): () -> ()
	if self._destroyed then
		error("Cannot subscribe to a destroyed LiveHierarchy", 2)
	end

	local listenerId = self._nextListenerId
	self._nextListenerId += 1
	self._listeners[listenerId] = listener

	local disconnected = false
	return function()
		if disconnected then
			return
		end

		disconnected = true
		self._listeners[listenerId] = nil
	end
end

function LiveHierarchy.GetId(self: LiveHierarchy, object: Instance): number?
	return self.InstanceToId[object]
end

function LiveHierarchy.GetInstance(self: LiveHierarchy, id: number): Instance?
	return self.IdToInstance[id]
end

function LiveHierarchy.IsRunning(self: LiveHierarchy): boolean
	return not self._destroyed
end

function LiveHierarchy.Destroy(self: LiveHierarchy)
	if self._destroyed then
		return
	end

	self._destroyed = true

	for _, connection in ipairs(self._rootConnections) do
		connection:Disconnect()
	end
	table.clear(self._rootConnections)

	local connectedObjects: { Instance } = {}
	for object in pairs(self._connections) do
		table.insert(connectedObjects, object)
	end

	for _, object in ipairs(connectedObjects) do
		self:_disconnectObject(object)
	end

	table.clear(self._listeners)
	table.clear(self.InstanceToId)
	table.clear(self.IdToInstance)
	self.Tree:Clear()
end

return LiveHierarchy
