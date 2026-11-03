--[[
    The click jobs, one in each Mode: each click or tap off the panel plays
    the next one-shot, and how long it took from the click until the voice
    moved and was first heard shows on screen at once
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Echo = require(ReplicatedStorage.Packages.Echo)

local Config = require(script.Parent.Config)
local Job = require(script.Parent.Job)

local ONE_SHOTS: { string } = Config.recordings.oneShots
local BUS: string = Config.bus.name
local PRELOAD_SECONDS: number = Config.deadlines.preload
local MAX_FRAMES: number = Config.b1.maxFrames
local CLICKS: number = Config.click.clicks
local CLICK_SECONDS: number = Config.click.seconds
local MILLISECONDS: number = 1000 -- In a second
local MICROSECONDS: number = 1000000 -- In a second

type Handle = Echo.Handle
type Job = Job.Job
type Mode = Echo.Mode
type Playing = Job.Playing
type Run = Job.Run
type Verdict = Job.Verdict
type Voice = Echo.Voice

-- One measured click, each time in seconds from the click
type Sample = {
	cost: number, -- The play call alone
	ready: boolean, -- Whether the voice's instance had its asset ready at the call
	frames: number, -- Heartbeats until TimePosition first moved, read only once it has
	moved: number?, -- Until the Heartbeat at which TimePosition first moved, nil when it did not within MAX_FRAMES
	heard: number?, -- Until the first Heartbeat its level read above 0, nil when it did not or could not be told
	shared: boolean, -- Whether the bus already sounded at the click, so its level could not tell this voice apart
}

local Click: { [string]: Run } = {}

-- A fragment of one sound on the bus for each one-shot, and the refs that receive their handles, in id order
local function sounds(): (Echo.Element, { Echo.Ref<Handle?> })
	local elements: { Echo.Element } = {}
	local refs: { Echo.Ref<Handle?> } = {}

	for _, id: string in ONE_SHOTS do
		local ref: Echo.Ref<Handle?> = Echo.createRef()
		local props: Echo.Props = { SoundId = id, Ref = ref, [Echo.Util.Bus] = BUS }

		table.insert(elements, Echo.createElement("Sound", props))
		table.insert(refs, ref)
	end

	return Echo.createElement(Echo.Fragment, elements), refs
end

--[[
    How loud a click's voice reads now: a Sound's own PlaybackLoudness, or
    for an AudioPlayer the bus analyzer's PeakLevel, which hears the whole
    bus and only Audio API voices
--]]

local function loudness(instance: Playing, analyzer: AudioAnalyzer): number
	if instance:IsA("Sound") then
		return (instance :: Sound).PlaybackLoudness
	end

	return analyzer.PeakLevel
end

--[[
    Follows a click's voice frame by frame, up to MAX_FRAMES, until its
    TimePosition first moves and its level first reads above 0, each timed
    from the click. A legacy Sound's TimePosition moves in steps of about
    22 ms, so a Legacy move reads in those steps
--]]

local function measure(sample: Sample, instance: Playing, analyzer: AudioAnalyzer, clicked: number)
	local frame: number = 0
	while (sample.moved == nil or (sample.heard == nil and not sample.shared)) and frame < MAX_FRAMES do
		RunService.Heartbeat:Wait()
		frame += 1

		local now: number = os.clock()
		if sample.moved == nil and instance.TimePosition > 0 then
			sample.moved = now - clicked
			sample.frames = frame
		end

		if sample.heard == nil and not sample.shared and loudness(instance, analyzer) > 0 then
			sample.heard = now - clicked
		end
	end
end

-- One click's figures, as its caption shows them
local function describe(sample: Sample): string
	local moved: number? = sample.moved
	local heard: number? = sample.heard

	local ready: string = sample.ready and "yes" or "no"
	local call: string = `call {math.round(sample.cost * MICROSECONDS)} µs`

	local move: string = `TimePosition not moved within {MAX_FRAMES} frames`
	if moved then
		move = `TimePosition moved {sample.frames} frames / {Job.fixed(moved * MILLISECONDS)} ms after the click`
	end

	local hear: string = `not heard within {MAX_FRAMES} frames`
	if sample.shared then
		hear = "first heard not told apart, since the bus still sounded at the click"
	elseif heard then
		hear = `first heard {Job.fixed(heard * MILLISECONDS)} ms after the click`
	end

	return `ready at the call {ready}, {call}, {move}, {hear}`
end

-- A figure's median, 95th percentile and worst over the clicks that reached it
local function spread(label: string, values: { number }, total: number, format: (value: number) -> string): string
	if #values == 0 then
		return `{label} reached in none of {total} clicks`
	end

	local median: number, high: number, worst: number = Job.summary(values)

	return `{label} median {format(median)}, p95 {format(high)}, worst {format(worst)} over {#values} of {total}`
end

--[[
    Mounts the one-shots in the Mode and preloads them, then plays the next
    at each left click or touch no GUI took, until CLICKS are measured or
    CLICK_SECONDS pass, each click's figures on screen once they are in
--]]

local function clicks(job: Job, mode: Mode): (Verdict, string)
	local analyzer: AudioAnalyzer = job.scene.analyzer
	local tree: Echo.Element, refs: { Echo.Ref<Handle?> } = sounds()
	local root: Echo.Root = job:own(Echo:root(nil, tree, mode))

	local handles: { Handle } = {}
	for index: number, ref: Echo.Ref<Handle?> in refs do
		handles[index] = job:need(ref.current, `{mode} handle for one-shot {index}`)
	end

	-- A one-shot that failed to load still plays at its click, so the job goes on either way
	local failed: { string } = job:await(Echo.preload({ root }), PRELOAD_SECONDS, "the preload")
	local missed: number = 0
	for _, id: string in failed do
		if table.find(ONE_SHOTS, id) then
			missed += 1
		end
	end

	job:line(`preload: {missed} of the {#ONE_SHOTS} one-shots failed to load`)
	job:caption(`{mode}: click or tap anywhere off the panel, up to {CLICKS} clicks in {CLICK_SECONDS} s`)

	local samples: { Sample } = {}
	local taken: number = 0
	local measuring: boolean = false
	local refusal: string? = nil

	local function take(input: InputObject, processed: boolean)
		local kind: Enum.UserInputType = input.UserInputType
		local pressed: boolean = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
		if processed or not pressed or measuring or refusal ~= nil or taken >= CLICKS then
			return
		end

		taken += 1
		local turn: number = taken
		local index: number = (turn - 1) % #handles + 1
		local handle: Handle = handles[index]

		-- Read before the click's time, so only the play sits between the click and the call's end
		local sounding: boolean = analyzer.PeakLevel > 0

		local clicked: number = os.clock()
		local voice: Voice? = handle:play()
		local cost: number = os.clock() - clicked

		local instance: Playing? = nil
		if voice then
			instance = voice.instance
		end

		if not instance then
			refusal = `click {turn}: the {mode} pool gave no voice for one-shot {index}`
			return
		end

		local playing: Playing = instance
		local sample: Sample = {
			cost = cost,
			ready = Job.loaded(playing),
			frames = 0,
			shared = sounding and not playing:IsA("Sound"),
		}

		measuring = true

		-- Ends within MAX_FRAMES frames, and the job waits for it before it reports
		task.spawn(function ()
			measure(sample, playing, analyzer, clicked)
			table.insert(samples, sample)
			job:caption(`click {turn} of {CLICKS}, {mode}, one-shot {index}: {describe(sample)}`)
			measuring = false
		end)
	end

	local connection: RBXScriptConnection = job:own(UserInputService.InputBegan:Connect(take))

	local deadline: number = os.clock() + CLICK_SECONDS
	while #samples < CLICKS and refusal == nil and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end

	connection:Disconnect()

	local refused: string? = refusal
	if refused then
		job:fail(refused)
	end

	-- One Heartbeat past the measure's own bound, since it may resume after this thread on the same one
	local frame: number = 0
	while measuring and frame <= MAX_FRAMES do
		RunService.Heartbeat:Wait()
		frame += 1
	end

	if measuring then
		job:fail(`the last click's measure ran past {MAX_FRAMES} frames`)
	end

	if #samples == 0 then
		return "DONE", `no click came in {CLICK_SECONDS} s`
	end

	local costs: { number } = {}
	local frames: { number } = {}
	local moves: { number } = {}
	local heards: { number } = {}
	local ready: number = 0

	for _, sample: Sample in samples do
		table.insert(costs, math.round(sample.cost * MICROSECONDS))
		ready += sample.ready and 1 or 0

		local moved: number? = sample.moved
		if moved then
			table.insert(frames, sample.frames)
			table.insert(moves, moved * MILLISECONDS)
		end

		local heard: number? = sample.heard
		if heard then
			table.insert(heards, heard * MILLISECONDS)
		end
	end

	local count: number = #samples
	local summary: string = table.concat({
		`{count} clicks in {mode}`,
		spread("play call in µs", costs, count, tostring),
		spread("frames until TimePosition moved", frames, count, tostring),
		spread("ms until TimePosition moved", moves, count, Job.fixed),
		spread("ms until first heard", heards, count, Job.fixed),
		`ready at the call {ready} of {count}`,
	}, "; ")

	return "DONE", summary
end

--[[
    In Audio API mode, each click first heard on the bus's analyzer
--]]

function Click.click(job: Job): (Verdict, string)
	return clicks(job, "AudioApi")
end

--[[
    In Legacy mode, each click first heard on its own Sound
--]]

function Click.clickLegacy(job: Job): (Verdict, string)
	return clicks(job, "Legacy")
end

return Click
