--[[
    Limit 8 on 7.8.6: useSignal takes a name only, so the signal's table
    from Echo.Signals, which the README passes, errors at the call
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Shot"
local WAIT: number = 6 -- Past 7.8.6's five-second timeout

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local calls: number = 0
	Echo.createSignal(NAME, function ()
		calls += 1
	end)

	local fired: boolean = pcall(Echo.useSignal, Echo.Signals[NAME])
	env.step(WAIT)

	if fired then
		return false,
			`useSignal took Echo.Signals.{NAME}, a table, with no error; in {WAIT} s its callback ran {calls} times and it warned: {env.warnings[1]}`
	end

	return true, nil
end
