--!strict

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local URL =
	"https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/ReflectionMetadata.xml"
local DEFAULT_OUTPUT = "src/UI/GeneratedClassIconMap.luau"

local outputPath = process.args[1] or DEFAULT_OUTPUT
local checkOnly = process.args[2] == "--check"

local response = net.request(URL)
assert(
	response.ok,
	string.format("Failed to download ReflectionMetadata.xml: %d", response.statusCode)
)

local indices: { [string]: number } = {}

for properties in
	string.gmatch(
		response.body,
		'<Item class="ReflectionMetadataClass">%s*<Properties>(.-)</Properties>'
	)
do
	local name = string.match(properties, '<string name="Name">([^<]+)</string>')
	local indexText = string.match(properties, '<string name="ExplorerImageIndex">(-?%d+)</string>')

	if name ~= nil and indexText ~= nil then
		local index = tonumber(indexText)
		if index ~= nil then
			indices[name] = index
		end
	end
end

local names: { string } = {}
for name in pairs(indices) do
	table.insert(names, name)
end
table.sort(names)

local lines = {
	"--!strict",
	"",
	"-- Generated from MaximumADHD/Roblox-Client-Tracker ReflectionMetadata.xml.",
	"-- Do not edit by hand; run scripts/generate_class_icons.luau.",
	"",
	"local INDEX: { [string]: number } = {",
}

for _, name in ipairs(names) do
	table.insert(lines, string.format("\t[%q] = %d,", name, indices[name]))
end

table.insert(lines, "}")
table.insert(lines, "")
table.insert(lines, "return INDEX")
table.insert(lines, "")

local output = table.concat(lines, "\n")

if checkOnly then
	local existing = fs.readFile(outputPath)
	assert(
		existing == output,
		"Generated class icon map is stale. Run: lune run scripts/generate_class_icons.luau"
	)
	print(string.format("Class icon map is current: %d classes", #names))
else
	fs.writeFile(outputPath, output)
	print(string.format("Wrote %d class icon mappings to %s", #names, outputPath))
end
