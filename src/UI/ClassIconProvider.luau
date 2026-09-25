--!strict

export type IconInfo = {
	Image: string?,
	ImageRectOffset: Vector2?,
	ImageRectSize: Vector2?,
	FallbackText: string,
	FallbackColor: Color3,
	Official: boolean,
}

local ClassIconProvider = {}

local cache: { [string]: IconInfo } = {}
local studioServiceChecked = false
local studioService: any = nil

local CLASS_FALLBACKS: { [string]: string } = {
	Folder = "F",
	Model = "M",
	Part = "P",
	MeshPart = "P",
	UnionOperation = "P",
	LocalScript = "LS",
	Script = "SC",
	ModuleScript = "MS",
	RemoteEvent = "RE",
	RemoteFunction = "RF",
	BindableEvent = "BE",
	BindableFunction = "BF",
	Sound = "♪",
	Animation = "A",
	Camera = "C",
	Tool = "T",
	Humanoid = "H",
	ScreenGui = "UI",
	Frame = "UI",
	TextLabel = "UI",
	TextButton = "UI",
	ImageLabel = "UI",
	ImageButton = "UI",
}

local function fallbackFor(className: string, isRoot: boolean, isService: boolean): (string, Color3)
	if isRoot then
		return "G", Color3.fromRGB(242, 190, 74)
	end

	if isService then
		return "S", Color3.fromRGB(92, 184, 232)
	end

	local text = CLASS_FALLBACKS[className] or "·"

	if className == "LocalScript" or className == "Script" or className == "ModuleScript" then
		return text, Color3.fromRGB(236, 187, 85)
	elseif className == "RemoteEvent" or className == "RemoteFunction" then
		return text, Color3.fromRGB(232, 112, 132)
	elseif className == "Folder" or className == "Model" then
		return text, Color3.fromRGB(120, 180, 240)
	elseif className == "Part" or className == "MeshPart" or className == "UnionOperation" then
		return text, Color3.fromRGB(133, 205, 145)
	elseif string.find(className, "Gui", 1, true) ~= nil then
		return text, Color3.fromRGB(188, 142, 238)
	end

	return text, Color3.fromRGB(160, 170, 184)
end

local function getStudioService(): any
	if studioServiceChecked then
		return studioService
	end

	studioServiceChecked = true

	if game == nil then
		return nil
	end

	local success, service = pcall(function()
		return game:GetService("StudioService")
	end)

	if success then
		studioService = service
	end

	return studioService
end

local function getOfficialIcon(className: string): IconInfo?
	local cached = cache[className]
	if cached ~= nil and cached.Official then
		return cached
	end

	local service = getStudioService()
	if service == nil then
		return nil
	end

	local success, icon = pcall(function()
		return service:GetClassIcon(className)
	end)

	if not success or type(icon) ~= "table" then
		return nil
	end

	local image = icon.Image
	local rectOffset = icon.ImageRectOffset
	local rectSize = icon.ImageRectSize

	if
		type(image) ~= "string"
		or typeof(rectOffset) ~= "Vector2"
		or typeof(rectSize) ~= "Vector2"
	then
		return nil
	end

	local result: IconInfo = {
		Image = image,
		ImageRectOffset = rectOffset,
		ImageRectSize = rectSize,
		FallbackText = "",
		FallbackColor = Color3.new(1, 1, 1),
		Official = true,
	}

	cache[className] = result
	return result
end

function ClassIconProvider.Get(className: string, isRoot: boolean, isService: boolean): IconInfo
	local official = getOfficialIcon(className)
	if official ~= nil then
		return official
	end

	local fallbackText, fallbackColor = fallbackFor(className, isRoot, isService)

	return {
		Image = nil,
		ImageRectOffset = nil,
		ImageRectSize = nil,
		FallbackText = fallbackText,
		FallbackColor = fallbackColor,
		Official = false,
	}
end

function ClassIconProvider.ClearCache()
	table.clear(cache)
	studioServiceChecked = false
	studioService = nil
end

return ClassIconProvider
