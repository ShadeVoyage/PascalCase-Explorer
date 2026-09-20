--!strict

local Explorer = require("../src")

-- This branch lets CI load the generated bundle under Lune without a Roblox DataModel.
if game == nil then
	return Explorer
end

local SESSION_KEY = "__PascalCaseExplorerSession"
local previousSession = rawget(_G, SESSION_KEY) :: any

if type(previousSession) == "table" and previousSession.Hierarchy ~= nil then
	pcall(function()
		previousSession.Hierarchy:Destroy()
	end)
end

local hierarchy = Explorer.LiveHierarchy.Start(game)

local session: any = {
	Explorer = Explorer,
	Hierarchy = hierarchy,
	Version = Explorer.Version,
}

function session.Stop()
	if hierarchy:IsRunning() then
		hierarchy:Destroy()
	end

	if rawget(_G, SESSION_KEY) == session then
		rawset(_G, SESSION_KEY, nil)
	end
end

rawset(_G, SESSION_KEY, session)

print(
	string.format(
		"[PascalCase Explorer] %s started; mirrored %d client-visible instances",
		Explorer.Version,
		hierarchy.Tree:GetCount()
	)
)

return session
