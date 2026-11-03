--[[
    On 7.8.6, Fragment's guard is always false, so a number in its list is
    called as a component; the fixed guard refuses it, naming its index
--]]

--!strict
local Environment = require("../../Environment")

local ENTRY: number = 5
local INDEX: string = "entry 1"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local made: boolean, message: any = pcall(Echo.createElement, Echo.Fragment, { ENTRY })
	if made then
		return false, "Fragment took a number as one of its entries"
	elseif not tostring(message):find(INDEX, 1, true) then
		return false, `Fragment's guard let a number through to a call: {message}`
	end

	return true, nil
end
