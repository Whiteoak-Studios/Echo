--[[
    A pool given only its initial size is fixed: configure takes it with no
    growth fields and fills that many voices
--]]

--!strict
local Environment = require("../../Environment")

local FIXED: { [string]: number } = { initial = 4 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Cache: any = env.require("Cache")

	local configured: boolean, message: any = pcall(Root.configure, { mode = "Legacy", cache = { Legacy = FIXED } })
	if not configured then
		return false, `a pool given only its initial errored: {message}`
	end

	local size: number = Cache.count("Legacy").size
	if size ~= FIXED.initial then
		return false, `the fixed pool holds {size} voices, not {FIXED.initial}`
	end

	return true, nil
end
