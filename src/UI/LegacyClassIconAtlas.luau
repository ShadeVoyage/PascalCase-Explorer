--!strict

local GeneratedClassIconMap = require("./GeneratedClassIconMap")

export type AtlasIcon = {
	Image: string,
	ImageRectOffset: Vector2,
	ImageRectSize: Vector2,
}

local LegacyClassIconAtlas = {}

local IMAGE = "rbxasset://textures/ClassImages.png"
local ICON_SIZE = 16

function LegacyClassIconAtlas.Get(className: string): AtlasIcon?
	local index = GeneratedClassIconMap[className]
	if index == nil or index < 0 then
		return nil
	end

	return {
		Image = IMAGE,
		ImageRectOffset = Vector2.new(index * ICON_SIZE, 0),
		ImageRectSize = Vector2.new(ICON_SIZE, ICON_SIZE),
	}
end

return LegacyClassIconAtlas
