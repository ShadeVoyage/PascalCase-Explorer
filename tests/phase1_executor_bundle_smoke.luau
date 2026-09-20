--!strict

local payload = require("../dist/PascalCaseExplorer_Phase1Test")

assert(type(payload) == "table", "Phase 1 test bundle must return a table under Lune")
assert(type(payload.Explorer) == "table", "Phase 1 test bundle must include Explorer")
assert(type(payload.RunIntegration) == "function", "Phase 1 test bundle must include the test function")
assert(
	payload.Explorer.Name == "PascalCase Explorer",
	"Phase 1 test bundle must contain PascalCase Explorer"
)

print("Phase 1 executor test bundle smoke test passed")
