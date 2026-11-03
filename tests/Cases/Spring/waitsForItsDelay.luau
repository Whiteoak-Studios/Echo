--[[
    A start holds its values still through its delay, then moves them over
    its duration and lands on the target at the delay plus the duration
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local DELAY: number = 0.5
local DURATION: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Spring: any = env.require("Spring")
	local State: any = env.require("State")

	local styles: any, api: any = Spring.new(function ()
		return { volume = START, config = { duration = DURATION, delay = DELAY } }
	end)

	local promise: any = api:start({ volume = TARGET })
	env.step(DELAY)
	if State.get(styles.volume) ~= START then
		return false, `during its delay the spring moved to {State.get(styles.volume)}`
	end

	env.step(DURATION / 2)
	if State.get(styles.volume) ~= (START + TARGET) / 2 then
		return false, `halfway past its delay the spring stood at {State.get(styles.volume)}`
	end

	env.step(DURATION / 2)
	if State.get(styles.volume) ~= TARGET or promise:getStatus() ~= "Resolved" then
		return false,
			`at its delay plus duration the spring stood at {State.get(styles.volume)}, its Promise {promise:getStatus()}`
	end

	return true, nil
end
