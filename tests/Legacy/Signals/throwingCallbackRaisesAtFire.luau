--[[
    Limit 14 on 7.8.6: a createSignal callback that throws raises at the
    useSignal that fired it, and the other callbacks under the name run
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Hit"
local BROKEN: string = "hit callback broke"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	Echo.createSignal(NAME, function ()
		error(BROKEN)
	end)

	local ran: number = 0
	Echo.createSignal(NAME, function ()
		ran += 1
	end)

	local fired: boolean = pcall(Echo.useSignal, NAME)
	env.step(0)

	if fired or ran ~= 1 then
		local raised: string = fired and "raised nothing at useSignal" or "raised at useSignal"
		return false, `a throwing callback {raised}, the other ran {ran} times, and 7.8.6 warned: {env.warnings[1]}`
	end

	return true, nil
end
