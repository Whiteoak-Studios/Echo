--[[
    A start moves on one Heartbeat connection in Studio and live alike, and
    lands exactly on its target at its duration, then writes no more
--]]

--!strict
local Environment = require("../../Environment")

local START: number = 0
local TARGET: number = 1
local HALF: number = 0.5
local DURATION: number = 1

type Run = {
	label: string,
	options: Environment.Options,
}

local RUNS: { Run } = {
	{ label = "in Studio", options = { studio = true } },
	{ label = "on a live client", options = { studio = false } },
	{ label = "on a live server", options = { studio = false, client = false } },
}

--[[
    Runs one spring to its end in one environment, and gives why it went
    wrong there, or nil
--]]

local function check(run: Run): string?
	local env: Environment.Environment = Environment.new(run.options)
	local Spring: any = env.require("Spring")
	local State: any = env.require("State")
	local runService: any = env.game:GetService("RunService")

	local styles: any, api: any = Spring.new(function ()
		return { volume = START, config = { duration = DURATION, delay = 0 } }
	end)

	local writes: number = 0
	State.subscribe(styles.volume, function ()
		writes += 1
	end)

	local promise: any = api:start({ volume = TARGET })
	if env.connections(runService.Heartbeat) ~= 1 or env.connections(runService.RenderStepped) ~= 0 then
		return `{run.label} a start did not hold exactly one Heartbeat connection and no RenderStepped one`
	end

	env.step(DURATION * HALF)
	if State.get(styles.volume) ~= START + (TARGET - START) * HALF then
		return `{run.label} halfway through, the spring stood at {State.get(styles.volume)}`
	end

	env.step(DURATION * HALF)
	if State.get(styles.volume) ~= TARGET or promise:getStatus() ~= "Resolved" then
		return `{run.label} at its duration the spring stood at {State.get(styles.volume)}, its Promise {promise:getStatus()}`
	end

	if env.connections(runService.Heartbeat) ~= 0 then
		return `{run.label} the spring kept its Heartbeat connection after it landed`
	end

	local landed: number = writes
	env.step(DURATION)
	if writes ~= landed or State.get(styles.volume) ~= TARGET then
		return `{run.label} the spring wrote {writes - landed} more times after it landed`
	end

	return nil
end

return function (): (boolean, string | nil)
	for _, run: Run in RUNS do
		local reason: string? = check(run)
		if reason then
			return false, reason
		end
	end

	return true, nil
end
