--[[
    Spring.new errors at the call on a builder that is no function, one that
    returns no table, and a config that is no table or holds bad seconds
--]]

--!strict
local Environment = require("../../Environment")

local VOLUME: number = 1
local NEGATIVE: number = -1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Spring: any = env.require("Spring")

	local builders: { [string]: any } = {
		["a number in place of a builder"] = VOLUME,
		["a builder that returns a number"] = function (): any
			return VOLUME
		end,
		["a config that is a number"] = function (): any
			return { volume = VOLUME, config = VOLUME }
		end,
		["a negative duration"] = function (): any
			return { volume = VOLUME, config = { duration = NEGATIVE } }
		end,
		["a delay that is a string"] = function (): any
			return { volume = VOLUME, config = { delay = "soon" } }
		end,
		["an infinite duration"] = function (): any
			return { volume = VOLUME, config = { duration = math.huge } }
		end,
	}

	for label: string, builder: any in builders do
		local built: boolean = pcall(Spring.new, builder)
		if built then
			return false, `Spring.new took {label}`
		end
	end

	return true, nil
end
