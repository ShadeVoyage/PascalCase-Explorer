--!strict

local Explorer = require("../src")

local info = Explorer.getInfo()

assert(type(info) == "string")
assert(string.find(info, "PascalCase Explorer", 1, true) ~= nil)

print("Smoke test passed:", info)
