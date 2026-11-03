--[[
    A state subscription's disconnect ends it, and a second call does
    nothing, so removing an element after any sets never throws
--]]

--!strict
local Environment = require("../../Environment")

local DEFAULT: number = 1
local NEXT: number = 2

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local State: any = env.require("State")
	local state: any, set: (value: any) -> () = State.new(DEFAULT)

	local calls: number = 0
	local disconnect: () -> () = State.subscribe(state, function ()
		calls += 1
	end)

	set(NEXT)
	disconnect()

	local again: boolean, reason: any = pcall(disconnect)
	if not again then
		return false, `a second disconnect threw: {reason}`
	end

	set(DEFAULT)
	if calls ~= 1 then
		return false, `a disconnected subscriber was told {calls} times, not once`
	end

	return true, nil
end
