--!strict

local TreeStore = require("../Core/TreeStore")

type Store = typeof(TreeStore.new())

export type Snapshot = {
	Tree: Store,
	RootId: number,
	InstanceToId: { [Instance]: number },
	IdToInstance: { [number]: Instance },
}

type PendingInstance = {
	Object: Instance,
	ParentId: number?,
}

local RobloxSnapshot = {}

function RobloxSnapshot.Capture(root: Instance): Snapshot
	local tree = TreeStore.new()
	local instanceToId: { [Instance]: number } = {}
	local idToInstance: { [number]: Instance } = {}
	local rootId = tree:AddNode(root.Name, root.ClassName, nil)

	instanceToId[root] = rootId
	idToInstance[rootId] = root

	local pending: { PendingInstance } = {}
	for _, child in ipairs(root:GetChildren()) do
		table.insert(pending, {
			Object = child,
			ParentId = rootId,
		})
	end

	local cursor = 1
	while cursor <= #pending do
		local item = pending[cursor]
		cursor += 1

		local object = item.Object
		local id = tree:AddNode(object.Name, object.ClassName, item.ParentId)
		instanceToId[object] = id
		idToInstance[id] = object

		for _, child in ipairs(object:GetChildren()) do
			table.insert(pending, {
				Object = child,
				ParentId = id,
			})
		end
	end

	return {
		Tree = tree,
		RootId = rootId,
		InstanceToId = instanceToId,
		IdToInstance = idToInstance,
	}
end

return RobloxSnapshot
