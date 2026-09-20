--!strict

local TreeStore = require("../Core/TreeStore")
local RobloxSnapshot = require("./RobloxSnapshot")

type Store = typeof(TreeStore.new())

local DEFAULT_RECONCILE_BATCH_SIZE = 512

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

export type Options = {
	ReconcileBatchSize: number?,
}

export type Stats = {
	TrackedInstances: number,
	ConnectionCount: number,
	PerInstanceConnections: number,
	ReconcileBatchSize: number,
	ScanQueueSize: number,
	ScanCursor: number,
	CompletedPasses: number,
	LastPassSeconds: number?,
}

local LiveHierarchy = {}
LiveHierarchy.__index = LiveHierarchy

type LiveHierarchyData = {
	Root: Instance,
	Tree: Store,
	RootId: number,
	InstanceToId: { [Instance]: number },
	IdToInstance: { [number]: Instance },
	_connections: { RBXScriptConnection },
	_listeners: { [number]: ChangeListener },
	_nextListenerId: number,
	_destroyed: boolean,
	_scanIds: { number },
	_scanCursor: number,
	_reconcileBatchSize: number,
	_completedPasses: number,
	_lastPassSeconds: number?,
	_passStartedAt: number,
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
	table.insert(self._scanIds, id)

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

function LiveHierarchy._finishScanPass(self: LiveHierarchy)
	self._lastPassSeconds = os.clock() - self._passStartedAt
	self._completedPasses += 1

	local writeIndex = 1
	for readIndex = 1, #self._scanIds do
		local id = self._scanIds[readIndex]
		if self.IdToInstance[id] ~= nil then
			self._scanIds[writeIndex] = id
			writeIndex += 1
		end
	end

	for index = #self._scanIds, writeIndex, -1 do
		table.remove(self._scanIds, index)
	end

	self._scanCursor = 1
	self._passStartedAt = os.clock()
end

function LiveHierarchy._scanStep(self: LiveHierarchy)
	if self._destroyed then
		return
	end

	local processed = 0
	while processed < self._reconcileBatchSize and self._scanCursor <= #self._scanIds do
		local id = self._scanIds[self._scanCursor]
		self._scanCursor += 1
		processed += 1

		local object = self.IdToInstance[id]
		if object ~= nil then
			self:_reconcileObject(object)
		end
	end

	if self._scanCursor > #self._scanIds then
		self:_finishScanPass()
	end
end

function LiveHierarchy.Start(root: Instance, options: Options?): LiveHierarchy
	local snapshot = RobloxSnapshot.Capture(root)
	local batchSize = DEFAULT_RECONCILE_BATCH_SIZE

	if options ~= nil and options.ReconcileBatchSize ~= nil then
		batchSize = math.max(1, math.floor(options.ReconcileBatchSize))
	end

	local scanIds = table.create(snapshot.Tree:GetCount())
	for id = 1, snapshot.Tree:GetCount() do
		if snapshot.IdToInstance[id] ~= nil then
			table.insert(scanIds, id)
		end
	end

	local self: LiveHierarchy = setmetatable({
		Root = root,
		Tree = snapshot.Tree,
		RootId = snapshot.RootId,
		InstanceToId = snapshot.InstanceToId,
		IdToInstance = snapshot.IdToInstance,
		_connections = {},
		_listeners = {},
		_nextListenerId = 1,
		_destroyed = false,
		_scanIds = scanIds,
		_scanCursor = 1,
		_reconcileBatchSize = batchSize,
		_completedPasses = 0,
		_lastPassSeconds = nil,
		_passStartedAt = os.clock(),
	}, LiveHierarchy)

	table.insert(
		self._connections,
		root.DescendantAdded:Connect(function(object)
			self:_trackAddedObject(object)
		end)
	)

	table.insert(
		self._connections,
		root.DescendantRemoving:Connect(function(object)
			task.defer(function()
				if not self._destroyed then
					self:_reconcileObject(object)
				end
			end)
		end)
	)

	local runService = game:GetService("RunService")
	table.insert(
		self._connections,
		runService.Heartbeat:Connect(function()
			self:_scanStep()
		end)
	)

	self:_reconcileObject(root)

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

function LiveHierarchy.RefreshObject(self: LiveHierarchy, object: Instance)
	self:_reconcileObject(object)
end

function LiveHierarchy.RefreshId(self: LiveHierarchy, id: number)
	local object = self.IdToInstance[id]
	if object ~= nil then
		self:_reconcileObject(object)
	end
end

function LiveHierarchy.GetStats(self: LiveHierarchy): Stats
	return {
		TrackedInstances = self.Tree:GetCount(),
		ConnectionCount = #self._connections,
		PerInstanceConnections = 0,
		ReconcileBatchSize = self._reconcileBatchSize,
		ScanQueueSize = #self._scanIds,
		ScanCursor = self._scanCursor,
		CompletedPasses = self._completedPasses,
		LastPassSeconds = self._lastPassSeconds,
	}
end

function LiveHierarchy.IsRunning(self: LiveHierarchy): boolean
	return not self._destroyed
end

function LiveHierarchy.Destroy(self: LiveHierarchy)
	if self._destroyed then
		return
	end

	self._destroyed = true

	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)

	table.clear(self._listeners)
	table.clear(self.InstanceToId)
	table.clear(self.IdToInstance)
	table.clear(self._scanIds)
	self.Tree:Clear()
end

return LiveHierarchy
