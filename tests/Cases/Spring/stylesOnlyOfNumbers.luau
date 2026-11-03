--[[
    A spring makes a style, a state, of each number it is built with, and of
    nothing else: not its config, a string, a boolean or a table
--]]

--!strict
local Environment = require("../../Environment")

local VOLUME: number = 0.5
local PITCH: number = -2
local NAME: string = "Bed"
local DURATION: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Spring: any = env.require("Spring")
	local State: any = env.require("State")

	local styles: any = Spring.new(function ()
		return {
			volume = VOLUME,
			pitch = PITCH,
			name = NAME,
			muted = true,
			list = {},
			config = { duration = DURATION, delay = 0 },
		}
	end)

	local names: { string } = {}
	for name: string in styles do
		table.insert(names, name)
	end
	table.sort(names)

	if #names ~= 2 or names[1] ~= "pitch" or names[2] ~= "volume" then
		return false, `the spring made styles of {table.concat(names, ", ")}, not only pitch and volume`
	end

	if not State.is(styles.volume) or State.get(styles.volume) ~= VOLUME or State.get(styles.pitch) ~= PITCH then
		return false, "a style is not a state holding the number it was built with"
	end

	return true, nil
end
