--[[
    On 7.8.6: in Studio a misspelled signal name fails loudly at the call,
    not with a silent warning five seconds later
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Gun/AKM/Fire"
local MISSPELLED: string = "Gun/AMK/Fire"
local WAIT: number = 6 -- Past 7.8.6's five-second timeout

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy", studio = true })
	local Echo: any = env.require()

	Echo.createSignal(NAME, function () end)

	local fired: boolean = pcall(Echo.useSignal, MISSPELLED)
	env.step(WAIT)

	if fired then
		return false,
			`in Studio useSignal took the misspelled {MISSPELLED} with no error, and after {WAIT} s had only warned: {env.warnings[1]}`
	end

	return true, nil
end
