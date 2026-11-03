--[[
    A start errors at the call, naming the problem, on a target with no
    style, a target that is no number, targets that are no table and a bad
    config, and a refused start leaves the running one alone
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local DURATION: number = 1
local MISSING: string = "pitch"

type Refusal = {
	label: string,
	targets: any,
	names: string?, -- Text the error must hold
}

local REFUSALS: { Refusal } = {
	{ label = "a target with no style", targets = { [MISSING] = TARGET }, names = MISSING },
	{ label = "a target that is a string", targets = { volume = "loud" }, names = "string" },
	{ label = "targets that are a number", targets = TARGET, names = "number" },
	{ label = "a config that is a string", targets = { volume = TARGET, config = "fast" } },
	{ label = "a negative delay", targets = { volume = TARGET, config = { delay = -DURATION } } },
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Spring: any = env.require("Spring")
	local State: any = env.require("State")
	local heartbeat: any = env.game:GetService("RunService").Heartbeat

	local styles: any, api: any = Spring.new(function ()
		return { volume = START, config = { duration = DURATION, delay = 0 } }
	end)

	local running: any = api:start({ volume = TARGET })

	for _, refusal: Refusal in REFUSALS do
		local started: boolean, reason: any = pcall(api.start, api, refusal.targets)
		if started then
			return false, `start took {refusal.label}`
		elseif refusal.names and not tostring(reason):find(refusal.names, 1, true) then
			return false, `start's error on {refusal.label} did not name {refusal.names}: {reason}`
		end
	end

	if running:getStatus() ~= "Started" or env.connections(heartbeat) ~= 1 then
		return false, "a refused start canceled the running one"
	end

	env.step(DURATION)
	if State.get(styles.volume) ~= TARGET then
		return false, `the running start ended at {State.get(styles.volume)} after the refused ones`
	end

	return true, nil
end
