--!strict

local Explorer = require("../src")

local info = Explorer.getInfo()

assert(type(info) == "string", "Explorer info must be a string")
assert(
	string.find(info, "PascalCase Explorer", 1, true) ~= nil,
	"Explorer info must contain the project name"
)

print("Smoke test passed:", info)
