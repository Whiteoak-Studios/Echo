--[[
    The fake task library runs nothing until a case steps: a defer runs on
    the next step, a delay on the first frame at its time and never before,
    a cancelled delay never, and os.clock and tick read the fake clock
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local FRAME: number = 1 / 60
local DELAY: number = 1
local HALF: number = 0.5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local package: any = env.require()
	local task: any = env.task
	local log: { string } = {}

	task.spawn(function ()
		table.insert(log, "spawn")
	end)

	if log[1] ~= "spawn" then
		return false, "task.spawn did not run its function at once"
	end

	local delayedAt: number? = nil
	task.defer(function ()
		table.insert(log, "defer")
	end)

	task.delay(DELAY, function ()
		table.insert(log, "delay")
		delayedAt = package.clock()
	end)

	task.cancel(task.delay(HALF, function ()
		table.insert(log, "cancelled")
	end))

	local waited: number? = nil
	local frameWait: number? = nil
	local clampedWait: number? = nil
	task.spawn(function ()
		waited = task.wait(HALF)
	end)

	task.spawn(function ()
		frameWait = task.wait()
	end)

	-- Roblox reads an infinite wait as none, so it lasts one frame
	task.spawn(function ()
		clampedWait = task.wait(math.huge)
	end)

	if #log ~= 1 then
		return false, `{log[2]} ran before the clock moved`
	end

	env.step(0)
	if log[2] ~= "defer" or #log ~= 2 then
		return false, "step(0) did not run only the deferred work"
	end

	env.step(FRAME)
	if frameWait ~= FRAME or clampedWait ~= FRAME then
		return false, `task.wait() returned {frameWait} and task.wait(math.huge) {clampedWait}, not one frame`
	end

	env.step(DELAY - FRAME * 2)
	if #log ~= 2 then
		return false, `{log[3]} ran a frame before its time`
	end

	if waited ~= HALF then
		return false, `task.wait({HALF}) returned {waited}`
	end

	env.step(FRAME)
	if log[3] ~= "delay" or #log ~= 3 or delayedAt ~= DELAY then
		return false, `the clock ran {table.concat(log, ", ")}, the delay at {delayedAt}`
	end

	if env.now() ~= DELAY or package.clock() ~= DELAY or package.tick() ~= DELAY then
		return false, `env.now, os.clock and tick read {env.now()}, {package.clock()} and {package.tick()}`
	end

	if pcall(env.step, -1) or pcall(env.step, math.huge) then
		return false, "the clock stepped by a negative or an infinite time"
	end

	if pcall(task.spawn, nil) or pcall(task.delay, DELAY, "not a function") then
		return false, "the task library took something that is neither a function nor a thread"
	end

	if #env.errors ~= 0 then
		return false, `a thread threw: {env.errors[1]}`
	end

	return true, nil
end
