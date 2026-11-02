--[[
    The fake DataModel and the containers a package is mounted in: the game
    with its services, ReplicatedStorage and ModuleScript
--]]

--!strict
local Instance = require("./Instance")

type Spec = Instance.Spec
type World = Instance.World

-- Every service the fake game holds, made with it
local SERVICES: { string } = {
	"Workspace",
	"ReplicatedStorage",
	"SoundService",
	"RunService",
	"ContentProvider",
	"Players",
}

local DataModel = {}

function DataModel.classes(world: World): { [string]: Spec }
	return {
		DataModel = {
			internal = true,

			init = function (game: any)
				for _, name: string in SERVICES do
					local service: any = world.create(name)
					service.Parent = game
				end

				world.write(game, "Workspace", game:FindFirstChild("Workspace"))
			end,

			methods = {
				GetService = function (self: any, name: string): any
					local service: any? = self:FindFirstChild(name)
					if not service or service.ClassName ~= name then
						error(`The fake game has no service {name}`, 2)
					end

					return service
				end,
			},
		},

		ReplicatedStorage = {},
		ModuleScript = {},
	}
end

return DataModel
