--[[
    A fire of a registered name runs its callbacks inside the call with its
    values, and no fire reaches Promise, which a counting stand-in proves
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Gun/AKM/Fire"
local POSITION: number = 4
local FIRES: number = 3

return function (): (boolean, string | nil)
	-- A counting stand-in records every member the package reads off Promise
	local reads: { string } = {}
	local counting: any = setmetatable({}, {
		__index = function (_: any, key: string): any
			table.insert(reads, key)
			return nil
		end,
	})

	local env: Environment.Environment = Environment.new({ dependencies = { Promise = counting } })
	local Signals: any = env.require("Signals")

	local received: { any } = {}
	local calls: number = 0
	Signals.create(NAME, function (...: any)
		calls += 1
		received = { ... }
	end)

	for _ = 1, FIRES do
		Signals.fire(NAME, POSITION, NAME)
	end

	if calls ~= FIRES or received[1] ~= POSITION or received[2] ~= NAME then
		return false,
			`{FIRES} fires ran the callback {calls} times inside the call, last with {received[1]} and {received[2]}`
	end

	if #reads ~= 0 then
		return false, `the fires read Promise.{reads[1]}`
	end

	return true, nil
end
