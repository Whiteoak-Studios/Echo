--[[
    Every set updates current and then tells each subscriber the new value,
    a repeat of the value it holds and a set to nil included
--]]

--!strict
local Environment = require("../../Environment")

local DEFAULT: number = 1
local NEXT: number = 2

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local State: any = env.require("State")
	local state: any, set: (value: any) -> () = State.new(DEFAULT)

	-- Indexed by call, since a nil value leaves no entry for a length to count
	local calls: number = 0
	local seen: { [number]: any } = {}
	local readInside: { [number]: any } = {}
	State.subscribe(state, function (value: any)
		calls += 1
		seen[calls] = value
		readInside[calls] = State.get(state)
	end)

	set(NEXT)
	set(NEXT)
	set(nil)

	if calls ~= 3 or seen[1] ~= NEXT or seen[2] ~= NEXT or seen[3] ~= nil then
		return false, `three sets told the subscriber {calls} times, with {seen[1]}, {seen[2]} and {seen[3]}`
	end

	if readInside[1] ~= NEXT or readInside[2] ~= NEXT or readInside[3] ~= nil then
		return false, "a subscriber read the old value: a set must update current before it notifies"
	end

	if State.get(state) ~= nil then
		return false, "a set to nil did not leave current nil"
	end

	return true, nil
end
