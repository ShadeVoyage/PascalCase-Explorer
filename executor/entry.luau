--# selene: allow(global_usage)
--!strict

-- _G intentionally stores the repeat-run executor session.

local Explorer = require("../src")

-- This branch lets CI load the generated bundle under Lune without a Roblox DataModel.
if game == nil then
	return Explorer
end

local SESSION_KEY = "__PascalCaseExplorerSession"
local previousSession = rawget(_G, SESSION_KEY) :: any

if type(previousSession) == "table" then
	if type(previousSession.Stop) == "function" then
		pcall(previousSession.Stop)
	elseif previousSession.Hierarchy ~= nil then
		pcall(function()
			previousSession.Hierarchy:Destroy()
		end)
	end
end

local hierarchy = Explorer.LiveHierarchy.Start(game)
local window: any = nil
local stopped = false

local session: any = {
	Explorer = Explorer,
	Hierarchy = hierarchy,
	Version = Explorer.Version,
}

function session.Stop()
	if stopped then
		return
	end

	stopped = true

	if window ~= nil and window:IsOpen() then
		window:Destroy()
	end

	if hierarchy:IsRunning() then
		hierarchy:Destroy()
	end

	if rawget(_G, SESSION_KEY) == session then
		rawset(_G, SESSION_KEY, nil)
	end
end

window = Explorer.ExplorerWindow.new(hierarchy, {
	Version = Explorer.Version,
	OnClose = function()
		session.Stop()
	end,
})

session.Window = window

rawset(_G, SESSION_KEY, session)

print(
	string.format(
		"[PascalCase Explorer] %s started; mirrored %d client-visible instances",
		Explorer.Version,
		hierarchy.Tree:GetCount()
	)
)

return session
