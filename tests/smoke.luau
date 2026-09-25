--!strict

local Explorer = require("../src")

local info = Explorer.getInfo()

assert(type(info) == "string", "Explorer info must be a string")
assert(
	string.find(info, "PascalCase Explorer", 1, true) ~= nil,
	"Explorer info must contain the project name"
)
assert(type(Explorer.LiveHierarchy) == "table", "LiveHierarchy must be exported")
assert(type(Explorer.LiveHierarchy.Start) == "function", "LiveHierarchy.Start must be available")
assert(type(Explorer.PropertyInspector) == "table", "PropertyInspector must be exported")
assert(
	type(Explorer.PropertyInspector.GetProperties) == "function",
	"PropertyInspector must be available"
)
assert(type(Explorer.ExplorerWindow) == "table", "ExplorerWindow must be exported")
assert(type(Explorer.ClassIconProvider) == "table", "ClassIconProvider must be exported")
assert(type(Explorer.LegacyClassIconAtlas) == "table", "LegacyClassIconAtlas must be exported")
assert(type(Explorer.ExplorerWindow.new) == "function", "ExplorerWindow.new must be available")

print("Smoke test passed:", info)
