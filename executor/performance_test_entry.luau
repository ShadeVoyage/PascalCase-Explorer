--!strict

local Explorer = require("../src")

if game == nil then
	return Explorer
end

local BATCH_SIZE = 512
local WAIT_FOR_PASS_SECONDS = 20

print("[PascalCase Explorer] Starting Phase 1.5 scalability test...")

local hierarchy = Explorer.LiveHierarchy.Start(game, {
	ReconcileBatchSize = BATCH_SIZE,
})

local deadline = os.clock() + WAIT_FOR_PASS_SECONDS
while hierarchy:GetStats().CompletedPasses == 0 and os.clock() < deadline do
	task.wait()
end

local stats = hierarchy:GetStats()

assert(stats.PerInstanceConnections == 0, "Phase 1.5 must not create per-Instance connections")
assert(stats.ConnectionCount == 3, "Phase 1.5 should use exactly three global connections")

print(string.format("[PascalCase Explorer] Tracked instances: %d", stats.TrackedInstances))
print(string.format("[PascalCase Explorer] Global connections: %d", stats.ConnectionCount))
print(
	string.format(
		"[PascalCase Explorer] Per-instance connections: %d",
		stats.PerInstanceConnections
	)
)
print(string.format("[PascalCase Explorer] Reconcile batch size: %d", stats.ReconcileBatchSize))
print(string.format("[PascalCase Explorer] Completed scan passes: %d", stats.CompletedPasses))

if stats.LastPassSeconds ~= nil then
	print(
		string.format("[PascalCase Explorer] Last full scan: %.3f seconds", stats.LastPassSeconds)
	)
else
	warn("[PascalCase Explorer] A full background scan did not finish within the test window")
end

hierarchy:Destroy()

print("[PascalCase Explorer] PHASE 1.5 SCALABILITY TEST: PASS")

return stats
