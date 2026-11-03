--[[
    Canceling a start's Promise ends its Heartbeat connection and leaves its
    values where they stood, with no write after
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local DURATION: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Spring: any = env.require("Spring")
	local State: any = env.require("State")
	local heartbeat: any = env.game:GetService("RunService").Heartbeat

	local styles: any, api: any = Spring.new(function ()
		return { volume = START, config = { duration = DURATION, delay = 0 } }
	end)

	local promise: any = api:start({ volume = TARGET })
	env.step(DURATION / 2)
	promise:cancel()

	if env.connections(heartbeat) ~= 0 then
		return false, "a canceled start kept its Heartbeat connection"
	end

	local stopped: number = State.get(styles.volume)
	env.step(DURATION)
	if State.get(styles.volume) ~= stopped then
		return false, `a canceled start moved the spring from {stopped} to {State.get(styles.volume)}`
	end

	return true, nil
end
