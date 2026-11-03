--[[
    Limit 1 on 7.8.6: requiring Echo connects its area tracker's Heartbeat
    loop and the local player's character events, before any root mounts
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local runService: any = env.game:GetService("RunService")
	local player: any = env.game:GetService("Players").LocalPlayer

	env.require()

	local heartbeat: number = env.connections(runService.Heartbeat)
	local characters: number = env.connections(player.CharacterAdded) + env.connections(player.CharacterRemoving)
	if heartbeat ~= 0 or characters ~= 0 then
		return false,
			`requiring Echo connected {heartbeat} to Heartbeat and {characters} to the local player's character events`
	end

	return true, nil
end
