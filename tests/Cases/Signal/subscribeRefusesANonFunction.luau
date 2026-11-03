--[[
    A subscribe given anything but a function errors at the call, naming
    what it was given, and subscribes nothing
--]]

--!strict
local Environment = require("../../Environment")

local NOT_A_FUNCTION: string = "play"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Signal: any = env.require("Signal")
	local signal: any = Signal.new()

	for _, value: any in { NOT_A_FUNCTION, {}, false } do
		local subscribed: boolean, reason: any = pcall(signal.subscribe, signal, value)
		if subscribed then
			return false, `subscribe took a {typeof(value)}`
		elseif not tostring(reason):find(typeof(value), 1, true) then
			return false, `subscribe's error did not name the {typeof(value)} it was given: {reason}`
		end
	end

	local fired: boolean, reason: any = pcall(signal.fire, signal)
	if not fired then
		return false, `a fire after the refused subscribes threw: {reason}`
	end

	return true, nil
end
