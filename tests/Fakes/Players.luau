--[[
    The fake Players service, holding a LocalPlayer on the client with the
    character events 7.8.6's area tracker connects when it is required
--]]

--!strict
local Instance = require("./Instance")

type Spec = Instance.Spec
type World = Instance.World

local Players = {}

function Players.classes(world: World): { [string]: Spec }
	return {
		Players = {
			events = { "PlayerAdded", "PlayerRemoving" },

			init = function (players: any)
				if not world.settings.client then
					return
				end

				local player: any = world.create("Player")
				player.Parent = players
				world.write(players, "LocalPlayer", player)
			end,

			methods = {
				GetPlayers = function (self: any): { any }
					local found: { any } = {}
					for _, child: any in self:GetChildren() do
						if child:IsA("Player") then
							table.insert(found, child)
						end
					end

					return found
				end,
			},
		},

		Player = {
			internal = true,
			events = { "CharacterAdded", "CharacterRemoving" },
		},
	}
end

return Players
