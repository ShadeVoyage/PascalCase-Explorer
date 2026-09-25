--!strict

local GeneratedClassIconMap = require("../src/UI/GeneratedClassIconMap")

assert(
	GeneratedClassIconMap.Workspace == 19,
	"Workspace icon index should come from current metadata"
)
assert(GeneratedClassIconMap.Players == 21, "Players icon index should come from current metadata")
assert(
	GeneratedClassIconMap.Lighting == 13,
	"Lighting icon index should come from current metadata"
)
assert(
	GeneratedClassIconMap.SoundService == 31,
	"SoundService icon index should come from current metadata"
)
assert(GeneratedClassIconMap.Folder == 77, "Folder icon index should come from current metadata")
assert(GeneratedClassIconMap.Part == 1, "Part icon index should come from current metadata")

print("Generated class icon map tests passed")
