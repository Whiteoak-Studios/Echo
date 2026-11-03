--[[
    Limit 14 on 7.8.6: an error in createSignal's own setup, such as a nil
    name, raises at the call instead of reaching only a warning
--]]

--!strict
local Environment = require("../../Environment")

local FRAME: number = 1 / 60 -- Promise warns of an unhandled rejection on the next frame

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local created: boolean = pcall(Echo.createSignal, nil, function () end)
	env.step(FRAME)

	if created then
		return false,
			`createSignal's setup failed on a nil name and raised nothing; 7.8.6 only warned: {env.warnings[1]}`
	end

	return true, nil
end
