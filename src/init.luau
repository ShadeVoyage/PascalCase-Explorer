--!strict

local Version = require("@self/Version")
local TreeStore = require("@self/Core/TreeStore")
local RobloxSnapshot = require("@self/Runtime/RobloxSnapshot")
local LiveHierarchy = require("@self/Runtime/LiveHierarchy")

local PascalCaseExplorer = {}

PascalCaseExplorer.Name = Version.Name
PascalCaseExplorer.Version = Version.Version
PascalCaseExplorer.TreeStore = TreeStore
PascalCaseExplorer.RobloxSnapshot = RobloxSnapshot
PascalCaseExplorer.LiveHierarchy = LiveHierarchy

function PascalCaseExplorer.getInfo(): string
	return string.format("%s %s", PascalCaseExplorer.Name, PascalCaseExplorer.Version)
end

return PascalCaseExplorer
