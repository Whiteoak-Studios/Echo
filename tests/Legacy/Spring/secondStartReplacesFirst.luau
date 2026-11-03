--[[
    Limit 17 on 7.8.6: a second start replaces the first, so a long fade up
    cut short by a short fade down ends at the second's target
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local LOUD: number = 1
local LONG: number = 2
local SHORT: number = 0.5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local styles: any, api: any = Echo.useSpring(function ()
		return { volume = START, config = { duration = LONG, delay = 0 } }
	end)

	local value: number = START
	styles.volume.subscribe(function (volume: number)
		value = volume
	end)

	api:start({ volume = LOUD })
	env.step(SHORT)
	api:start({ volume = START, config = { duration = SHORT, delay = 0 } })

	env.step(SHORT * 2)
	local afterSecond: number = value

	env.step(LONG)
	if afterSecond ~= START or value ~= START then
		return false,
			`a fade up cut by a {SHORT} s fade down stood at {afterSecond} once the second should have ended, and at {value} once the first's {LONG} s had passed`
	end

	return true, nil
end
