--!strict

local runIntegration = require("./roblox/phase1_live_hierarchy.integration")

assert(type(runIntegration) == "function", "Roblox integration harness must return a function")

print("Roblox integration harness load test passed")
