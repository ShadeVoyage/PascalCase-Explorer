--!strict

local TreeStore = require("../src/Core/TreeStore")

local tree = TreeStore.new()

local gameId = tree:AddNode("Game", "DataModel", nil)
local workspaceId = tree:AddNode("Workspace", "Workspace", gameId)
local playersId = tree:AddNode("Players", "Players", gameId)
local modelId = tree:AddNode("TestModel", "Model", workspaceId)
local partId = tree:AddNode("Part", "Part", modelId)

assert(tree:GetCount() == 5)
assert(#tree:GetRoots() == 1)
assert(#tree:GetChildren(gameId) == 2)
assert(tree:GetNode(partId) ~= nil)

-- Returned nodes are snapshots; modifying one must not corrupt the store.
local workspaceSnapshot = tree:GetNode(workspaceId)
assert(workspaceSnapshot ~= nil)
workspaceSnapshot.Name = "ChangedOutsideStore"

local storedWorkspace = tree:GetNode(workspaceId)
assert(storedWorkspace ~= nil)
assert(storedWorkspace.Name == "Workspace")

tree:RenameNode(partId, "RenamedPart")
local renamedPart = tree:GetNode(partId)
assert(renamedPart ~= nil)
assert(renamedPart.Name == "RenamedPart")

tree:MoveNode(modelId, playersId)
local movedModel = tree:GetNode(modelId)
assert(movedModel ~= nil)
assert(movedModel.ParentId == playersId)
assert(#tree:GetChildren(workspaceId) == 0)
assert(#tree:GetChildren(playersId) == 1)

local cycleOk = pcall(function()
	tree:MoveNode(playersId, partId)
end)
assert(cycleOk == false)

local removed = tree:RemoveNode(modelId)
assert(#removed == 2)
assert(tree:GetNode(modelId) == nil)
assert(tree:GetNode(partId) == nil)
assert(tree:GetCount() == 3)

print("TreeStore test passed")
