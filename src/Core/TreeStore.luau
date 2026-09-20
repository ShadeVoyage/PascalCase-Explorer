--!strict

export type Node = {
	Id: number,
	Name: string,
	ClassName: string,
	ParentId: number?,
	Children: { number },
}

local TreeStore = {}
TreeStore.__index = TreeStore

type TreeStoreData = {
	_nextId: number,
	_nodes: { [number]: Node },
	_roots: { number },
	_count: number,
}

export type TreeStore = typeof(setmetatable({} :: TreeStoreData, TreeStore))

local function copyIds(values: { number }): { number }
	local result = table.create(#values)
	for index, value in ipairs(values) do
		result[index] = value
	end
	return result
end

local function copyNode(node: Node): Node
	return {
		Id = node.Id,
		Name = node.Name,
		ClassName = node.ClassName,
		ParentId = node.ParentId,
		Children = copyIds(node.Children),
	}
end

local function removeId(values: { number }, targetId: number): boolean
	for index, value in ipairs(values) do
		if value == targetId then
			table.remove(values, index)
			return true
		end
	end

	return false
end

function TreeStore.new(): TreeStore
	return setmetatable({
		_nextId = 1,
		_nodes = {},
		_roots = {},
		_count = 0,
	}, TreeStore)
end

function TreeStore.AddNode(
	self: TreeStore,
	name: string,
	className: string,
	parentId: number?
): number
	if parentId ~= nil and self._nodes[parentId] == nil then
		error(string.format("Parent node %d does not exist", parentId), 2)
	end

	local id = self._nextId
	self._nextId += 1

	local node: Node = {
		Id = id,
		Name = name,
		ClassName = className,
		ParentId = parentId,
		Children = {},
	}

	self._nodes[id] = node
	self._count += 1

	if parentId == nil then
		table.insert(self._roots, id)
	else
		local parent = self._nodes[parentId]
		assert(parent ~= nil)
		table.insert(parent.Children, id)
	end

	return id
end

function TreeStore.GetNode(self: TreeStore, id: number): Node?
	local node = self._nodes[id]
	if node == nil then
		return nil
	end

	return copyNode(node)
end

function TreeStore.GetRoots(self: TreeStore): { Node }
	local result = table.create(#self._roots)
	for index, id in ipairs(self._roots) do
		local node = self._nodes[id]
		assert(node ~= nil)
		result[index] = copyNode(node)
	end
	return result
end

function TreeStore.GetChildren(self: TreeStore, id: number): { Node }
	local node = self._nodes[id]
	if node == nil then
		error(string.format("Node %d does not exist", id), 2)
	end

	local result = table.create(#node.Children)
	for index, childId in ipairs(node.Children) do
		local child = self._nodes[childId]
		assert(child ~= nil)
		result[index] = copyNode(child)
	end
	return result
end

function TreeStore.GetSubtreeIds(self: TreeStore, id: number): { number }
	if self._nodes[id] == nil then
		return {}
	end

	local result = { id }
	local cursor = 1

	while cursor <= #result do
		local node = self._nodes[result[cursor]]
		if node ~= nil then
			for _, childId in ipairs(node.Children) do
				table.insert(result, childId)
			end
		end
		cursor += 1
	end

	return result
end

function TreeStore.RenameNode(self: TreeStore, id: number, newName: string)
	local node = self._nodes[id]
	if node == nil then
		error(string.format("Node %d does not exist", id), 2)
	end

	node.Name = newName
end

function TreeStore.MoveNode(self: TreeStore, id: number, newParentId: number?)
	local node = self._nodes[id]
	if node == nil then
		error(string.format("Node %d does not exist", id), 2)
	end

	if newParentId ~= nil then
		if self._nodes[newParentId] == nil then
			error(string.format("Parent node %d does not exist", newParentId), 2)
		end

		local ancestorId: number? = newParentId
		while ancestorId ~= nil do
			if ancestorId == id then
				error("Cannot move a node under itself or one of its descendants", 2)
			end

			local ancestor = self._nodes[ancestorId]
			if ancestor == nil then
				break
			end
			ancestorId = ancestor.ParentId
		end
	end

	if node.ParentId == newParentId then
		return
	end

	if node.ParentId == nil then
		removeId(self._roots, id)
	else
		local oldParent = self._nodes[node.ParentId]
		if oldParent ~= nil then
			removeId(oldParent.Children, id)
		end
	end

	node.ParentId = newParentId

	if newParentId == nil then
		table.insert(self._roots, id)
	else
		local newParent = self._nodes[newParentId]
		assert(newParent ~= nil)
		table.insert(newParent.Children, id)
	end
end

function TreeStore.RemoveNode(self: TreeStore, id: number): { number }
	local node = self._nodes[id]
	if node == nil then
		return {}
	end

	if node.ParentId == nil then
		removeId(self._roots, id)
	else
		local parent = self._nodes[node.ParentId]
		if parent ~= nil then
			removeId(parent.Children, id)
		end
	end

	local removedIds = self:GetSubtreeIds(id)
	for _, removedId in ipairs(removedIds) do
		self._nodes[removedId] = nil
	end

	self._count -= #removedIds
	return removedIds
end

function TreeStore.GetCount(self: TreeStore): number
	return self._count
end

function TreeStore.Clear(self: TreeStore)
	self._nextId = 1
	table.clear(self._nodes)
	table.clear(self._roots)
	self._count = 0
end

return TreeStore
