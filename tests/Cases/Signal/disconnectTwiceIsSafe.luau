--[[
    A disconnect called twice does nothing the second time, and it ends only
    its own subscription, even when the same function is subscribed twice
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Signal: any = env.require("Signal")
	local signal: any = Signal.new()

	local calls: number = 0
	local function count()
		calls += 1
	end

	local disconnect: () -> () = signal:subscribe(count)
	signal:subscribe(count)

	signal:fire()
	if calls ~= 2 then
		return false, `one function subscribed twice ran {calls} times in a fire, not 2`
	end

	disconnect()
	local again: boolean, reason: any = pcall(disconnect)
	if not again then
		return false, `a second disconnect threw: {reason}`
	end

	calls = 0
	signal:fire()
	if calls ~= 1 then
		return false, `after one of the two subscriptions disconnected twice, the function ran {calls} times, not 1`
	end

	return true, nil
end
