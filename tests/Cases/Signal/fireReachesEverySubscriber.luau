--[[
    A fire calls every subscribed callback with every value it is given, and
    a disconnected callback never runs again
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Shot"
local COUNT: number = 3

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Signal: any = env.require("Signal")
	local signal: any = Signal.new()

	local first: { any } = {}
	local second: { any } = {}

	signal:subscribe(function (...: any)
		first = { ... }
	end)

	local disconnect: () -> () = signal:subscribe(function (...: any)
		second = { ... }
	end)

	signal:fire(NAME, COUNT)
	if first[1] ~= NAME or first[2] ~= COUNT or second[1] ~= NAME or second[2] ~= COUNT then
		return false, "a fire did not reach both callbacks with both of its values"
	end

	disconnect()
	second = {}

	signal:fire(NAME, COUNT)
	if second[1] ~= nil then
		return false, "a disconnected callback ran"
	end

	if first[1] ~= NAME then
		return false, "disconnecting one callback stopped another"
	end

	return true, nil
end
