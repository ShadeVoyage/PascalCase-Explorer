--!strict

local Explorer = require("../dist/PascalCaseExplorer_PerformanceTest")

assert(type(Explorer) == "table", "Performance bundle must return Explorer under Lune")
assert(Explorer.Name == "PascalCase Explorer", "Performance bundle must contain PascalCase Explorer")
assert(type(Explorer.LiveHierarchy) == "table", "Performance bundle must include LiveHierarchy")

print("Performance executor bundle smoke test passed")
