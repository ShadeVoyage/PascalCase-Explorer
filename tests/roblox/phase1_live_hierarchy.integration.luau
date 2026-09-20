--!strict

return function(PascalCaseExplorer: any)
	assert(type(PascalCaseExplorer) == "table", "Expected PascalCase Explorer module")
	assert(
		type(PascalCaseExplorer.LiveHierarchy) == "table",
		"PascalCase Explorer must expose LiveHierarchy"
	)

	local root = Instance.new("Folder")
	root.Name = "__PascalCasePhase1Integration"
	root.Parent = workspace

	local hierarchy = PascalCaseExplorer.LiveHierarchy.Start(root)
	local seenKinds: { [string]: boolean } = {}

	local disconnect = hierarchy:Subscribe(function(change: any)
		seenKinds[change.Kind] = true
	end)

	local function settle()
		task.wait()
		task.wait()
	end

	local success, failure = pcall(function()
		assert(hierarchy.Tree:GetCount() == 1, "New hierarchy should initially contain only its root")

		local alpha = Instance.new("Folder")
		alpha.Name = "Alpha"
		alpha.Parent = root
		settle()

		local alphaId = hierarchy:GetId(alpha)
		assert(alphaId ~= nil, "Added Alpha folder was not tracked")

		local beta = Instance.new("Folder")
		beta.Name = "Beta"
		beta.Parent = root
		settle()

		local betaId = hierarchy:GetId(beta)
		assert(betaId ~= nil, "Added Beta folder was not tracked")

		local child = Instance.new("Part")
		child.Name = "ChildPart"
		child.Parent = alpha
		settle()

		local childId = hierarchy:GetId(child)
		assert(childId ~= nil, "Added child part was not tracked")

		alpha.Name = "AlphaRenamed"
		settle()

		local renamedNode = hierarchy.Tree:GetNode(alphaId)
		assert(renamedNode ~= nil, "Renamed Alpha node disappeared")
		assert(renamedNode.Name == "AlphaRenamed", "Rename was not mirrored into TreeStore")

		alpha.Parent = beta
		settle()

		local movedNode = hierarchy.Tree:GetNode(alphaId)
		assert(movedNode ~= nil, "Moved Alpha node disappeared")
		assert(movedNode.ParentId == betaId, "Re-parenting inside the root was not mirrored")

		alpha.Parent = nil
		settle()

		assert(hierarchy:GetId(alpha) == nil, "Unparented subtree root should leave the hierarchy")
		assert(hierarchy:GetId(child) == nil, "Unparented subtree child should leave the hierarchy")
		assert(hierarchy:GetId(beta) == betaId, "Unrelated Beta node should remain tracked")

		alpha.Parent = root
		settle()

		local readdedAlphaId = hierarchy:GetId(alpha)
		local readdedChildId = hierarchy:GetId(child)
		assert(readdedAlphaId ~= nil, "Re-added Alpha folder was not tracked")
		assert(readdedChildId ~= nil, "Re-added child part was not tracked")
		assert(readdedAlphaId ~= alphaId, "Re-entering the hierarchy should allocate a new node ID")
		assert(readdedChildId ~= childId, "Re-entering a subtree should allocate new descendant IDs")

		alpha:Destroy()
		settle()

		assert(hierarchy:GetId(alpha) == nil, "Destroyed Alpha folder remained tracked")
		assert(hierarchy:GetId(child) == nil, "Destroyed Alpha descendant remained tracked")
		assert(hierarchy.Tree:GetCount() == 2, "Only the test root and Beta should remain")

		beta:Destroy()
		settle()
		assert(hierarchy.Tree:GetCount() == 1, "Only the test root should remain after Beta is destroyed")
	end)

	disconnect()
	hierarchy:Destroy()
	root:Destroy()

	if not success then
		error("Phase 1 Roblox integration test failed: " .. tostring(failure), 0)
	end

	assert(seenKinds.Added == true, "Integration test did not observe an Added change")
	assert(seenKinds.Renamed == true, "Integration test did not observe a Renamed change")
	assert(seenKinds.Moved == true, "Integration test did not observe a Moved change")
	assert(seenKinds.Removed == true, "Integration test did not observe a Removed change")
	assert(hierarchy:IsRunning() == false, "Destroy should stop the live hierarchy")
	assert(hierarchy.Tree:GetCount() == 0, "Destroy should clear the mirrored tree")

	print("PascalCase Explorer Phase 1 Roblox integration test passed")
end
