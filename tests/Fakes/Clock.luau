--[[
    The fake clock an environment runs on: os.clock, tick and a task library
    whose waits, delays and defers run only when a case steps it, frame by
    frame at sixty frames a second
--]]

--!strict
local task = require("@lune/task")

local FRAME_RATE: number = 60 -- Frames in one second of fake time, as Roblox steps a client
local EPSILON: number = 1e-9 -- Float slack when a due time is compared with the clock
local MAX_DEFERS: number = 10000 -- Deferred threads one step may run before the clock calls it a runaway

type Timed = {
	at: number, -- The fake time it is due, resumed at the first frame on or after it
	resume: () -> (),
}

export type Task = {
	spawn: (callback: any, ...any) -> thread,
	defer: (callback: any, ...any) -> thread,
	delay: (seconds: number?, callback: any, ...any) -> thread,
	wait: (seconds: number?) -> number,
	cancel: (thread: thread) -> (),
}

export type Clock = {
	task: Task,
	os: { [string]: any },
	tick: () -> number,
	now: () -> number,
	errors: { string }, -- Every error a thread the fake task library started threw
	pending: () -> (() -> ...any, (...any) -> ()),
	step: (seconds: number, frame: (delta: number) -> ()) -> (),
}

local Clock = {}

--[[
    Roblox reads a missing, negative, infinite or NaN wait as none
--]]

local function length(seconds: number?): number
	if seconds and seconds > 0 and seconds < math.huge then
		return seconds
	end

	return 0
end

local function checkCallback(name: string, callback: any)
	if type(callback) ~= "function" and type(callback) ~= "thread" then
		error(`invalid argument #1 to '{name}' (function or thread expected, got {type(callback)})`, 3)
	end
end

local function traceback(message: any): string
	return debug.traceback(tostring(message), 2)
end

--[[
    Builds a clock at zero. A waiting thread parks on a pending promise of
    the given Promise, the harness's own copy on Lune's task, which resumes
    it at once when the clock settles it
--]]

function Clock.new(Promise: any): Clock
	local elapsed: number = 0
	local frames: number = 0
	local timed: { Timed } = {}
	local deferred: { () -> () } = {}
	local errors: { string } = {}

	local function now(): number
		return elapsed
	end

	-- Gives a hold that parks the calling thread and the resume that wakes it with the values it is given
	local function pending(): (() -> ...any, (...any) -> ())
		local settle: (...any) -> () = function () end
		local promise: any = Promise.new(function (resolve: (...any) -> ())
			settle = resolve
		end)

		return function (): ...any
			return select(2, promise:await())
		end, settle
	end

	-- Runs a callback on a thread of its own and keeps any error it throws, as Roblox prints it and carries on
	local function spawnThread(callback: any, ...: any): thread
		checkCallback("spawn", callback)

		if type(callback) == "thread" then
			return task.spawn(callback, ...)
		end

		return task.spawn(function (...: any)
			local ran: boolean, message: any = xpcall(callback, traceback, ...)
			if not ran then
				table.insert(errors, tostring(message))
			end
		end, ...)
	end

	local function call(callback: any, ...: any)
		if type(callback) == "thread" then
			task.spawn(callback, ...)
		else
			(callback :: (...any) -> ())(...)
		end
	end

	-- Parks the running thread until the first frame on or after at, behind every thread due as soon
	local function park(at: number)
		local hold: () -> ...any, resume: (...any) -> () = pending()

		local index: number = #timed + 1
		for position: number, entry: Timed in timed do
			if entry.at > at then
				index = position
				break
			end
		end

		table.insert(timed, index, { at = at, resume = resume })
		hold()
	end

	local function defer(callback: any, ...: any): thread
		checkCallback("defer", callback)

		return spawnThread(function (...: any)
			local hold: () -> ...any, resume: (...any) -> () = pending()
			table.insert(deferred, resume)
			hold()
			call(callback, ...)
		end, ...)
	end

	local function delay(seconds: number?, callback: any, ...: any): thread
		checkCallback("delay", callback)
		local at: number = elapsed + length(seconds)

		return spawnThread(function (...: any)
			park(at)
			call(callback, ...)
		end, ...)
	end

	local function waitFor(seconds: number?): number
		local start: number = elapsed
		park(elapsed + length(seconds))

		return elapsed - start
	end

	-- Takes every thread due by now before resuming any, so a wait a resumed thread makes lands on a later frame
	local function runDue()
		local due: { Timed } = {}
		while timed[1] and timed[1].at <= elapsed + EPSILON do
			table.insert(due, table.remove(timed, 1) :: Timed)
		end

		for _, entry: Timed in due do
			entry.resume()
		end
	end

	local function runDeferred()
		local ran: number = 0
		while deferred[1] do
			ran += 1
			if ran > MAX_DEFERS then
				error(
					`The clock ran {MAX_DEFERS} deferred threads in one step with more still queued; something defers forever`
				)
			end

			local resume: () -> () = table.remove(deferred, 1) :: () -> ()
			resume()
		end
	end

	-- Runs the deferred threads, then each frame the time covers: its frame callback, the threads due, then their defers
	local function step(seconds: number, frame: (delta: number) -> ())
		if not (seconds >= 0 and seconds < math.huge) then
			error(`step takes a finite time of 0 or more, not {seconds}`, 3)
		end

		local target: number = elapsed + seconds
		runDeferred()

		while (frames + 1) / FRAME_RATE <= target + EPSILON do
			frames += 1
			elapsed = frames / FRAME_RATE

			frame(1 / FRAME_RATE)
			runDue()
			runDeferred()
		end

		-- A target within float slack of the last frame is that frame, so whole frames add up exactly
		if target > elapsed + EPSILON then
			elapsed = target
		end
	end

	local fakeOs: { [string]: any } = table.clone(os) :: any
	fakeOs.clock = now

	return {
		os = fakeOs,
		tick = now,
		now = now,
		errors = errors,
		pending = pending,
		step = step,

		task = {
			spawn = spawnThread,
			defer = defer,
			delay = delay,
			wait = waitFor,
			cancel = task.cancel,
		},
	}
end

return Clock
