--[[
    A callback that throws raises its error at the fire, and every other
    callback under the name still runs
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Hit"
local BROKEN: string = "hit callback broke"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Signals: any = env.require("Signals")

	local ran: number = 0
	Signals.create(NAME, function ()
		error(BROKEN)
	end)

	Signals.create(NAME, function ()
		ran += 1
	end)

	local fired: boolean, reason: any = pcall(Signals.fire, NAME)
	if fired or not tostring(reason):find(BROKEN, 1, true) then
		return false, `a fire whose callback threw gave {fired}, {reason}`
	end

	if ran ~= 1 then
		return false, `the other callback ran {ran} times, not once`
	end

	if #env.warnings ~= 0 then
		return false, `the fire warned where it should only raise: {env.warnings[1]}`
	end

	return true, nil
end
