--!strict

local Version = require("./Version")

local PascalCaseExplorer = {}

PascalCaseExplorer.Name = Version.Name
PascalCaseExplorer.Version = Version.Version

function PascalCaseExplorer.getInfo(): string
	return string.format("%s %s", PascalCaseExplorer.Name, PascalCaseExplorer.Version)
end

return PascalCaseExplorer
