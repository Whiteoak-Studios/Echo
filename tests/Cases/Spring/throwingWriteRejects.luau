--[[
    A write that throws mid-start rejects the start's Promise with the error
    and ends its Heartbeat connection, so a broken binding leaks nothing
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local DURATION: number = 1
local BROKEN: string = "binding broke"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Spring: any = env.require("Spring")
	local State: any = env.require("State")
	local heartbeat: any = env.game:GetService("RunService").Heartbeat

	local styles: any, api: any = Spring.new(function ()
		return { volume = START, config = { duration = DURATION, delay = 0 } }
	end)

	State.subscribe(styles.volume, function ()
		error(BROKEN)
	end)

	local rejection: string? = nil
	local promise: any = api:start({ volume = TARGET }):catch(function (message: any)
		rejection = tostring(message)
	end)

	env.step(DURATION)
	if not rejection or not rejection:find(BROKEN, 1, true) then
		return false, `a throwing write left the start's Promise {promise:getStatus()}, rejected with {rejection}`
	end

	if env.connections(heartbeat) ~= 0 then
		return false, "a start whose write threw kept its Heartbeat connection"
	end

	return true, nil
end
