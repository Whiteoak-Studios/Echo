--[[
    A second start cancels the first and its Promise, so a fade cut short by
    the opposite one ends at the second's target, on one connection
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local LOUD: number = 1
local LONG: number = 2
local SHORT: number = 0.5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Spring: any = env.require("Spring")
	local State: any = env.require("State")
	local heartbeat: any = env.game:GetService("RunService").Heartbeat

	local styles: any, api: any = Spring.new(function ()
		return { volume = START, config = { duration = LONG, delay = 0 } }
	end)

	local first: any = api:start({ volume = LOUD })
	env.step(SHORT)
	local cut: number = State.get(styles.volume)

	local second: any = api:start({ volume = START, config = { duration = SHORT, delay = 0 } })
	if first:getStatus() ~= "Cancelled" then
		return false, `the first start's Promise was {first:getStatus()} after a second start, not Cancelled`
	end

	if env.connections(heartbeat) ~= 1 then
		return false, `two starts held {env.connections(heartbeat)} Heartbeat connections, not 1`
	end

	-- The second start moves from where the first left the value
	env.step(SHORT / 2)
	if State.get(styles.volume) ~= cut / 2 then
		return false, `halfway through the second start the spring stood at {State.get(styles.volume)}, not {cut / 2}`
	end

	env.step(SHORT / 2)
	if State.get(styles.volume) ~= START or second:getStatus() ~= "Resolved" then
		return false, `the second start ended at {State.get(styles.volume)}, its Promise {second:getStatus()}`
	end

	env.step(LONG)
	if State.get(styles.volume) ~= START or env.connections(heartbeat) ~= 0 then
		return false, `after the first start's duration the spring stood at {State.get(styles.volume)}`
	end

	return true, nil
end
