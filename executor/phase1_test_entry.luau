--!strict

local Explorer = require("../src")
local runIntegration = require("../tests/roblox/phase1_live_hierarchy.integration")

-- Let CI load the generated bundle under Lune without a Roblox DataModel.
if game == nil then
	return {
		Explorer = Explorer,
		RunIntegration = runIntegration,
	}
end

print("[PascalCase Explorer] Running Phase 1 Roblox integration test...")

local success, failure = pcall(runIntegration, Explorer)

if not success then
	warn("[PascalCase Explorer] PHASE 1 TEST: FAIL")
	error(failure, 0)
end

print("[PascalCase Explorer] PHASE 1 TEST: PASS")

return true
