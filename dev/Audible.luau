--[[
    The audible test, with Mike listening: every role of the stand-in set in
    turn under its caption, in Audio API mode with Acoustic Simulation on and
    then off, and the same sequence in Legacy mode to compare by ear
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Echo = require(ReplicatedStorage.Packages.Echo)

local Config = require(script.Parent.Config)
local Job = require(script.Parent.Job)

local ONE_SHOTS: { string } = Config.recordings.oneShots
local RAPID_FIRE: { string } = Config.recordings.rapidFire
local FOOTSTEPS: { string } = Config.recordings.footsteps
local LOOPS: { string } = Config.recordings.loops
local INTERFACE: { string } = Config.recordings.interface
local BUS: string = Config.bus.name
local TOLERANCE: number = Config.tolerance
local SETTLE_SECONDS: number = Config.deadlines.settle
local WALL_FORWARD: number = Config.audible.wall.forward
local WALL_RIGHT: number = Config.audible.wall.right
local OPEN_FORWARD: number = Config.audible.open.forward
local OPEN_RIGHT: number = Config.audible.open.right
local BEHIND_FORWARD: number = Config.audible.behind.forward
local BEHIND_RIGHT: number = Config.audible.behind.right
local STEPS_FORWARD: number = Config.audible.footsteps.forward
local STEPS_FROM: number = Config.audible.footsteps.from
local STEPS_TO: number = Config.audible.footsteps.to
local STEP_SECONDS: number = Config.audible.footsteps.stepSeconds
local WALK_SPEED: number = Config.audible.footsteps.walkSpeed
local RAPID_GROUP: string = Config.audible.rapidFire.group
local RAPID_LIMIT: number = Config.audible.rapidFire.limit
local RAPID_SIGNAL: string = Config.audible.rapidFire.signal
local RAPID_FIRES: number = Config.audible.rapidFire.fires
local RAPID_SECONDS: number = Config.audible.rapidFire.seconds
local LISTEN_SECONDS: number = Config.audible.listen
local GAP_SECONDS: number = Config.audible.gap
local RAPID_HOLD: number = Config.audible.rapidHold
local LOOP_VOLUME: number = Config.audible.loopVolume
local LOOP_HOLD: number = Config.audible.loopHold
local CROSSFADE_SECONDS: number = Config.audible.crossfade
local INTERFACE_GAP: number = Config.audible.interfaceGap
local DECIBELS: number = 20 -- Decibels in a tenfold rise of amplitude

type Handle = Echo.Handle
type Job = Job.Job
type Mode = Echo.Mode
type Run = Job.Run
type Verdict = Job.Verdict

-- The loudest level the bus's analyzer read while each world one-shot played
type Levels = { open: number, behind: number }

local Audible: { [string]: Run } = {}

-- The camera's view now, turned level, which every position in a pass is set from
local function view(): CFrame
	local camera: CFrame = (Workspace.CurrentCamera :: Camera).CFrame
	local look: Vector3 = Vector3.new(camera.LookVector.X, 0, camera.LookVector.Z)

	-- A camera looking straight down has no level look of its own
	if look.Magnitude < TOLERANCE then
		look = -Vector3.zAxis
	end

	return CFrame.lookAt(camera.Position, camera.Position + look.Unit)
end

local function place(frame: CFrame, right: number, forward: number): Vector3
	return frame * Vector3.new(right, 0, -forward)
end

-- The loudest RmsLevel the analyzer reads over the seconds
local function loudest(analyzer: AudioAnalyzer, seconds: number): number
	local peak: number = 0
	local deadline: number = os.clock() + seconds
	while os.clock() < deadline do
		RunService.Heartbeat:Wait()
		peak = math.max(peak, analyzer.RmsLevel)
	end

	return peak
end

local function decibels(value: number, reference: number): string
	if value <= 0 or reference <= 0 then
		return "silent"
	end

	return `{string.format("%.1f", DECIBELS * math.log10(value / reference))} dB`
end

-- A sound on the bus, with a ref that receives its handle
local function onBus(id: string, ref: Echo.Ref<Handle?>, props: Echo.Props): Echo.Element
	local given: Echo.Props = table.clone(props)
	given.SoundId = id
	given.Ref = ref
	given[Echo.Util.Bus] = BUS

	return Echo.createElement("Sound", given)
end

--[[
    Plays the whole sequence once in a Mode, every sound on the bus, and
    gives back its root, signal and wall when it ends. The wall stands
    between the camera and the sounds set behind it, and the levels are the
    bus's, which only Audio API voices reach
--]]

local function pass(job: Job, mode: Mode, label: string): Levels
	local analyzer: AudioAnalyzer = job.scene.analyzer
	local wall: Part = job.scene.wall
	local frame: CFrame = view()

	wall.CFrame = frame * CFrame.new(WALL_RIGHT, 0, -WALL_FORWARD)
	wall.Parent = Workspace

	local function removeWall()
		wall.Parent = nil
	end

	job:own(removeWall)

	local styles: { [string]: Echo.State<number> }, crossfade: Echo.SpringApi = Echo.useSpring(function ()
		return { first = LOOP_VOLUME, second = 0 }
	end)

	local elements: { Echo.Element } = {}
	local function add(id: string, props: Echo.Props): Echo.Ref<Handle?>
		local ref: Echo.Ref<Handle?> = Echo.createRef()
		table.insert(elements, onBus(id, ref, props))

		return ref
	end

	local function list(ids: { string }, props: Echo.Props): { Echo.Ref<Handle?> }
		local refs: { Echo.Ref<Handle?> } = {}
		for _, id: string in ids do
			table.insert(refs, add(id, props))
		end

		return refs
	end

	local shotRef: Echo.Ref<Handle?> = add(ONE_SHOTS[1], {})
	local worldRef: Echo.Ref<Handle?> = add(ONE_SHOTS[2], {})
	local rapidRefs: { Echo.Ref<Handle?> } = list(RAPID_FIRE, { [Echo.Util.Cap] = RAPID_GROUP })
	local stepRefs: { Echo.Ref<Handle?> } = list(FOOTSTEPS, {})
	local firstLoopRef: Echo.Ref<Handle?> = add(LOOPS[1], { Looped = true, Volume = styles.first })
	local secondLoopRef: Echo.Ref<Handle?> = add(LOOPS[2], { Looped = true, Volume = styles.second })
	local interfaceRefs: { Echo.Ref<Handle?> } = list(INTERFACE, {})

	local root: Echo.Root = job:own(Echo:root(nil, Echo.createElement(Echo.Fragment, elements), mode))

	local function handleOf(ref: Echo.Ref<Handle?>, what: string): Handle
		return job:need(ref.current, `{label} handle for {what}`)
	end

	local function handlesOf(refs: { Echo.Ref<Handle?> }, what: string): { Handle }
		local handles: { Handle } = {}
		for index: number, ref: Echo.Ref<Handle?> in refs do
			handles[index] = handleOf(ref, `{what} {index}`)
		end

		return handles
	end

	-- 1) A 2D one-shot
	local shot: Handle = handleOf(shotRef, "the 2D one-shot")
	job:caption(`{label}: a 2D one-shot`)
	job:play(shot, nil, "the 2D one-shot")
	task.wait(LISTEN_SECONDS)
	shot:stop()
	task.wait(GAP_SECONDS)

	-- 2) A world one-shot ahead in the open, and 3) the same behind the wall
	local world: Handle = handleOf(worldRef, "the world one-shot")
	job:caption(`{label}: a world one-shot ahead, in the open`)
	job:play(world, { at = place(frame, OPEN_RIGHT, OPEN_FORWARD) }, "the world one-shot in the open")
	local open: number = loudest(analyzer, LISTEN_SECONDS)
	world:stop()
	task.wait(GAP_SECONDS)

	job:caption(`{label}: the same one-shot behind the wall`)
	job:play(world, { at = place(frame, BEHIND_RIGHT, BEHIND_FORWARD) }, "the world one-shot behind the wall")
	local behind: number = loudest(analyzer, LISTEN_SECONDS)
	world:stop()
	task.wait(GAP_SECONDS)

	-- 4) Rapid fire, a signal fired into a cap group shared by both takes
	local rapid: { Handle } = handlesOf(rapidRefs, "rapid fire")
	local fired: number = 0
	local disconnect: () -> () = Echo.createSignal(RAPID_SIGNAL, function ()
		fired += 1
		rapid[(fired - 1) % #rapid + 1]:play()
	end)

	local function removeSignal()
		disconnect()
		Echo.removeSignal(RAPID_SIGNAL)
	end

	job:own(removeSignal)
	job:caption(`{label}: rapid fire, {RAPID_FIRES} fires in {RAPID_SECONDS} s into a cap group of {RAPID_LIMIT}`)

	local most: number = 0
	for _ = 1, RAPID_FIRES do
		Echo.useSignal(RAPID_SIGNAL)

		local live: number = 0
		for _, handle: Handle in rapid do
			live += #handle:getAll()
		end

		most = math.max(most, live)
		task.wait(RAPID_SECONDS / RAPID_FIRES)
	end

	job:line(`{label}: at most {most} rapid-fire voices played at once, under a cap of {RAPID_LIMIT}`)
	task.wait(RAPID_HOLD)

	for _, handle: Handle in rapid do
		handle:stop()
	end

	removeSignal()
	task.wait(GAP_SECONDS)

	-- 5) Footsteps at a walking pace, passing behind the wall
	local steps: { Handle } = handlesOf(stepRefs, "footstep")
	local stride: number = WALK_SPEED * STEP_SECONDS
	local count: number = math.floor((STEPS_TO - STEPS_FROM) / stride) + 1

	job:caption(`{label}: footsteps at a walking pace, passing behind the wall`)
	for step: number = 1, count do
		local point: Vector3 = place(frame, STEPS_FROM + (step - 1) * stride, STEPS_FORWARD)
		job:play(steps[(step - 1) % #steps + 1], { at = point }, `footstep {step}`)
		task.wait(STEP_SECONDS)
	end

	task.wait(GAP_SECONDS)

	-- 6) A loop crossfading into the other through useSpring
	local firstLoop: Handle = handleOf(firstLoopRef, "the first loop")
	local secondLoop: Handle = handleOf(secondLoopRef, "the second loop")

	job:caption(`{label}: a loop crossfading into the other over {CROSSFADE_SECONDS} s`)
	job:play(firstLoop, nil, "the first loop")
	job:play(secondLoop, nil, "the second loop")
	task.wait(LOOP_HOLD)

	local fading: any = crossfade:start({ first = 0, second = LOOP_VOLUME, config = { duration = CROSSFADE_SECONDS } })
	local function cancelFade()
		fading:cancel()
	end

	job:own(cancelFade)
	job:await(fading, CROSSFADE_SECONDS + SETTLE_SECONDS, "the crossfade")
	task.wait(LOOP_HOLD)
	firstLoop:stop()
	secondLoop:stop()
	task.wait(GAP_SECONDS)

	-- 7) Interface sounds through the bus
	job:caption(`{label}: interface sounds through the bus`)
	for index: number, interface: Handle in handlesOf(interfaceRefs, "interface sound") do
		job:play(interface, nil, `interface sound {index}`)
		task.wait(INTERFACE_GAP)
	end

	task.wait(GAP_SECONDS)
	job:caption(`{label}: done`)

	root:destroy()
	removeWall()

	return { open = open, behind = behind }
end

--[[
    The Audio API pass with Acoustic Simulation on, then with it turned off
    at runtime, recording what SoundService reads after each change and how
    loud the bus heard the open and the walled one-shot
--]]

function Audible.audible(job: Job): (Verdict, string)
	local original: boolean = SoundService.AcousticSimulationEnabled
	local function restore()
		SoundService.AcousticSimulationEnabled = original
	end

	job:own(restore)

	local findings: { string } = {}
	for _, enabled: boolean in { true, false } do
		SoundService.AcousticSimulationEnabled = enabled

		local reads: boolean = SoundService.AcousticSimulationEnabled
		local state: string = enabled and "on" or "off"
		local finding: string = `set {state} at runtime, SoundService reads {reads}`
		job:line(`Acoustic Simulation {finding}`)

		local levels: Levels = pass(job, "AudioApi", `Audio API, Acoustic Simulation {state}`)
		local heard: string =
			`open {string.format("%.4f", levels.open)}, behind the wall {string.format("%.4f", levels.behind)}`
		local walled: string = decibels(levels.behind, levels.open)
		job:line(`Acoustic Simulation {state}: loudest RmsLevel on the bus {heard}, the wall {walled} from the open`)

		table.insert(findings, `{state}: {finding}, the wall {walled}`)
	end

	return "DONE", table.concat(findings, "; ")
end

--[[
    The same sequence in Legacy mode, which Acoustic Simulation never
    reaches, to compare with the Audio API pass by ear
--]]

function Audible.audibleLegacy(job: Job): (Verdict, string)
	pass(job, "Legacy", "Legacy")

	return "DONE", ""
end

return Audible
