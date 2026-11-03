--[[
    Limit 16 on 7.8.6: a spring rises from -12 to 0 with no jump, and from
    -12 to -6 with no error, each landing on its target
--]]

--!strict
local Environment = require("../../Environment")

local FROM: number = -12
local UP_TO_ZERO: number = 0
local UP_TO_NEGATIVE: number = -6
local DURATION: number = 1
local HALF: number = 0.5
local SLACK: number = 1 -- 7.8.6 starts a frame late, so its halfway value sits a fraction off

type Rise = {
	halfway: number,
	ended: number,
	warning: string?,
}

--[[
    Runs one rise from FROM in a fresh 7.8.6 and gives where it stood
    halfway and at the end, and its first warning
--]]

local function rise(target: number): Rise
	local env: Environment.Environment = Environment.new({ source = "legacy", studio = true })
	local Echo: any = env.require()

	local styles: any, api: any = Echo.useSpring(function ()
		return { volume = FROM, config = { duration = DURATION, delay = 0 } }
	end)

	local value: number = FROM
	styles.volume.subscribe(function (volume: number)
		value = volume
	end)

	api:start({ volume = target })
	env.step(DURATION * HALF)
	local halfway: number = value

	env.step(DURATION)
	local warning: string? = env.warnings[1] or env.errors[1]
	table.clear(env.errors)

	return { halfway = halfway, ended = value, warning = warning }
end

return function (): (boolean, string | nil)
	local toZero: Rise = rise(UP_TO_ZERO)
	local toNegative: Rise = rise(UP_TO_NEGATIVE)

	local expected: number = FROM + (UP_TO_ZERO - FROM) * HALF
	if math.abs(toZero.halfway - expected) > SLACK or toNegative.ended ~= UP_TO_NEGATIVE then
		return false,
			`halfway from {FROM} to {UP_TO_ZERO} the spring stood at {toZero.halfway}, not near {expected}; from {FROM} to {UP_TO_NEGATIVE} it ended at {toNegative.ended}, warning: {toNegative.warning}`
	end

	return true, nil
end
