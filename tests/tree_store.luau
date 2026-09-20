--!strict

local TreeStore = require("../src/Core/TreeStore")

local tree = TreeStore.new()

local gameId = tree:AddNode("Game", "DataModel", nil)
local workspaceId = tree:AddNode("Workspace", "Workspace", gameId)
local playersId = tree:AddNode("Players", "Players", gameId)
local modelId = tree:AddNode("TestModel", "Model", workspaceId)
local partId = tree:AddNode("Part", "Part", modelId)

assert(tree:GetCount() == 5, "Expected five nodes after setup")
assert(#tree:GetRoots() == 1, "Expected exactly one root node")
assert(#tree:GetChildren(gameId) == 2, "Game should have two direct children")
assert(tree:GetNode(partId) ~= nil, "Part node should exist")

-- Returned nodes are snapshots; modifying one must not corrupt the store.
local workspaceSnapshot = tree:GetNode(workspaceId)
assert(workspaceSnapshot ~= nil, "Workspace snapshot should exist")
workspaceSnapshot.Name = "ChangedOutsideStore"

local storedWorkspace = tree:GetNode(workspaceId)
assert(storedWorkspace ~= nil, "Stored Workspace node should exist")
assert(storedWorkspace.Name == "Workspace", "External mutation must not change stored node")

tree:RenameNode(partId, "RenamedPart")
local renamedPart = tree:GetNode(partId)
assert(renamedPart ~= nil, "Renamed part should still exist")
assert(renamedPart.Name == "RenamedPart", "RenameNode should update the stored name")

tree:MoveNode(modelId, playersId)
local movedModel = tree:GetNode(modelId)
assert(movedModel ~= nil, "Moved model should still exist")
assert(movedModel.ParentId == playersId, "Model should move under Players")
assert(#tree:GetChildren(workspaceId) == 0, "Workspace should no longer contain the model")
assert(#tree:GetChildren(playersId) == 1, "Players should contain the moved model")

local cycleOk = pcall(function()
	tree:MoveNode(playersId, partId)
end)
assert(cycleOk == false, "Moving a node below its descendant must fail")

local removed = tree:RemoveNode(modelId)
assert(#removed == 2, "Removing the model should remove its child part too")
assert(tree:GetNode(modelId) == nil, "Removed model should no longer exist")
assert(tree:GetNode(partId) == nil, "Removed descendant should no longer exist")
assert(tree:GetCount() == 3, "Three nodes should remain after subtree removal")

print("TreeStore test passed")
