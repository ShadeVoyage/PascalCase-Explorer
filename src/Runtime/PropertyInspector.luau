--!strict

export type PropertyEntry = {
	Name: string,
	Category: string,
	Value: any,
	ValueText: string,
	ValueType: string,
	Editable: boolean,
}

type PropertySpec = {
	Name: string,
	Category: string,
	Editable: boolean,
}

type Rule = {
	ClassName: string,
	Properties: { PropertySpec },
}

local PropertyInspector = {}

local BASE_PROPERTIES: { PropertySpec } = {
	{ Name = "Name", Category = "Identity", Editable = true },
	{ Name = "ClassName", Category = "Identity", Editable = false },
	{ Name = "Parent", Category = "Identity", Editable = false },
	{ Name = "Archivable", Category = "Identity", Editable = true },
}

local RULES: { Rule } = {
	{
		ClassName = "ValueBase",
		Properties = {
			{ Name = "Value", Category = "Data", Editable = true },
		},
	},
	{
		ClassName = "BasePart",
		Properties = {
			{ Name = "Anchored", Category = "Transform", Editable = true },
			{ Name = "Position", Category = "Transform", Editable = true },
			{ Name = "Orientation", Category = "Transform", Editable = true },
			{ Name = "Size", Category = "Transform", Editable = true },
			{ Name = "AssemblyLinearVelocity", Category = "Physics", Editable = true },
			{ Name = "AssemblyAngularVelocity", Category = "Physics", Editable = true },
			{ Name = "CanCollide", Category = "Physics", Editable = true },
			{ Name = "CanTouch", Category = "Physics", Editable = true },
			{ Name = "CanQuery", Category = "Physics", Editable = true },
			{ Name = "Massless", Category = "Physics", Editable = true },
			{ Name = "CollisionGroup", Category = "Physics", Editable = true },
			{ Name = "Transparency", Category = "Appearance", Editable = true },
			{ Name = "Reflectance", Category = "Appearance", Editable = true },
			{ Name = "Color", Category = "Appearance", Editable = true },
			{ Name = "Material", Category = "Appearance", Editable = true },
			{ Name = "CastShadow", Category = "Appearance", Editable = true },
		},
	},
	{
		ClassName = "Humanoid",
		Properties = {
			{ Name = "Health", Category = "Humanoid", Editable = true },
			{ Name = "MaxHealth", Category = "Humanoid", Editable = true },
			{ Name = "WalkSpeed", Category = "Humanoid", Editable = true },
			{ Name = "JumpPower", Category = "Humanoid", Editable = true },
			{ Name = "JumpHeight", Category = "Humanoid", Editable = true },
			{ Name = "HipHeight", Category = "Humanoid", Editable = true },
			{ Name = "AutoRotate", Category = "Humanoid", Editable = true },
			{ Name = "PlatformStand", Category = "Humanoid", Editable = true },
			{ Name = "Sit", Category = "Humanoid", Editable = true },
			{ Name = "RigType", Category = "Humanoid", Editable = false },
		},
	},
	{
		ClassName = "Sound",
		Properties = {
			{ Name = "SoundId", Category = "Sound", Editable = true },
			{ Name = "Volume", Category = "Sound", Editable = true },
			{ Name = "PlaybackSpeed", Category = "Sound", Editable = true },
			{ Name = "TimePosition", Category = "Sound", Editable = true },
			{ Name = "Looped", Category = "Sound", Editable = true },
			{ Name = "Playing", Category = "Sound", Editable = true },
			{ Name = "RollOffMinDistance", Category = "Sound", Editable = true },
			{ Name = "RollOffMaxDistance", Category = "Sound", Editable = true },
		},
	},
	{
		ClassName = "GuiObject",
		Properties = {
			{ Name = "Visible", Category = "GUI", Editable = true },
			{ Name = "Active", Category = "GUI", Editable = true },
			{ Name = "Position", Category = "GUI", Editable = true },
			{ Name = "Size", Category = "GUI", Editable = true },
			{ Name = "AnchorPoint", Category = "GUI", Editable = true },
			{ Name = "Rotation", Category = "GUI", Editable = true },
			{ Name = "ZIndex", Category = "GUI", Editable = true },
			{ Name = "LayoutOrder", Category = "GUI", Editable = true },
			{ Name = "BackgroundColor3", Category = "Appearance", Editable = true },
			{ Name = "BackgroundTransparency", Category = "Appearance", Editable = true },
			{ Name = "BorderSizePixel", Category = "Appearance", Editable = true },
		},
	},
	{
		ClassName = "TextLabel",
		Properties = {
			{ Name = "Text", Category = "Text", Editable = true },
			{ Name = "TextSize", Category = "Text", Editable = true },
			{ Name = "TextColor3", Category = "Text", Editable = true },
			{ Name = "TextTransparency", Category = "Text", Editable = true },
			{ Name = "TextWrapped", Category = "Text", Editable = true },
		},
	},
	{
		ClassName = "TextButton",
		Properties = {
			{ Name = "Text", Category = "Text", Editable = true },
			{ Name = "TextSize", Category = "Text", Editable = true },
			{ Name = "TextColor3", Category = "Text", Editable = true },
			{ Name = "TextTransparency", Category = "Text", Editable = true },
			{ Name = "TextWrapped", Category = "Text", Editable = true },
		},
	},
	{
		ClassName = "TextBox",
		Properties = {
			{ Name = "Text", Category = "Text", Editable = true },
			{ Name = "TextSize", Category = "Text", Editable = true },
			{ Name = "TextColor3", Category = "Text", Editable = true },
			{ Name = "TextTransparency", Category = "Text", Editable = true },
			{ Name = "TextWrapped", Category = "Text", Editable = true },
			{ Name = "PlaceholderText", Category = "Text", Editable = true },
		},
	},
	{
		ClassName = "ImageLabel",
		Properties = {
			{ Name = "Image", Category = "Image", Editable = true },
			{ Name = "ImageColor3", Category = "Image", Editable = true },
			{ Name = "ImageTransparency", Category = "Image", Editable = true },
		},
	},
	{
		ClassName = "ImageButton",
		Properties = {
			{ Name = "Image", Category = "Image", Editable = true },
			{ Name = "ImageColor3", Category = "Image", Editable = true },
			{ Name = "ImageTransparency", Category = "Image", Editable = true },
		},
	},
	{
		ClassName = "ScreenGui",
		Properties = {
			{ Name = "Enabled", Category = "GUI", Editable = true },
			{ Name = "DisplayOrder", Category = "GUI", Editable = true },
			{ Name = "IgnoreGuiInset", Category = "GUI", Editable = true },
		},
	},
	{
		ClassName = "Lighting",
		Properties = {
			{ Name = "ClockTime", Category = "Lighting", Editable = true },
			{ Name = "Brightness", Category = "Lighting", Editable = true },
			{ Name = "ExposureCompensation", Category = "Lighting", Editable = true },
			{ Name = "Ambient", Category = "Lighting", Editable = true },
			{ Name = "OutdoorAmbient", Category = "Lighting", Editable = true },
			{ Name = "FogStart", Category = "Lighting", Editable = true },
			{ Name = "FogEnd", Category = "Lighting", Editable = true },
			{ Name = "FogColor", Category = "Lighting", Editable = true },
		},
	},
	{
		ClassName = "Camera",
		Properties = {
			{ Name = "FieldOfView", Category = "Camera", Editable = true },
			{ Name = "CameraType", Category = "Camera", Editable = true },
			{ Name = "CameraSubject", Category = "Camera", Editable = false },
			{ Name = "ViewportSize", Category = "Camera", Editable = false },
		},
	},
	{
		ClassName = "Animation",
		Properties = {
			{ Name = "AnimationId", Category = "Animation", Editable = true },
		},
	},
	{
		ClassName = "Decal",
		Properties = {
			{ Name = "Texture", Category = "Appearance", Editable = true },
			{ Name = "Color3", Category = "Appearance", Editable = true },
			{ Name = "Transparency", Category = "Appearance", Editable = true },
		},
	},
	{
		ClassName = "Texture",
		Properties = {
			{ Name = "Texture", Category = "Appearance", Editable = true },
			{ Name = "Color3", Category = "Appearance", Editable = true },
			{ Name = "Transparency", Category = "Appearance", Editable = true },
			{ Name = "StudsPerTileU", Category = "Appearance", Editable = true },
			{ Name = "StudsPerTileV", Category = "Appearance", Editable = true },
		},
	},
	{
		ClassName = "ProximityPrompt",
		Properties = {
			{ Name = "Enabled", Category = "Prompt", Editable = true },
			{ Name = "ActionText", Category = "Prompt", Editable = true },
			{ Name = "ObjectText", Category = "Prompt", Editable = true },
			{ Name = "HoldDuration", Category = "Prompt", Editable = true },
			{ Name = "MaxActivationDistance", Category = "Prompt", Editable = true },
			{ Name = "RequiresLineOfSight", Category = "Prompt", Editable = true },
		},
	},
	{
		ClassName = "ClickDetector",
		Properties = {
			{ Name = "MaxActivationDistance", Category = "Interaction", Editable = true },
			{ Name = "CursorIcon", Category = "Interaction", Editable = true },
		},
	},
}

local function trim(text: string): string
	return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

local function splitNumbers(text: string): { number }?
	local result: { number } = {}
	for token in string.gmatch(text, "[^,%s]+") do
		local value = tonumber(token)
		if value == nil then
			return nil
		end
		table.insert(result, value)
	end
	return result
end

local function formatNumber(value: number): string
	if math.abs(value) >= 100000 or (value ~= 0 and math.abs(value) < 0.0001) then
		return string.format("%.5g", value)
	end
	return string.format("%.6g", value)
end

function PropertyInspector.FormatValue(value: any): string
	local valueType = typeof(value)

	if valueType == "string" then
		return value
	elseif valueType == "number" then
		return formatNumber(value)
	elseif valueType == "boolean" then
		return if value then "true" else "false"
	elseif valueType == "nil" then
		return "nil"
	elseif valueType == "Color3" then
		return string.format(
			"%d, %d, %d",
			math.round(value.R * 255),
			math.round(value.G * 255),
			math.round(value.B * 255)
		)
	elseif valueType == "Vector2" then
		return string.format("%s, %s", formatNumber(value.X), formatNumber(value.Y))
	elseif valueType == "Vector3" then
		return string.format(
			"%s, %s, %s",
			formatNumber(value.X),
			formatNumber(value.Y),
			formatNumber(value.Z)
		)
	elseif valueType == "UDim" then
		return string.format("%s, %s", formatNumber(value.Scale), formatNumber(value.Offset))
	elseif valueType == "UDim2" then
		return string.format(
			"%s, %s, %s, %s",
			formatNumber(value.X.Scale),
			formatNumber(value.X.Offset),
			formatNumber(value.Y.Scale),
			formatNumber(value.Y.Offset)
		)
	elseif valueType == "EnumItem" then
		return value.Name
	elseif valueType == "Instance" then
		local success, fullName = pcall(function()
			return value:GetFullName()
		end)
		if success then
			return fullName
		end
		return value.Name
	end

	return tostring(value)
end

function PropertyInspector.ParseValue(text: string, currentValue: any): (boolean, any, string?)
	local valueType = typeof(currentValue)
	local cleaned = trim(text)

	if valueType == "string" then
		return true, text, nil
	elseif valueType == "number" then
		local value = tonumber(cleaned)
		if value == nil then
			return false, nil, "Expected a number"
		end
		return true, value, nil
	elseif valueType == "boolean" then
		local lowered = string.lower(cleaned)
		if lowered == "true" or lowered == "1" or lowered == "yes" or lowered == "on" then
			return true, true, nil
		elseif lowered == "false" or lowered == "0" or lowered == "no" or lowered == "off" then
			return true, false, nil
		end
		return false, nil, "Expected true or false"
	elseif valueType == "Color3" then
		local values = splitNumbers(cleaned)
		if values == nil or #values ~= 3 then
			return false, nil, "Expected R, G, B"
		end

		local maxValue = math.max(values[1], values[2], values[3])
		if maxValue > 1 then
			return true, Color3.fromRGB(values[1], values[2], values[3]), nil
		end
		return true, Color3.new(values[1], values[2], values[3]), nil
	elseif valueType == "Vector2" then
		local values = splitNumbers(cleaned)
		if values == nil or #values ~= 2 then
			return false, nil, "Expected X, Y"
		end
		return true, Vector2.new(values[1], values[2]), nil
	elseif valueType == "Vector3" then
		local values = splitNumbers(cleaned)
		if values == nil or #values ~= 3 then
			return false, nil, "Expected X, Y, Z"
		end
		return true, Vector3.new(values[1], values[2], values[3]), nil
	elseif valueType == "UDim" then
		local values = splitNumbers(cleaned)
		if values == nil or #values ~= 2 then
			return false, nil, "Expected Scale, Offset"
		end
		return true, UDim.new(values[1], values[2]), nil
	elseif valueType == "UDim2" then
		local values = splitNumbers(cleaned)
		if values == nil or #values ~= 4 then
			return false, nil, "Expected XScale, XOffset, YScale, YOffset"
		end
		return true, UDim2.new(values[1], values[2], values[3], values[4]), nil
	elseif valueType == "EnumItem" then
		local enumType = currentValue.EnumType
		for _, item in ipairs(enumType:GetEnumItems()) do
			if string.lower(item.Name) == string.lower(cleaned) then
				return true, item, nil
			end
		end
		return false, nil, "Unknown enum item for " .. tostring(enumType)
	end

	return false, nil, valueType .. " editing is not supported"
end

local function supportsEditing(value: any): boolean
	local valueType = typeof(value)
	return valueType == "string"
		or valueType == "number"
		or valueType == "boolean"
		or valueType == "Color3"
		or valueType == "Vector2"
		or valueType == "Vector3"
		or valueType == "UDim"
		or valueType == "UDim2"
		or valueType == "EnumItem"
end

local function tryRead(object: Instance, propertyName: string): (boolean, any)
	return pcall(function()
		return (object :: any)[propertyName]
	end)
end

local function addSpec(
	object: Instance,
	spec: PropertySpec,
	seen: { [string]: boolean },
	result: { PropertyEntry }
)
	if seen[spec.Name] then
		return
	end

	local success, value = tryRead(object, spec.Name)
	if not success then
		return
	end

	seen[spec.Name] = true
	table.insert(result, {
		Name = spec.Name,
		Category = spec.Category,
		Value = value,
		ValueText = PropertyInspector.FormatValue(value),
		ValueType = typeof(value),
		Editable = spec.Editable and supportsEditing(value),
	})
end

function PropertyInspector.GetProperties(object: Instance): { PropertyEntry }
	local result: { PropertyEntry } = {}
	local seen: { [string]: boolean } = {}

	for _, spec in ipairs(BASE_PROPERTIES) do
		addSpec(object, spec, seen, result)
	end

	for _, rule in ipairs(RULES) do
		local applies = false
		local success, isA = pcall(function()
			return object:IsA(rule.ClassName)
		end)
		if success then
			applies = isA
		end

		if applies then
			for _, spec in ipairs(rule.Properties) do
				addSpec(object, spec, seen, result)
			end
		end
	end

	return result
end

function PropertyInspector.SetProperty(
	object: Instance,
	propertyName: string,
	text: string
): (boolean, string?)
	local readSuccess, currentValue = tryRead(object, propertyName)
	if not readSuccess then
		return false, "Property is unavailable"
	end

	local parsed, newValue, parseError = PropertyInspector.ParseValue(text, currentValue)
	if not parsed then
		return false, parseError
	end

	local writeSuccess, writeError = pcall(function()
		(object :: any)[propertyName] = newValue
	end)

	if not writeSuccess then
		return false, tostring(writeError)
	end

	return true, nil
end

return PropertyInspector
