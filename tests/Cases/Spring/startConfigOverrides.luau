--[[
    A config in the targets stands in for the spring's own for that start
    only, and a start without one goes back to the spring's own
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local OWN: number = 2
local OVERRIDE: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Spring: any = env.require("Spring")
	local State: any = env.require("State")

	local styles: any, api: any = Spring.new(function ()
		return { volume = START, config = { duration = OWN, delay = 0 } }
	end)

	local overridden: any = api:start({ volume = TARGET, config = { duration = OVERRIDE, delay = 0 } })
	env.step(OVERRIDE)
	if State.get(styles.volume) ~= TARGET or overridden:getStatus() ~= "Resolved" then
		return false, `a start with its own {OVERRIDE} s config stood at {State.get(styles.volume)} at {OVERRIDE} s`
	end

	local own: any = api:start({ volume = START })
	env.step(OVERRIDE)
	if State.get(styles.volume) ~= TARGET / 2 or own:getStatus() ~= "Started" then
		return false,
			`a start with no config did not take the spring's own {OWN} s: it stood at {State.get(styles.volume)}`
	end

	env.step(OWN - OVERRIDE)
	if State.get(styles.volume) ~= START or own:getStatus() ~= "Resolved" then
		return false, `a start with no config did not land at the spring's own {OWN} s`
	end

	return true, nil
end
