--[[
    Limit 2 on 7.8.6: a spring started outside Studio lands exactly on its
    target at its duration, settles then, and writes no more after
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local DURATION: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local styles: any, api: any = Echo.useSpring(function ()
		return { volume = START, config = { duration = DURATION, delay = 0 } }
	end)

	local value: number = START
	local writes: number = 0
	styles.volume.subscribe(function (volume: number)
		value = volume
		writes += 1
	end)

	local promise: any = api:start({ volume = TARGET })

	env.step(DURATION)
	local landed: number = value
	local status: string = promise:getStatus()
	local landedWrites: number = writes

	env.step(DURATION)
	local extra: number = writes - landedWrites

	if landed ~= TARGET or status ~= "Resolved" or extra ~= 0 then
		return false,
			`at its {DURATION} s duration the spring stood at {landed}, its Promise {status}, and it wrote {extra} more times after`
	end

	return true, nil
end
