--[[
    On 7.8.6, a function under Echo.Util.Cache is taken as an event before
    its key is read, so the cache never reads its config from the function
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	-- Cache.lua requires a Cache package beside Promise, so the case gives it an empty one
	local env: Environment.Environment = Environment.new({ source = "legacy", dependencies = { Cache = {} } })
	local Echo: any = env.require()
	local read: boolean = false

	local made: boolean, message: any = pcall(Echo.createElement, "Sound", {
		[Echo.Util.Cache] = function (): { [string]: any }
			read = true

			return {}
		end,
	})

	if not read then
		return false, `the function under Echo.Util.Cache was taken as an event and never reached the cache: {message}`
	elseif not made then
		return false, `the cache read its config, then createElement errored: {message}`
	end

	return true, nil
end
