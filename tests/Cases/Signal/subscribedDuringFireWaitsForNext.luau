--[[
    A callback subscribed during a fire runs from the next fire, even when a
    callback fires the same signal again before the first fire ends
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Signal: any = env.require("Signal")
	local signal: any = Signal.new()

	local late: number = 0
	local outer: number = 0
	local subscribed: boolean = false

	signal:subscribe(function ()
		outer += 1
		if subscribed then
			return
		end

		subscribed = true
		signal:subscribe(function ()
			late += 1
		end)

		-- A fire from inside a callback still runs while the first fire walks its callbacks
		signal:fire()
	end)

	signal:fire()
	if outer ~= 2 then
		return false, `the first callback ran {outer} times across a fire and the one it started, not 2`
	end

	if late ~= 0 then
		return false, `a callback subscribed during a fire ran {late} times in that fire`
	end

	signal:fire()
	if late ~= 1 then
		return false, `a callback subscribed during a fire ran {late} times in the next fire, not 1`
	end

	return true, nil
end
