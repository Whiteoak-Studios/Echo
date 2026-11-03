--[[
    Limit 15 on 7.8.6: useSpring makes a spring value only of a number, so
    a string or a boolean it is built with makes none
--]]

--!strict
local Environment = require("../../Environment")

local VOLUME: number = 0.5
local NAME: string = "Bed"
local DURATION: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local styles: any = Echo.useSpring(function ()
		return { volume = VOLUME, name = NAME, muted = true, config = { duration = DURATION, delay = 0 } }
	end)

	local extra: { string } = {}
	for key: string in styles do
		if key ~= "volume" then
			table.insert(extra, key)
		end
	end
	table.sort(extra)

	if #extra ~= 0 or not styles.volume then
		return false, `useSpring made spring values of {table.concat(extra, " and ")} beside volume`
	end

	return true, nil
end
