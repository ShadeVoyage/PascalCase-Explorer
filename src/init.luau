--!strict

local Version = require("@self/Version")
local TreeStore = require("@self/Core/TreeStore")
local RobloxSnapshot = require("@self/Runtime/RobloxSnapshot")
local LiveHierarchy = require("@self/Runtime/LiveHierarchy")
local PropertyInspector = require("@self/Runtime/PropertyInspector")
local ExplorerWindow = require("@self/UI/ExplorerWindow")
local ClassIconProvider = require("@self/UI/ClassIconProvider")

local PascalCaseExplorer = {}

PascalCaseExplorer.Name = Version.Name
PascalCaseExplorer.Version = Version.Version
PascalCaseExplorer.TreeStore = TreeStore
PascalCaseExplorer.RobloxSnapshot = RobloxSnapshot
PascalCaseExplorer.LiveHierarchy = LiveHierarchy
PascalCaseExplorer.PropertyInspector = PropertyInspector
PascalCaseExplorer.ExplorerWindow = ExplorerWindow
PascalCaseExplorer.ClassIconProvider = ClassIconProvider

function PascalCaseExplorer.getInfo(): string
	return string.format("%s %s", PascalCaseExplorer.Name, PascalCaseExplorer.Version)
end

return PascalCaseExplorer
