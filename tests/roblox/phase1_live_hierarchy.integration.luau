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

	local hierarchy = PascalCaseExplorer.LiveHierarchy.Start(root, {
		ReconcileBatchSize = 64,
	})
	local seenKinds: { [string]: boolean } = {}

	local disconnect = hierarchy:Subscribe(function(change: any)
		seenKinds[change.Kind] = true
	end)

	local function waitUntil(predicate: () -> boolean, message: string)
		local deadline = os.clock() + 2

		while not predicate() and os.clock() < deadline do
			task.wait()
		end

		assert(predicate(), message)
	end

	local success, failure = pcall(function()
		assert(
			hierarchy.Tree:GetCount() == 1,
			"New hierarchy should initially contain only its root"
		)

		local initialStats = hierarchy:GetStats()
		assert(initialStats.PerInstanceConnections == 0, "Per-Instance signals must stay disabled")
		assert(
			initialStats.ConnectionCount == 3,
			"LiveHierarchy should use only three global signals"
		)

		local ignored = Instance.new("Folder")
		ignored.Name = "IgnoredSubtree"
		hierarchy:IgnoreSubtree(ignored)
		ignored.Parent = root

		local ignoredChild = Instance.new("Part")
		ignoredChild.Name = "IgnoredChild"
		ignoredChild.Parent = ignored

		task.wait()
		task.wait()

		assert(hierarchy:GetId(ignored) == nil, "Ignored root must not be tracked")
		assert(hierarchy:GetId(ignoredChild) == nil, "Ignored descendants must not be tracked")
		assert(hierarchy.Tree:GetCount() == 1, "Ignored subtree must not change the tree count")

		ignored:Destroy()

		local alpha = Instance.new("Folder")
		alpha.Name = "Alpha"
		alpha.Parent = root
		waitUntil(function()
			return hierarchy:GetId(alpha) ~= nil
		end, "Added Alpha folder was not tracked")

		local alphaId = hierarchy:GetId(alpha)
		assert(alphaId ~= nil, "Alpha ID should exist after tracking")

		local beta = Instance.new("Folder")
		beta.Name = "Beta"
		beta.Parent = root
		waitUntil(function()
			return hierarchy:GetId(beta) ~= nil
		end, "Added Beta folder was not tracked")

		local betaId = hierarchy:GetId(beta)
		assert(betaId ~= nil, "Beta ID should exist after tracking")

		local child = Instance.new("Part")
		child.Name = "ChildPart"
		child.Parent = alpha
		waitUntil(function()
			return hierarchy:GetId(child) ~= nil
		end, "Added child part was not tracked")

		local childId = hierarchy:GetId(child)
		assert(childId ~= nil, "Child ID should exist after tracking")

		alpha.Name = "AlphaRenamed"
		waitUntil(function()
			local node = hierarchy.Tree:GetNode(alphaId)
			return node ~= nil and node.Name == "AlphaRenamed"
		end, "Rename was not mirrored into TreeStore")

		alpha.Parent = beta
		waitUntil(function()
			local node = hierarchy.Tree:GetNode(alphaId)
			return node ~= nil and node.ParentId == betaId
		end, "Re-parenting inside the root was not mirrored")

		alpha.Parent = nil
		waitUntil(function()
			return hierarchy:GetId(alpha) == nil and hierarchy:GetId(child) == nil
		end, "Unparented subtree should leave the hierarchy")

		assert(hierarchy:GetId(beta) == betaId, "Unrelated Beta node should remain tracked")

		alpha.Parent = root
		waitUntil(function()
			return hierarchy:GetId(alpha) ~= nil and hierarchy:GetId(child) ~= nil
		end, "Re-added subtree was not tracked")

		local readdedAlphaId = hierarchy:GetId(alpha)
		local readdedChildId = hierarchy:GetId(child)
		assert(readdedAlphaId ~= alphaId, "Re-entering the hierarchy should allocate a new node ID")
		assert(
			readdedChildId ~= childId,
			"Re-entering a subtree should allocate new descendant IDs"
		)

		alpha:Destroy()
		waitUntil(function()
			return hierarchy:GetId(alpha) == nil and hierarchy:GetId(child) == nil
		end, "Destroyed Alpha subtree remained tracked")

		assert(hierarchy.Tree:GetCount() == 2, "Only the test root and Beta should remain")

		beta:Destroy()
		waitUntil(function()
			return hierarchy.Tree:GetCount() == 1
		end, "Only the test root should remain after Beta is destroyed")

		waitUntil(function()
			return hierarchy:GetStats().CompletedPasses > 0
		end, "Background reconciliation did not complete a scan pass")
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
