--!strict

local bundle = require("../dist/PascalCaseExplorer")

assert(type(bundle) == "table", "Generated executor bundle must return a table")
assert(bundle.Name == "PascalCase Explorer", "Generated bundle must expose the project name")
assert(type(bundle.Version) == "string", "Generated bundle must expose a version")
assert(type(bundle.TreeStore) == "table", "Generated bundle must include TreeStore")
assert(type(bundle.LiveHierarchy) == "table", "Generated bundle must include LiveHierarchy")

print("Executor bundle smoke test passed:", bundle.getInfo())
