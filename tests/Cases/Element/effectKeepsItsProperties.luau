--[[
    Each legacy effect class makes an effect element that keeps its class
    and, in a copy of its own, every property's value, a state included
--]]

--!strict
local Environment = require("../../Environment")

local PRIORITY: number = 1
local OTHER: number = 2

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Constants: any = env.require("Constants")
	local Keys: any = env.require("Keys")

	local state: any = { [Keys.State] = true, current = true }

	for className: string in Constants.EFFECTS do
		local props: { [string]: any } = { Priority = PRIORITY, Enabled = state }
		local effect: any = Element.create(className, props)

		if effect.kind ~= "Effect" or effect.className ~= className then
			return false, `a {className} made no effect element of its class`
		end

		if effect.properties.Priority ~= PRIORITY or effect.properties.Enabled ~= state then
			return false, `a {className} did not keep a value and a state as given`
		end

		props.Priority = OTHER
		if effect.properties == props or effect.properties.Priority ~= PRIORITY then
			return false, `a {className}'s properties changed with the table it was given`
		end
	end

	return true, nil
end
