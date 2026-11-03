--[[
    A new state holds its default in current and true under the state
    marker, which is all State.is and the element unit tell a state by
--]]

--!strict
local Environment = require("../../Environment")

local DEFAULT: number = 0.5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local State: any = env.require("State")
	local Keys: any = env.require("Keys")

	local state: any, set: any = State.new(DEFAULT)
	if rawget(state, "current") ~= DEFAULT or rawget(state, Keys.State) ~= true then
		return false, "a new state does not hold its default in current and true under Keys.State"
	end

	if type(set) ~= "function" or not State.is(state) or State.get(state) ~= DEFAULT then
		return false, "State.new gave no setter, or State.is or State.get did not read the state"
	end

	local empty: any = State.new(nil)
	if not State.is(empty) or State.get(empty) ~= nil then
		return false, "a state with no default is not a state holding nil"
	end

	-- Only a table holding true under the marker itself is a state
	local lookalike: any = setmetatable({}, { __index = { [Keys.State] = true } })
	local others: { any } = { DEFAULT, "state", {}, { current = DEFAULT }, { [Keys.State] = "yes" }, lookalike }
	for _, value: any in others do
		if State.is(value) then
			return false, `State.is took a {typeof(value)} that is no state`
		end
	end

	if State.is(nil) then
		return false, "State.is took nil"
	end

	return true, nil
end
