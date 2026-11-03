--[[
    The sound pool benchmark's four jobs, each in both Modes: a pooled voice
    playing a preloaded asset, the first play after a preload, about 150
    voices, and a play of a recording nothing has held for ten minutes
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local Echo = require(ReplicatedStorage.Packages.Echo)

local Config = require(script.Parent.Config)
local Job = require(script.Parent.Job)
local Scene = require(script.Parent.Scene)

local ONE_SHOTS: { string } = Config.recordings.oneShots
local FIRST_PLAYS: { string } = Config.recordings.b2
local IDLE_PLAYS: { string } = Config.recordings.b4
local LOOPS: { string } = Config.recordings.loops
local LOAD_SECONDS: number = Config.deadlines.load
local PRELOAD_SECONDS: number = Config.deadlines.preload
local ENDED_SECONDS: number = Config.deadlines.ended
local DISTANCE: number = Config.distance
local PLAYS: number = Config.b1.plays
local MAX_FRAMES: number = Config.b1.maxFrames
local VOICES: number = Config.b3.voices
local QUIET_SECONDS: number = Config.b3.idle
local BUSY_SECONDS: number = Config.b3.busy
local RADIUS: number = Config.b3.radius
local SEED: number = Config.b3.seed
local IDLE_SECONDS: number = Config.b4.idle
local MILLISECONDS: number = 1000 -- In a second
local MICROSECONDS: number = 1000000 -- In a second

local MODES: { Echo.Mode } = { "Legacy", "AudioApi" }

type Handle = Echo.Handle
type Job = Job.Job
type Mode = Echo.Mode
type Playing = Job.Playing
type Run = Job.Run
type Verdict = Job.Verdict
type Voice = Echo.Voice

-- One timed play, as b1 measures it
type Sample = {
	cost: number, -- Seconds the play call took
	loaded: boolean, -- Whether the instance had its asset ready at the call
	startDelay: number, -- Seconds from the call to the next Heartbeat, less the TimePosition there
	frames: number, -- Heartbeats until TimePosition first moves
}

local Bench: { [string]: Run } = {}

-- A fragment of one sound for each id, each with the given props and a ref, the refs in id order
local function sounds(ids: { string }, props: Echo.Props): (Echo.Element, { Echo.Ref<Handle?> })
	local elements: { Echo.Element } = {}
	local refs: { Echo.Ref<Handle?> } = {}

	for _, id: string in ids do
		local ref: Echo.Ref<Handle?> = Echo.createRef()
		local given: Echo.Props = table.clone(props)
		given.SoundId = id
		given.Ref = ref

		table.insert(elements, Echo.createElement("Sound", given))
		table.insert(refs, ref)
	end

	return Echo.createElement(Echo.Fragment, elements), refs
end

local function handlesOf(job: Job, refs: { Echo.Ref<Handle?> }, mode: Mode): { Handle }
	local handles: { Handle } = {}
	for index: number, ref: Echo.Ref<Handle?> in refs do
		handles[index] = job:need(ref.current, `{mode} handle {index}`)
	end

	return handles
end

--[[
    Times one play: the play call's cost, whether the asset was ready at
    the call, the start delay at the next Heartbeat and the frames until
    TimePosition moves, then stops the voice before the next play
--]]

local function measure(job: Job, handle: Handle, overrides: Echo.Overrides?, what: string): Sample
	-- Each play starts at the same point of a frame
	RunService.Heartbeat:Wait()

	local started: number = os.clock()
	local voice: Voice? = handle:play(overrides)
	local cost: number = os.clock() - started

	local played: Voice = job:need(voice, `voice for {what}`)
	local instance: Playing = job:need(played.instance, `instance playing {what}`)
	local loaded: boolean = Job.loaded(instance)

	RunService.Heartbeat:Wait()
	local startDelay: number = os.clock() - started - instance.TimePosition

	local frames: number = 1
	while instance.TimePosition <= 0 and frames < MAX_FRAMES do
		RunService.Heartbeat:Wait()
		frames += 1
	end

	if instance.TimePosition <= 0 then
		job:fail(`{what} never moved its TimePosition within {MAX_FRAMES} frames`)
	end

	handle:stop(played)

	return { cost = cost, loaded = loaded, startDelay = startDelay, frames = frames }
end

-- The figures of a set of timed plays, each as its median, 95th percentile and worst
local function report(label: string, samples: { Sample }): string
	local costs: { number } = {}
	local delays: { number } = {}
	local frames: { number } = {}
	local loaded: number = 0

	for _, sample: Sample in samples do
		table.insert(costs, sample.cost * MICROSECONDS)
		table.insert(delays, sample.startDelay * MILLISECONDS)
		table.insert(frames, sample.frames)
		loaded += sample.loaded and 1 or 0
	end

	local costMedian: number, costHigh: number, costWorst: number = Job.summary(costs)
	local delayMedian: number, delayHigh: number, delayWorst: number = Job.summary(delays)
	local frameMedian: number, frameHigh: number, frameWorst: number = Job.summary(frames)

	local cost: string = `{math.round(costMedian)}, p95 {math.round(costHigh)}, worst {math.round(costWorst)}`
	local delay: string = `{Job.fixed(delayMedian)}, p95 {Job.fixed(delayHigh)}, worst {Job.fixed(delayWorst)}`
	local moved: string = `{frameMedian}, p95 {frameHigh}, worst {frameWorst}`

	return table.concat({
		`{label}: play call in microseconds median {cost}`,
		`start delay in ms median {delay}`,
		`frames until TimePosition moves median {moved}`,
		`loaded at the call {loaded} of {#samples}`,
	}, "; ")
end

-- Each Heartbeat interval and Stats.FrameTime, in milliseconds, over a span
local function span(seconds: number): ({ number }, { number })
	local beats: { number } = {}
	local frames: { number } = {}
	local deadline: number = os.clock() + seconds

	while os.clock() < deadline do
		table.insert(beats, RunService.Heartbeat:Wait() * MILLISECONDS)
		table.insert(frames, Stats.FrameTime * MILLISECONDS)
	end

	return beats, frames
end

-- The sound memory tags, read only once memory tracking is on, since the read gives 0 without it
local function memory(): string
	if not Stats.MemoryTrackingEnabled then
		return "memory unread, since Stats.MemoryTrackingEnabled is false"
	end

	local held: number = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Sounds)
	local streaming: number = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.StreamingSounds)

	return `Sounds {Job.fixed(held)} MB, StreamingSounds {Job.fixed(streaming)} MB`
end

local function spanLine(label: string, beats: { number }, frames: { number }): string
	local beatMedian: number, beatHigh: number = Job.summary(beats)
	local frameMedian: number, frameHigh: number = Job.summary(frames)
	local beat: string = `{Job.fixed(beatMedian)}, p95 {Job.fixed(beatHigh)}`
	local frame: string = `{Job.fixed(frameMedian)}, p95 {Job.fixed(frameHigh)}`

	return `{label}: Heartbeat interval in ms median {beat}; FrameTime in ms median {frame}; {memory()}`
end

--[[
    b1: in each Mode, 2D and positioned, PLAYS plays round-robin over the
    one-shots, each id preloaded and played once before timing starts
--]]

function Bench.b1(job: Job): (Verdict, string)
	local tree: Echo.Element, refs: { Echo.Ref<Handle?> } = sounds(ONE_SHOTS, {})
	job:await(Echo.preload(), PRELOAD_SECONDS, "the preload")

	for _, mode: Mode in MODES do
		local root: Echo.Root = job:own(Echo:root(nil, tree, mode))
		local handles: { Handle } = handlesOf(job, refs, mode)

		for index: number, handle: Handle in handles do
			local voice: Voice, instance: Playing = job:play(handle, nil, `{mode} warm-up of id {index}`)
			job:wait(function (): boolean
				return instance.TimePosition > 0
			end, LOAD_SECONDS, `{mode} warm-up of id {index} to start playing`)

			handle:stop(voice)
		end

		for _, positioned: boolean in { false, true } do
			local samples: { Sample } = {}
			for play: number = 1, PLAYS do
				local handle: Handle = handles[(play - 1) % #handles + 1]
				local overrides: Echo.Overrides? = nil
				if positioned then
					overrides = { at = Scene.ahead(DISTANCE) }
				end

				table.insert(samples, measure(job, handle, overrides, `{mode} play {play}`))
			end

			local kind: string = positioned and "positioned" or "2D"
			job:line(report(`{mode} {kind}, {PLAYS} plays`, samples))
		end

		root:destroy()
	end

	return "DONE", ""
end

--[[
    b2: before any other job of a new play session, a preload over the ids
    kept for it, then the first play of each, half in each Mode, measured
    as b1 measures
--]]

function Bench.b2(job: Job): (Verdict, string)
	if job.ran > 0 then
		job:fail(`b2 runs first in a new play session, and {job.ran} jobs ran before it`)
	end

	local tree: Echo.Element, refs: { Echo.Ref<Handle?> } = sounds(FIRST_PLAYS, {})
	job:await(Echo.preload(), PRELOAD_SECONDS, "the preload")

	-- Each Mode plays its own half, so every play is the first of its id
	local half: number = #FIRST_PLAYS // #MODES
	for modeIndex: number, mode: Mode in MODES do
		local root: Echo.Root = job:own(Echo:root(nil, tree, mode))
		local handles: { Handle } = handlesOf(job, refs, mode)
		local samples: { Sample } = {}

		for index: number = (modeIndex - 1) * half + 1, modeIndex * half do
			local sample: Sample = measure(job, handles[index], nil, `{mode} first play of id {index}`)
			table.insert(samples, sample)
			job:line(report(`{mode} first play of {FIRST_PLAYS[index]}`, { sample }))
		end

		job:line(report(`{mode}, {#samples} first plays`, samples))
		root:destroy()
	end

	return "DONE", ""
end

--[[
    b3: in each Mode, a quiet span, then VOICES looping voices, half 2D and
    half in the world within RADIUS studs of the camera, for a busy span,
    each span's frame figures and sound memory recorded
--]]

function Bench.b3(job: Job): (Verdict, string)
	local tree: Echo.Element, refs: { Echo.Ref<Handle?> } = sounds(LOOPS, { Looped = true })
	local random: Random = Random.new(SEED)
	job:await(Echo.preload(), PRELOAD_SECONDS, "the preload")

	for _, mode: Mode in MODES do
		local root: Echo.Root = job:own(Echo:root(nil, tree, mode))
		local handles: { Handle } = handlesOf(job, refs, mode)
		local origin: Vector3 = (Workspace.CurrentCamera :: Camera).CFrame.Position

		-- The first half plays in 2D and the second at points made ahead of the timing
		local placed: { [number]: Echo.Overrides } = {}
		for index: number = VOICES // 2 + 1, VOICES do
			placed[index] = { at = origin + random:NextUnitVector() * random:NextNumber(0, RADIUS) }
		end

		local quietBeats: { number }, quietFrames: { number } = span(QUIET_SECONDS)
		job:line(spanLine(`{mode} quiet for {QUIET_SECONDS} s`, quietBeats, quietFrames))

		local missed: number = 0
		local started: number = os.clock()
		for index: number = 1, VOICES do
			local voice: Voice? = handles[(index - 1) % #handles + 1]:play(placed[index])
			missed += voice and 0 or 1
		end

		local took: number = (os.clock() - started) * MILLISECONDS
		job:line(`{mode}: started {VOICES - missed} of {VOICES} looping voices in {Job.fixed(took)} ms`)

		local busyBeats: { number }, busyFrames: { number } = span(BUSY_SECONDS)
		job:line(spanLine(`{mode} with {VOICES} voices for {BUSY_SECONDS} s`, busyBeats, busyFrames))

		for _, handle: Handle in handles do
			handle:stop()
		end

		root:destroy()
	end

	return "DONE", ""
end

--[[
    b4: in each Mode, one id preloaded, played once and let end, held by
    nothing for IDLE_SECONDS, then played again, measured as b1 measures
--]]

function Bench.b4(job: Job): (Verdict, string)
	local ended: { [Voice]: boolean } = {}
	local tree: Echo.Element, refs: { Echo.Ref<Handle?> } = sounds(IDLE_PLAYS, {
		[Echo.Event.Ended] = function (voice: Voice)
			ended[voice] = true
		end,
	})

	job:await(Echo.preload(), PRELOAD_SECONDS, "the preload")

	-- The roots go once their plays end, so nothing of Echo's holds an id through the idle
	for index: number, mode: Mode in MODES do
		local root: Echo.Root = job:own(Echo:root(nil, tree, mode))
		local handle: Handle = handlesOf(job, refs, mode)[index]
		local voice: Voice = job:play(handle, nil, `the {mode} first play of {IDLE_PLAYS[index]}`)

		job:wait(function (): boolean
			return ended[voice] == true
		end, ENDED_SECONDS, `the {mode} first play of {IDLE_PLAYS[index]} to end`)

		root:destroy()
	end

	job:line(`each id played once and ended; nothing holds them for {IDLE_SECONDS} s`)
	task.wait(IDLE_SECONDS)

	for index: number, mode: Mode in MODES do
		local root: Echo.Root = job:own(Echo:root(nil, tree, mode))
		local handle: Handle = handlesOf(job, refs, mode)[index]
		local sample: Sample = measure(job, handle, nil, `the {mode} play after the idle`)

		job:line(report(`{mode} play of {IDLE_PLAYS[index]} after {IDLE_SECONDS} s held by nothing`, { sample }))
		root:destroy()
	end

	return "DONE", ""
end

return Bench
