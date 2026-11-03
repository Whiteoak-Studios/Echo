--[[
    Limit 17 on 7.8.6: a start with a duration of 0 sets its target at once,
    within the call, and never writes a value that is not a number
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local FRAME: number = 1 / 60

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local styles: any, api: any = Echo.useSpring(function ()
		return { volume = START, config = { duration = 0, delay = 0 } }
	end)

	local value: number = START
	local writes: { string } = {}
	local nonNumber: boolean = false
	styles.volume.subscribe(function (volume: number)
		value = volume
		table.insert(writes, tostring(volume))

		-- Only NaN differs from itself
		if volume ~= volume then
			nonNumber = true
		end
	end)

	api:start({ volume = TARGET })
	local atOnce: number = value

	env.step(FRAME * 2)

	local written: string = table.concat(writes, ", ")
	if atOnce ~= TARGET or nonNumber then
		return false,
			`a start with no duration left the spring at {atOnce} within the call, and its next frames wrote {written}`
	end

	return true, nil
end
