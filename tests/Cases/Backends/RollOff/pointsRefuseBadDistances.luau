--[[
    RollOff.points fails its assert, naming the bad end, for a min below 0,
    a max at or below its min, and a distance that is not a finite number
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

local NAN: number = 0 / 0

-- Each bad pair, and the end its message names
local BAD: { { any } } = {
	{ -1, 10, "min" },
	{ NAN, 10, "min" },
	{ math.huge, math.huge, "min" },
	{ 10, 10, "max" },
	{ 10, 5, "max" },
	{ 10, NAN, "max" },
	{ 10, math.huge, "max" },
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local RollOff: any = env.require("Backends/RollOff")
	local mode: any = roblox.Enum.RollOffMode.Linear

	for _, pair: { any } in BAD do
		local passed: boolean, message: any = pcall(RollOff.points, mode, pair[1], pair[2])
		if passed then
			return false, `RollOff.points took a min of {pair[1]} and a max of {pair[2]}`
		elseif not tostring(message):find(`{pair[3]} distance`) then
			return false,
				`RollOff.points refused a min of {pair[1]} and a max of {pair[2]} without naming its {pair[3]}: {message}`
		end
	end

	return true, nil
end
