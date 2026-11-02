--[[
    The fake RunService: Heartbeat and RenderStepped, which the environment
    fires once a frame as a case steps, and the realm checks a case sets
--]]

--!strict
local Instance = require("./Instance")

type Spec = Instance.Spec
type World = Instance.World

local RunService = {}

function RunService.classes(world: World): { [string]: Spec }
	return {
		RunService = {
			events = { "Heartbeat", "RenderStepped" },

			methods = {
				IsStudio = function (): boolean
					return world.settings.studio
				end,

				IsClient = function (): boolean
					return world.settings.client
				end,

				IsServer = function (): boolean
					return not world.settings.client
				end,
			},
		},
	}
end

return RunService
