--[[
    create's disconnect ends its own callback and no other under the name,
    and calling it twice is safe
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Ambience/Rain"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Signals: any = env.require("Signals")

	local stopped: number = 0
	local kept: number = 0

	local disconnect: () -> () = Signals.create(NAME, function ()
		stopped += 1
	end)

	Signals.create(NAME, function ()
		kept += 1
	end)

	disconnect()
	local again: boolean, reason: any = pcall(disconnect)
	if not again then
		return false, `a second disconnect threw: {reason}`
	end

	Signals.fire(NAME)
	if stopped ~= 0 or kept ~= 1 then
		return false, `after one disconnect the callbacks ran {stopped} and {kept} times, not 0 and 1`
	end

	return true, nil
end
