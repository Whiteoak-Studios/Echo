--[[
    Requiring Echo, on the client or the server, connects nothing on
    RunService or Players, makes no instance and warns nothing, and a second
    later still holds nothing connected (limit 1)
--]]

--!strict
local Environment = require("../../Environment")

local LATER: number = 1

return function (): (boolean, string | nil)
	for _, client: boolean in { true, false } do
		local env: Environment.Environment = Environment.new({ client = client })
		local runService: any = env.game:GetService("RunService")
		local players: any = env.game:GetService("Players")
		local realm: string = client and "client" or "server"

		-- Each signal a require could connect: the frame loops, and the joins and characters a tracker follows
		local signals: { [string]: any } = {
			Heartbeat = runService.Heartbeat,
			RenderStepped = runService.RenderStepped,
			PlayerAdded = players.PlayerAdded,
			PlayerRemoving = players.PlayerRemoving,
		}

		local player: any = players.LocalPlayer
		if player then
			signals.CharacterAdded = player.CharacterAdded
			signals.CharacterRemoving = player.CharacterRemoving
		end

		-- Counts every instance the package makes, parented or not
		local made: number = 0
		local new: (className: string) -> any = env.Instance.new
		env.Instance.new = function (className: string): any
			made += 1
			return new(className)
		end

		local instances: number = #env.game:GetDescendants()

		env.require()
		env.step(LATER)

		for name: string, signal: any in signals do
			local connected: number = env.connections(signal)
			if connected ~= 0 then
				return false, `requiring Echo on the {realm} connected {connected} to {name}`
			end
		end

		local added: number = #env.game:GetDescendants() - instances
		if made ~= 0 or added ~= 0 then
			return false, `requiring Echo on the {realm} made {made} instances, and the game gained {added}`
		elseif #env.warnings ~= 0 then
			return false, `requiring Echo on the {realm} warned: {env.warnings[1]}`
		end
	end

	return true, nil
end
