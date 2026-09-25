--# selene: allow(global_usage)
--!strict

local Clipboard = {}

local function findClipboardFunction(): ((string) -> ())?
	local candidates: { any } = { _G }

	local envOk, environment = pcall(function()
		return getfenv(0)
	end)
	if envOk and type(environment) == "table" then
		table.insert(candidates, environment)
	end

	for _, candidate in ipairs(candidates) do
		for _, name in ipairs({ "setclipboard", "toclipboard" }) do
			local value = rawget(candidate, name)
			if type(value) == "function" then
				return value
			end
		end
	end

	return nil
end

function Clipboard.Copy(text: string): (boolean, string?)
	local copy = findClipboardFunction()
	if copy == nil then
		return false, "Clipboard API unavailable in this executor"
	end

	local success, message = pcall(copy, text)
	if not success then
		return false, tostring(message)
	end

	return true, nil
end

return Clipboard
