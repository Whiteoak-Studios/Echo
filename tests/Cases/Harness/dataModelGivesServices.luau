--[[
    The fake game gives each service it holds by GetService, refuses one it
    does not, and lets no script make a service or a game
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"

local SERVICES: { string } = {
	"Workspace",
	"ReplicatedStorage",
	"SoundService",
	"RunService",
	"ContentProvider",
	"Players",
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local package: any = env.require()

	if package.game ~= env.game or env.game.ClassName ~= "DataModel" then
		return false, "the package's game is not the environment's DataModel"
	end

	for _, name: string in SERVICES do
		local service: any = env.game:GetService(name)
		if service.ClassName ~= name or service.Parent ~= env.game then
			return false, `GetService("{name}") did not give the game's {name}`
		end

		if pcall(env.Instance.new, name) then
			return false, `Instance.new made a {name}`
		end
	end

	if pcall(env.game.GetService, env.game, "DataStoreService") or pcall(env.Instance.new, "DataModel") then
		return false, "GetService gave a service the fake game lacks, or Instance.new made a game"
	end

	if env.game.Workspace ~= env.game:GetService("Workspace") then
		return false, "game.Workspace is not the Workspace service"
	end

	if env.Instance.new("ModuleScript").ClassName ~= "ModuleScript" then
		return false, "Instance.new made no ModuleScript"
	end

	return true, nil
end
