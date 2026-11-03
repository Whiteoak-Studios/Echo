--[[
    A duration of 0 sets the targets within the start call and settles its
    Promise with no connection, or at the delay when there is one
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local DELAY: number = 0.5
local FRAME: number = 1 / 60

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Spring: any = env.require("Spring")
	local State: any = env.require("State")
	local heartbeat: any = env.game:GetService("RunService").Heartbeat

	local styles: any, api: any = Spring.new(function ()
		return { volume = START, config = { duration = 0, delay = 0 } }
	end)

	local promise: any = api:start({ volume = TARGET })
	if State.get(styles.volume) ~= TARGET or promise:getStatus() ~= "Resolved" then
		return false,
			`a start with no duration left the spring at {State.get(styles.volume)}, its Promise {promise:getStatus()}`
	end

	if env.connections(heartbeat) ~= 0 then
		return false, "a start with no duration and no delay connected to Heartbeat"
	end

	local delayed: any = api:start({ volume = START, config = { duration = 0, delay = DELAY } })
	env.step(DELAY - FRAME)
	if State.get(styles.volume) ~= TARGET then
		return false, `a start with a delay and no duration moved the spring before its delay`
	end

	env.step(FRAME)
	if State.get(styles.volume) ~= START or delayed:getStatus() ~= "Resolved" or env.connections(heartbeat) ~= 0 then
		return false, `at its delay a start with no duration left the spring at {State.get(styles.volume)}`
	end

	return true, nil
end
