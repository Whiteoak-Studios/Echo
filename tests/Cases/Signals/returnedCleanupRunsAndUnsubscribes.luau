--[[
    A callback that returns a function is unsubscribed in the fire that
    called it, the function runs at once inside that fire, and the other
    callbacks under the name carry on
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Radio"
local LAST_CALL: number = 2

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Signals: any = env.require("Signals")

	local calls: number = 0
	local cleanups: number = 0
	local others: number = 0

	local disconnect: () -> () = Signals.create(NAME, function (): any
		calls += 1
		if calls < LAST_CALL then
			return nil
		end

		return function ()
			cleanups += 1
		end
	end)

	Signals.create(NAME, function ()
		others += 1
	end)

	Signals.fire(NAME)
	if cleanups ~= 0 then
		return false, "a callback that returned nothing had a cleanup run"
	end

	Signals.fire(NAME)
	if cleanups ~= 1 then
		return false,
			`the fire whose callback returned a function had run its cleanup {cleanups} times when it returned`
	end

	Signals.fire(NAME)
	if calls ~= LAST_CALL or cleanups ~= 1 then
		return false, `after its cleanup the callback ran {calls} times in all and its cleanup {cleanups}`
	end

	if others ~= 3 then
		return false, `the other callback ran {others} times in three fires`
	end

	local again: boolean, reason: any = pcall(disconnect)
	if not again then
		return false, `create's disconnect threw after the callback had unsubscribed: {reason}`
	end

	return true, nil
end
