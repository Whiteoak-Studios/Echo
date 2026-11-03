--[[
    Limit 2 on 7.8.6: outside Studio a spring moves on Heartbeat, so it
    reaches its target where only Heartbeat fires and RenderStepped never
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local DURATION: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy", studio = false, client = false })
	local Echo: any = env.require()

	local styles: any, api: any = Echo.useSpring(function ()
		return { volume = START, config = { duration = DURATION, delay = 0 } }
	end)

	local value: number = START
	styles.volume.subscribe(function (volume: number)
		value = volume
	end)

	local promise: any = api:start({ volume = TARGET })
	env.step(DURATION * 2)

	if value ~= TARGET then
		return false,
			`with Heartbeat firing and RenderStepped not, the spring stood at {value} after {DURATION * 2} s, its Promise {promise:getStatus()}`
	end

	return true, nil
end
