--[[
    The live run's thirteen jobs, each proving in the dev place what the
    Lune suite's fakes cannot show, in both Modes where a Mode applies, and
    the two reports Mike reads: an id that never loads, and the curves
--]]

--!strict
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Echo = require(ReplicatedStorage.Packages.Echo)

local Config = require(script.Parent.Config)
local Job = require(script.Parent.Job)
local Scene = require(script.Parent.Scene)

local ONE_SHOTS: { string } = Config.recordings.oneShots
local LOOPS: { string } = Config.recordings.loops
local NEVER_LOADS: string = Config.recordings.neverLoads
local DEFAULT_MODE: string = Config.mode
local POOL_SIZE: number = Config.pool.initial
local LOAD_SECONDS: number = Config.deadlines.load
local PRELOAD_SECONDS: number = Config.deadlines.preload
local ENDED_SECONDS: number = Config.deadlines.ended
local CHARACTER_SECONDS: number = Config.deadlines.character
local SETTLE_SECONDS: number = Config.deadlines.settle
local DISTANCE: number = Config.distance
local TOLERANCE: number = Config.tolerance
local PRIORITY_COUNT: number = Config.preload.priority
local OTHER_COUNT: number = Config.preload.others
local ENGINE_CUT: number = Config.engine.cut
local ENGINE_SEEK: number = Config.engine.seek
local ENDED_MARGIN: number = Config.engine.endedMargin
local ENGINE_CURVE: { [number]: number } = Config.engine.curve
local CUT: number = Config.cut
local FADE_SECONDS: number = Config.fade.seconds
local FADE_TOLERANCE: number = Config.fade.tolerance
local RESTART_CUT: number = Config.restart.cut
local RESTART_MAX: number = Config.restart.maxDistance
local HIGH_GAIN: number = Config.effects.highGain
local NEVER_WATCH: number = Config.neverLoadsWatch
local CURVES_BUS: string = Config.curves.bus
local CURVES_GROUP: string = Config.curves.interactionGroup
local CURVE_MIN: number = Config.curves.min
local CURVE_MAX: number = Config.curves.max
local CURVE_DISTANCES: { number } = Config.curves.distances
local CURVE_VOLUME: number = Config.curves.volume
local CURVE_SETTLE: number = Config.curves.settle
local CURVE_WINDOW: number = Config.curves.window
local MILLISECONDS: number = 1000 -- In a second
local DECIBELS: number = 20 -- Decibels in a tenfold rise of amplitude

local MODES: { Echo.Mode } = { "Legacy", "AudioApi" }

-- Each legacy RollOffMode beside the emitter preset that stands for it
local ROLL_OFFS: { RollOff } = {
	{ mode = Enum.RollOffMode.Inverse, preset = Enum.DistanceAttenuationMode.Inverse },
	{ mode = Enum.RollOffMode.Linear, preset = Enum.DistanceAttenuationMode.Linear },
	{ mode = Enum.RollOffMode.LinearSquare, preset = Enum.DistanceAttenuationMode.LinearSquared },
	{ mode = Enum.RollOffMode.InverseTapered, preset = Enum.DistanceAttenuationMode.InverseTapered },
}

type Handle = Echo.Handle
type Job = Job.Job
type Mode = Echo.Mode
type Playing = Job.Playing
type RollOff = { mode: Enum.RollOffMode, preset: Enum.DistanceAttenuationMode }
type Run = Job.Run
type Verdict = Job.Verdict
type Voice = Echo.Voice

local Checks: { [string]: Run } = {}

--[[
    Mounts a root the job gives back. A Legacy root takes the default Mode,
    so only an Audio API root names its own
--]]

local function mount(job: Job, target: Instance | string | nil, element: Echo.Element, mode: Mode): Echo.Root
	local named: Mode? = mode ~= DEFAULT_MODE and mode or nil

	return job:own(Echo:root(target, element, named))
end

-- A fragment of one sound for each id
local function sounds(ids: { string }): Echo.Element
	local elements: { Echo.Element } = {}
	for _, id: string in ids do
		table.insert(elements, Echo.createElement("Sound", { SoundId = id }))
	end

	return Echo.createElement(Echo.Fragment, elements)
end

local function moving(job: Job, instance: Playing, what: string)
	job:wait(function (): boolean
		return instance.TimePosition > 0
	end, LOAD_SECONDS, `{what} to start playing`)
end

--[[
    Whether a voice is heard in the world: a legacy Sound under its
    Attachment, or an AudioPlayer whose chain ends at its emitter
--]]

local function heardInWorld(instance: Playing): boolean
	local parent: Instance? = instance.Parent
	if not parent then
		return false
	elseif instance:IsA("Sound") then
		return parent:IsA("Attachment")
	end

	local emitter: AudioEmitter? = parent:FindFirstChildOfClass("AudioEmitter")
	for _, child: Instance in parent:GetChildren() do
		if child:IsA("Wire") and (child :: Wire).TargetInstance == emitter then
			return true
		end
	end

	return false
end

--[[
    The Attachment a world voice plays under, failing the job unless the
    voice sits under one and that tree is a child of the scene's voices
--]]

local function attachmentOf(job: Job, instance: Playing, what: string): Attachment
	local parent: Instance? = instance.Parent
	if not parent or not parent:IsA("Attachment") then
		job:fail(`{instance:GetFullName()} sits under no Attachment, where a world voice plays`)
	end

	local tree: Attachment = parent :: Attachment
	local voices: Folder = job.scene.voices
	local home: Instance? = tree.Parent
	local where: string = home and home:GetFullName() or "nothing"
	job:expect(home == voices, `{what}'s tree is a child of {voices:GetFullName()}, reading {where}`)

	return tree
end

-- An analyzer's mean RmsLevel over the window, once the level has settled
local function level(analyzer: AudioAnalyzer): number
	task.wait(CURVE_SETTLE)

	local total: number, count: number = 0, 0
	local deadline: number = os.clock() + CURVE_WINDOW
	while os.clock() < deadline do
		RunService.Heartbeat:Wait()
		total += analyzer.RmsLevel
		count += 1
	end

	return count > 0 and total / count or 0
end

local function decibels(value: number, reference: number): string
	if value <= 0 or reference <= 0 then
		return "silent"
	end

	return `{string.format("%.1f", DECIBELS * math.log10(value / reference))} dB`
end

--[[
    1. Echo sits where a game's install puts it, configure ran at boot, and
    each Mode's pool reads 0 in use of its initial size, with every voice
    tree of both pools in the scene's voices and none under Terrain
--]]

function Checks.link(job: Job): (Verdict, string)
	local module: Instance? = ReplicatedStorage.Packages:FindFirstChild("Echo")
	job:expect(module ~= nil and module:IsA("ModuleScript"), "Echo is the ModuleScript ReplicatedStorage.Packages.Echo")

	local refused: string? = job.configureError
	if refused then
		job:fail(`Echo.configure refused the configuration at boot: {refused}`)
	end

	job:line("ok: Echo.configure ran at boot")

	local voices: Folder = job.scene.voices
	for _, mode: Mode in MODES do
		local count: Echo.CacheCount = Echo.getCache(mode)
		job:expect(count.inUse == 0 and count.size == POOL_SIZE, `{mode} reads {count.inUse} in use of {count.size}`)

		-- Each of the Mode's voices is a tree in the scene's folder, an Attachment holding its player
		local className: string = mode == "AudioApi" and "AudioPlayer" or "Sound"
		local trees: number = 0
		for _, child: Instance in voices:GetChildren() do
			if child:IsA("Attachment") and child:FindFirstChildOfClass(className) then
				trees += 1
			end
		end

		job:expect(
			trees == POOL_SIZE,
			`{voices:GetFullName()} holds {trees} Attachments holding a {className}, of {POOL_SIZE} {mode} voices`
		)
	end

	-- Terrain is where the voices would live had configure been given no parent
	local strays: number = 0
	for _, descendant: Instance in Workspace.Terrain:GetDescendants() do
		local holdsVoice: boolean = descendant:FindFirstChildOfClass("Sound") ~= nil
			or descendant:FindFirstChildOfClass("AudioPlayer") ~= nil

		if descendant:IsA("Attachment") and holdsVoice then
			strays += 1
		end
	end

	job:expect(strays == 0, `Workspace.Terrain holds {strays} Attachments holding a Sound or an AudioPlayer`)

	return "PASS", `Echo is linked and configured, and both Modes read 0 in use of {POOL_SIZE} in {voices.Name}`
end

--[[
    2. One preload with a priority root and the ids played only as
    overrides: it returns at once, resolves with exactly the id that never
    loads once that id's wait ends, and its holders join Echo's folder the
    priority root's first. Every other id's holder then reads ready, and in
    each Mode a priority sound and an override take read ready at the play.
    Holders last the session, so the job runs before any other preload
--]]

function Checks.preload(job: Job): (Verdict, string)
	local overridesFrom: number = PRIORITY_COUNT + OTHER_COUNT + 1
	local priority: { string } = table.move(ONE_SHOTS, 1, PRIORITY_COUNT, 1, {})
	local others: { string } = table.move(ONE_SHOTS, PRIORITY_COUNT + 1, overridesFrom - 1, 1, {})
	local overrides: { string } = table.move(ONE_SHOTS, overridesFrom, #ONE_SHOTS, 1, {})
	local take: string = overrides[1] -- Played only as a SoundId override
	table.insert(overrides, NEVER_LOADS)

	-- The other root's sounds are made first, so only the priority can put its ids ahead in the pass
	mount(job, nil, sounds(others), DEFAULT_MODE :: Mode)

	-- The priority tree's first sound hands its handle to the ref, for the plays after the pass
	local priorityRef: Echo.Ref<Handle?> = Echo.createRef()
	local priorityTree: Echo.Element = Echo.createElement(Echo.Fragment, {
		Echo.createElement("Sound", { SoundId = priority[1], Ref = priorityRef }),
		sounds(table.move(priority, 2, #priority, 1, {})),
	})

	local priorityRoot: Echo.Root = mount(job, nil, priorityTree, DEFAULT_MODE :: Mode)
	local priorityHandle: Handle = job:need(priorityRef.current, `{DEFAULT_MODE} priority handle`)

	-- configure made the folder at boot, so every holder the pass makes joins it
	local folder = job:need(SoundService:FindFirstChild("Echo") :: Folder?, "Echo's folder under SoundService")

	-- Each holder's place in the order the AudioPlayers joined the folder
	local order: { [string]: number } = {}
	local arrivals: number = 0
	job:own(folder.ChildAdded:Connect(function (child: Instance)
		if child:IsA("AudioPlayer") and not order[child.Name] then
			arrivals += 1
			order[child.Name] = arrivals
		end
	end))

	local started: number = os.clock()
	local promise: any = Echo.preload({ priorityRoot }, overrides)
	local returned: number = (os.clock() - started) * MILLISECONDS
	local status: string = promise:getStatus()

	job:expect(status == "Started", `preload returned in {Job.fixed(returned)} ms with its Promise {status}`)

	local failed: { string } = job:await(promise, PRELOAD_SECONDS, "the preload Promise")
	local listed: string = table.concat(failed, ", ")
	job:line(`the Promise settled {Job.fixed(os.clock() - started)} s after the call`)
	job:expect(#failed == 1 and failed[1] == NEVER_LOADS, `the Promise resolved with the ids that failed: {listed}`)

	local lastPriority: number = 0
	for _, id: string in priority do
		local arrival: number = job:need(order[id], `holder joining Echo's folder for the priority id {id}`)
		lastPriority = math.max(lastPriority, arrival)
	end

	local firstOther: number = math.huge
	for _, list: { string } in { others, overrides } do
		for _, id: string in list do
			firstOther = math.min(firstOther, order[id] or math.huge)
		end
	end

	job:expect(
		lastPriority < firstOther,
		`the priority holders joined the folder by arrival {lastPriority}, the rest from {firstOther}`
	)

	-- Each id that loads stays held, ready, after the pass
	local unready: { string } = {}
	for _, list: { string } in { priority, others, overrides } do
		for _, id: string in list do
			if id ~= NEVER_LOADS then
				local holder = job:need(folder:FindFirstChild(id) :: AudioPlayer?, `holder for {id} in Echo's folder`)
				if not holder.IsReady then
					table.insert(unready, id)
				end
			end
		end
	end

	local notReady: string = #unready == 0 and "none" or table.concat(unready, ", ")
	job:expect(#unready == 0, `every holder but the one that never loads reads IsReady; not ready: {notReady}`)

	-- A voice switched to a held id reads ready at the play, which is what holding is for
	for _, mode: Mode in MODES do
		local handle: Handle = priorityHandle
		if mode ~= DEFAULT_MODE then
			mount(job, nil, priorityTree, mode)
			handle = job:need(priorityRef.current, `{mode} priority handle`)
		end

		local voice: Voice, instance: Playing = job:play(handle, nil, `the {mode} priority sound`)
		local ready: boolean = Job.loaded(instance)
		handle:stop(voice)
		job:expect(ready, `the {mode} priority sound's {instance.ClassName} read ready at the play`)

		local taken: Voice, takenInstance: Playing = job:play(handle, { SoundId = take }, `the {mode} override take`)
		local takeReady: boolean = Job.loaded(takenInstance)
		handle:stop(taken)
		job:expect(takeReady, `the {mode} override take's {takenInstance.ClassName} read ready at the play`)
	end

	local failedOnly: string = "failed only the id that never loads"
	local held: string = "held the priority first and every other id ready"
	return "PASS", `preload returned at once, {failedOnly}, {held}, and both Modes played held ids ready`
end

--[[
    3. One description plays in both Modes: a 2D one-shot, a world one-shot
    at a point ahead of the camera and a loop. Each instance plays, the
    world one-shot's tree in the scene's voices, a one-shot's Ended runs
    once with its voice back, and a loop's Looped runs before handle:stop
    ends it
--]]

function Checks.playback(job: Job): (Verdict, string)
	local ended: { [Voice]: number } = {}
	local backInEnded: { [Voice]: boolean } = {}
	local loops: { [Voice]: number } = {}
	local shotRef: Echo.Ref<Handle?> = Echo.createRef()
	local loopRef: Echo.Ref<Handle?> = Echo.createRef()

	-- A short take looped, so its Looped runs within seconds
	local tree: Echo.Element = Echo.createElement(Echo.Fragment, {
		Echo.createElement("Sound", {
			SoundId = ONE_SHOTS[1],
			Ref = shotRef,
			[Echo.Event.Ended] = function (voice: Voice)
				ended[voice] = (ended[voice] or 0) + 1
				backInEnded[voice] = voice.instance == nil
			end,
		}),
		Echo.createElement("Sound", {
			SoundId = ONE_SHOTS[1],
			Looped = true,
			Ref = loopRef,
			[Echo.Event.Looped] = function (voice: Voice, count: number)
				loops[voice] = count
			end,
		}),
	})

	for _, mode: Mode in MODES do
		local root: Echo.Root = mount(job, nil, tree, mode)
		local shot: Handle = job:need(shotRef.current, `{mode} one-shot's handle`)
		local loop: Handle = job:need(loopRef.current, `{mode} loop's handle`)
		local className: string = mode == "AudioApi" and "AudioPlayer" or "Sound"

		local function oneShot(at: Vector3?, what: string)
			local overrides: Echo.Overrides? = nil
			if at then
				overrides = { at = at }
			end

			local voice: Voice, instance: Playing = job:play(shot, overrides, what)
			job:expect(instance:IsA(className), `{what} plays on a {instance.ClassName}`)
			job:expect(heardInWorld(instance) == (at ~= nil), `{what} is heard in the world: {at ~= nil}`)

			if at then
				local position: Vector3 = attachmentOf(job, instance, what).WorldPosition
				job:expect((position - at).Magnitude <= TOLERANCE, `{what} sits at its point, {DISTANCE} studs out`)
			end

			moving(job, instance, what)
			job:wait(function (): boolean
				return (ended[voice] or 0) >= 1
			end, ENDED_SECONDS, `{what}'s Ended`)

			-- Watched a little longer, for an Ended that runs twice
			task.wait(SETTLE_SECONDS)
			local once: boolean = ended[voice] == 1 and backInEnded[voice] == true and voice.instance == nil
			job:expect(once, `{what}'s Ended ran once, with its voice back in the pool`)
		end

		oneShot(nil, `the {mode} 2D one-shot`)
		oneShot(Scene.ahead(DISTANCE), `the {mode} world one-shot`)

		local looping: Voice, looper: Playing = job:play(loop, nil, `the {mode} loop`)
		job:expect(looper:IsA(className), `the {mode} loop plays on a {looper.ClassName}`)
		moving(job, looper, `the {mode} loop`)
		job:wait(function (): boolean
			return (loops[looping] or 0) >= 1
		end, ENDED_SECONDS, `the {mode} loop's Looped`)

		loop:stop(looping)
		job:expect(looping.instance == nil, `the {mode} loop looped, and handle:stop gave its voice back`)

		root:destroy()
	end

	return "PASS", "one description played a 2D one-shot, a world one-shot and a loop in both Modes"
end

--[[
    4. The five engine behaviors the fakes assume, each on instances the job
    makes and gives back
--]]

function Checks.engine(job: Job): (Verdict, string)
	local scene: Scene.Scene = job.scene

	local sound: Sound = job:own(Instance.new("Sound"))
	sound.SoundId = ONE_SHOTS[1]
	sound.Parent = scene.folder

	job:wait(function (): boolean
		return sound.IsLoaded
	end, LOAD_SECONDS, "the Sound to load")

	sound:Play()
	job:wait(function (): boolean
		return sound.TimePosition >= ENGINE_CUT
	end, LOAD_SECONDS, `the Sound to play {ENGINE_CUT} s`)

	sound:Stop()
	job:expect(sound.TimePosition == 0, `Sound:Stop() sets TimePosition to 0, reading {sound.TimePosition}`)

	sound.TimePosition = ENGINE_SEEK
	sound:Play()
	job:expect(
		sound.TimePosition >= ENGINE_SEEK,
		`Sound:Play() keeps the {ENGINE_SEEK} s a script set, reading {sound.TimePosition}`
	)
	RunService.Heartbeat:Wait()
	job:expect(sound.TimePosition >= ENGINE_SEEK, `and still reads {Job.fixed(sound.TimePosition)} s on the next frame`)
	sound:Stop()

	local player: AudioPlayer = job:own(Instance.new("AudioPlayer"))
	player.Asset = ONE_SHOTS[1]
	player.Parent = scene.folder

	local link: Wire = job:own(Instance.new("Wire"))
	link.SourceInstance = player
	link.TargetInstance = scene.output
	link.Parent = scene.folder

	job:wait(function (): boolean
		return player.IsReady
	end, LOAD_SECONDS, "the AudioPlayer to load")

	local endings: number = 0
	job:own(player.Ended:Connect(function ()
		endings += 1
	end))

	player:Play()
	job:wait(function (): boolean
		return player.TimePosition >= ENGINE_CUT
	end, LOAD_SECONDS, `the AudioPlayer to play {ENGINE_CUT} s`)

	player:Stop()

	-- Watched past where the asset would have ended
	task.wait(player.TimeLength + ENDED_MARGIN)
	job:expect(endings == 0, `AudioPlayer:Stop() fires no Ended, which fired {endings} times`)

	local emitter: AudioEmitter = job:own(Instance.new("AudioEmitter"))
	local attenuation: Enum.DistanceAttenuationMode = emitter.DistanceAttenuationMode
	job:expect(
		attenuation == Enum.DistanceAttenuationMode.Custom,
		`a new AudioEmitter's DistanceAttenuationMode is Custom, reading {attenuation.Name}`
	)

	emitter:SetDistanceAttenuation(ENGINE_CURVE)
	local copy = job:own(emitter:Clone()) :: AudioEmitter
	local given: { [number]: number } = emitter:GetDistanceAttenuation()
	local copied: { [number]: number } = copy:GetDistanceAttenuation()

	local points: number = 0
	local kept: boolean = true
	for distance: number, volume: number in given do
		points += 1
		kept = kept and copied[distance] ~= nil and math.abs(copied[distance] - volume) <= TOLERANCE
	end

	for distance: number in copied do
		kept = kept and given[distance] ~= nil
	end

	job:expect(points > 0 and kept, `a cloned AudioEmitter keeps every one of its {points} curve points`)

	return "PASS", "the five engine behaviors the fakes assume hold"
end

--[[
    5. An element's Loaded runs once when a pooled voice plays an asset
    already preloaded, in each Mode
--]]

function Checks.loaded(job: Job): (Verdict, string)
	local loads: { [Voice]: number } = {}
	local ref: Echo.Ref<Handle?> = Echo.createRef()
	local element: Echo.Element = Echo.createElement("Sound", {
		SoundId = ONE_SHOTS[1],
		Ref = ref,
		[Echo.Event.Loaded] = function (voice: Voice)
			loads[voice] = (loads[voice] or 0) + 1
		end,
	})

	job:await(Echo.preload(), PRELOAD_SECONDS, "the preload")

	for _, mode: Mode in MODES do
		local root: Echo.Root = mount(job, nil, element, mode)
		local handle: Handle = job:need(ref.current, `{mode} handle`)
		local voice: Voice, instance: Playing = job:play(handle, nil, `the {mode} preloaded one-shot`)

		job:line(`{mode}: the asset read loaded at the play: {Job.loaded(instance)}`)
		job:wait(function (): boolean
			return (loads[voice] or 0) >= 1
		end, LOAD_SECONDS, `the {mode} Loaded callback`)

		-- Watched a little longer, for a Loaded that runs twice
		task.wait(SETTLE_SECONDS)
		job:expect(loads[voice] == 1, `the {mode} Loaded callback ran {loads[voice]} times`)

		handle:stop(voice)
		root:destroy()
	end

	return "PASS", "Loaded ran once for a pooled voice playing a preloaded asset, in both Modes"
end

--[[
    6. A root on a Part plays a one-shot from a tree in the scene's voices,
    the Part is destroyed mid-play, and the voice plays on to its natural
    end at the Part's last position
--]]

function Checks.outlives(job: Job): (Verdict, string)
	local ended: { [Voice]: number } = {}
	local ref: Echo.Ref<Handle?> = Echo.createRef()
	local element: Echo.Element = Echo.createElement("Sound", {
		SoundId = ONE_SHOTS[1],
		Ref = ref,
		[Echo.Event.Ended] = function (voice: Voice)
			ended[voice] = (ended[voice] or 0) + 1
		end,
	})

	for _, mode: Mode in MODES do
		local part: Part = job:own(Scene.part(Scene.ahead(DISTANCE)))
		local root: Echo.Root = mount(job, part, element, mode)
		local handle: Handle = job:need(ref.current, `{mode} handle`)
		local voice: Voice, instance: Playing = job:play(handle, nil, `the {mode} voice on the Part`)
		local attachment: Attachment = attachmentOf(job, instance, `the {mode} voice on the Part`)

		job:wait(function (): boolean
			return instance.TimePosition >= CUT
		end, LOAD_SECONDS, `the {mode} voice on the Part to play {CUT} s`)

		local last: Vector3 = part.Position
		part:Destroy()

		-- Read only while the voice is out, since its Attachment is parked once it is back
		local drift: number = 0
		job:wait(function (): boolean
			if voice.instance then
				drift = math.max(drift, (attachment.WorldPosition - last).Magnitude)
			end

			return (ended[voice] or 0) >= 1
		end, ENDED_SECONDS, `the {mode} voice to end after its Part was destroyed`)

		job:expect(
			drift <= TOLERANCE,
			`the {mode} voice played at the Part's last position, {Job.fixed(drift)} studs off`
		)

		task.wait(SETTLE_SECONDS)
		job:expect(ended[voice] == 1, `the {mode} voice played on to its natural end, its Ended once`)

		root:destroy()
	end

	return "PASS", "a voice outlived its destroyed Part at the Part's last position, in both Modes"
end

--[[
    7. A first-person one-shot plays from a 2D root while the character holds a
    Tool, and plays on to its end once the Tool is destroyed
--]]

function Checks.unequip(job: Job): (Verdict, string)
	job:wait(function (): boolean
		return Players.LocalPlayer.Character ~= nil
	end, CHARACTER_SECONDS, "the character")

	local character: Model = job:need(Players.LocalPlayer.Character, "character")
	local ended: { [Voice]: number } = {}
	local ref: Echo.Ref<Handle?> = Echo.createRef()
	local element: Echo.Element = Echo.createElement("Sound", {
		SoundId = ONE_SHOTS[1],
		Ref = ref,
		[Echo.Event.Ended] = function (voice: Voice)
			ended[voice] = (ended[voice] or 0) + 1
		end,
	})

	for _, mode: Mode in MODES do
		local tool: Tool = job:own(Scene.tool(character))
		local root: Echo.Root = mount(job, nil, element, mode)
		local handle: Handle = job:need(ref.current, `{mode} handle`)
		local voice: Voice, instance: Playing = job:play(handle, nil, `the {mode} first-person one-shot`)

		job:expect(not heardInWorld(instance), `the {mode} first-person one-shot plays in 2D`)
		job:wait(function (): boolean
			return instance.TimePosition >= CUT
		end, LOAD_SECONDS, `the {mode} first-person one-shot to play {CUT} s`)

		tool:Destroy()
		job:wait(function (): boolean
			return (ended[voice] or 0) >= 1
		end, ENDED_SECONDS, `the {mode} first-person one-shot to end after the Tool was destroyed`)

		task.wait(SETTLE_SECONDS)
		job:expect(ended[voice] == 1, `the {mode} first-person one-shot played on to its end, its Ended once`)

		root:destroy()
	end

	return "PASS", "a first-person voice played on after its Tool was destroyed, in both Modes"
end

--[[
    8. handle:stop with a fade lowers the voice's Volume over about the fade
    and gives it back, and a second stop during a fade gives it back at
    once
--]]

function Checks.fade(job: Job): (Verdict, string)
	local ref: Echo.Ref<Handle?> = Echo.createRef()

	-- Looped, so no natural end comes before the fade's
	local element: Echo.Element = Echo.createElement("Sound", { SoundId = ONE_SHOTS[1], Looped = true, Ref = ref })

	for _, mode: Mode in MODES do
		local root: Echo.Root = mount(job, nil, element, mode)
		local handle: Handle = job:need(ref.current, `{mode} handle`)
		local voice: Voice, instance: Playing = job:play(handle, nil, `the {mode} voice to fade`)
		moving(job, instance, `the {mode} voice to fade`)

		local from: number = instance.Volume
		local fell: boolean = false
		local started: number = os.clock()
		handle:stop(voice, FADE_SECONDS)

		job:wait(function (): boolean
			if voice.instance then
				local now: number = instance.Volume
				fell = fell or (now < from and now > 0)
			end

			return voice.instance == nil
		end, FADE_SECONDS + SETTLE_SECONDS, `the {mode} faded voice to come back`)

		local took: number = os.clock() - started
		job:expect(fell, `the {mode} voice's Volume fell between {from} and 0 during the fade`)
		job:expect(math.abs(took - FADE_SECONDS) <= FADE_TOLERANCE, `the {mode} voice came back {Job.fixed(took)} s on`)

		local again: Voice, againInstance: Playing = job:play(handle, nil, `the {mode} voice stopped twice`)
		moving(job, againInstance, `the {mode} voice stopped twice`)
		handle:stop(again, FADE_SECONDS)

		job:wait(function (): boolean
			return againInstance.Volume < from
		end, FADE_SECONDS, `the {mode} second voice's fade to begin`)

		job:expect(again.instance ~= nil, `the {mode} second voice is still fading`)
		handle:stop(again, FADE_SECONDS)
		job:expect(again.instance == nil, `a second stop during the {mode} fade gave the voice back at once`)

		root:destroy()
	end

	return "PASS", `a fade of {FADE_SECONDS} s gave its voice back on time, and a second stop at once, in both Modes`
end

--[[
    9. In Audio API mode a second play of an element restarts from 0, and a
    play overriding SoundId and RollOffMaxDistance sets the AudioPlayer's
    Asset and an emitter curve ending at that distance
--]]

function Checks.restart(job: Job): (Verdict, string)
	local ref: Echo.Ref<Handle?> = Echo.createRef()
	local root: Echo.Root =
		mount(job, nil, Echo.createElement("Sound", { SoundId = ONE_SHOTS[1], Ref = ref }), "AudioApi")
	local handle: Handle = job:need(ref.current, "Audio API handle")

	local first: Voice, firstInstance: Playing = job:play(handle, nil, "the first play")
	job:wait(function (): boolean
		return firstInstance.TimePosition >= RESTART_CUT
	end, LOAD_SECONDS, `the first play to pass {RESTART_CUT} s`)

	handle:stop(first)
	job:line(`after its voice went back, the AudioPlayer reads TimePosition {Job.fixed(firstInstance.TimePosition)}`)

	local second: Voice, secondInstance: Playing = job:play(handle, nil, "the second play")
	job:line(`the second play took {secondInstance == firstInstance and "the same" or "another"} AudioPlayer`)
	job:expect(
		secondInstance.TimePosition < RESTART_CUT,
		`the second play starts from 0, at {Job.fixed(secondInstance.TimePosition)}`
	)
	RunService.Heartbeat:Wait()
	job:expect(
		secondInstance.TimePosition < RESTART_CUT,
		`and reads {Job.fixed(secondInstance.TimePosition)} s a frame on`
	)
	handle:stop(second)

	local overridden: string = ONE_SHOTS[2]
	local overrides: Echo.Overrides =
		{ SoundId = overridden, RollOffMaxDistance = RESTART_MAX, at = Scene.ahead(DISTANCE) }
	local third: Voice, thirdInstance: Playing = job:play(handle, overrides, "the play with overrides")
	job:expect(thirdInstance:IsA("AudioPlayer"), `the play with overrides plays on a {thirdInstance.ClassName}`)

	local player: AudioPlayer = thirdInstance :: AudioPlayer
	job:expect(player.Asset == overridden, `the SoundId override set the AudioPlayer's Asset to {player.Asset}`)

	local tree: Instance = job:need(player.Parent, "voice's Attachment")
	local emitter: AudioEmitter =
		job:need(tree:FindFirstChildOfClass("AudioEmitter"), "AudioEmitter beside the voice's AudioPlayer")
	local curve: { [number]: number } = emitter:GetDistanceAttenuation()

	local farthest: number = 0
	for distance: number in curve do
		farthest = math.max(farthest, distance)
	end

	local endsThere: boolean = math.abs(farthest - RESTART_MAX) <= TOLERANCE and (curve[farthest] or 1) <= TOLERANCE
	job:expect(
		endsThere,
		`the RollOffMaxDistance override's curve ends at {Job.fixed(farthest)} studs, at {curve[farthest]}`
	)

	handle:stop(third)
	root:destroy()

	return "PASS", `a second play restarted from 0, and the overrides set the Asset and a curve ending at {RESTART_MAX}`
end

--[[
    10. An element with an EqualizerSoundEffect child plays in both Modes
    with the effect on and set on its voice, and the voice comes back with
    it off
--]]

function Checks.effects(job: Job): (Verdict, string)
	local ref: Echo.Ref<Handle?> = Echo.createRef()
	local element: Echo.Element = Echo.createElement("Sound", { SoundId = ONE_SHOTS[1], Ref = ref }, {
		Equalizer = Echo.createElement("EqualizerSoundEffect", { HighGain = HIGH_GAIN }),
	})

	for _, mode: Mode in MODES do
		local root: Echo.Root = mount(job, nil, element, mode)
		local handle: Handle = job:need(ref.current, `{mode} handle`)
		local voice: Voice, instance: Playing = job:play(handle, nil, `the {mode} voice with an effect`)
		local tree: Instance = job:need(instance.Parent, `{mode} voice's parent`)

		-- A legacy effect sits under its Sound, and an Audio API one beside the player, each named by its key
		local holder: Instance = mode == "Legacy" and instance or tree
		local effect: Instance = job:need(holder:FindFirstChild("Equalizer"), `{mode} Equalizer effect`)

		if mode == "Legacy" then
			job:expect(effect:IsA("EqualizerSoundEffect"), `the Legacy effect is an {effect.ClassName}`)

			local equalizer: EqualizerSoundEffect = effect :: EqualizerSoundEffect
			local set: boolean = equalizer.Enabled and math.abs(equalizer.HighGain - HIGH_GAIN) <= TOLERANCE
			job:expect(set, `the Legacy EqualizerSoundEffect is on with HighGain {equalizer.HighGain}`)

			handle:stop(voice)
			job:expect(not equalizer.Enabled, "the Legacy voice came back with its EqualizerSoundEffect off")
		else
			job:expect(effect:IsA("AudioEqualizer"), `the Audio API effect is an {effect.ClassName}`)

			local equalizer: AudioEqualizer = effect :: AudioEqualizer
			local set: boolean = not equalizer.Bypass and math.abs(equalizer.HighGain - HIGH_GAIN) <= TOLERANCE
			job:expect(set, `the AudioEqualizer has Bypass off with HighGain {equalizer.HighGain}`)

			local player: Instance = instance
			local into: boolean, out: boolean = false, false
			for _, child: Instance in tree:GetChildren() do
				if child:IsA("Wire") then
					local link: Wire = child :: Wire
					into = into or (link.SourceInstance == player and link.TargetInstance == equalizer)
					out = out or (link.SourceInstance == equalizer and link.TargetInstance ~= nil)
				end
			end

			job:expect(into and out, "the AudioEqualizer sits in the chain between the player and its output")

			handle:stop(voice)
			job:expect(equalizer.Bypass, "the Audio API voice came back with its AudioEqualizer bypassed")
		end

		root:destroy()
	end

	return "PASS", "an EqualizerSoundEffect child reached its voice and went off with it, in both Modes"
end

--[[
    11. After the jobs above, each Mode's pool reads 0 in use of its
    initial size
--]]

function Checks.count(job: Job): (Verdict, string)
	for _, mode: Mode in MODES do
		local count: Echo.CacheCount = Echo.getCache(mode)
		job:expect(count.inUse == 0 and count.size == POOL_SIZE, `{mode} reads {count.inUse} in use of {count.size}`)
	end

	return "PASS", `both Modes read 0 in use of {POOL_SIZE}`
end

--[[
    12. A report: a one-shot on the id that never loads, watched for
    NEVER_WATCH seconds in each Mode, shows whether its voice stays out or
    comes back
--]]

function Checks.neverLoads(job: Job): (Verdict, string)
	local ref: Echo.Ref<Handle?> = Echo.createRef()
	local element: Echo.Element = Echo.createElement("Sound", { SoundId = NEVER_LOADS, Ref = ref })
	local handles: { [Mode]: Handle } = {}
	local voices: { [Mode]: Voice } = {}

	for _, mode: Mode in MODES do
		mount(job, nil, element, mode)
		handles[mode] = job:need(ref.current, `{mode} handle`)
		voices[mode] = job:need(handles[mode]:play(), `{mode} voice on the id that never loads`)
	end

	local back: { [Mode]: number } = {}
	local returned: number = 0
	local started: number = os.clock()
	local deadline: number = started + NEVER_WATCH
	while os.clock() < deadline and returned < #MODES do
		RunService.Heartbeat:Wait()

		for mode: Mode, voice: Voice in voices do
			if voice.instance == nil and not back[mode] then
				back[mode] = os.clock() - started
				returned += 1
			end
		end
	end

	local findings: { string } = {}
	for _, mode: Mode in MODES do
		local after: number? = back[mode]
		local finding: string = after and `came back after {Job.fixed(after)} s` or `stayed out for {NEVER_WATCH} s`
		job:line(`{mode}: the voice on the id that never loads {finding}`)
		table.insert(findings, `{mode} {finding}`)

		handles[mode]:stop()
		job:line(`{mode}: after a stop, the pool reads {Echo.getCache(mode).inUse} in use`)
	end

	job:line(`the engine reports AssetFetchStatus {ContentProvider:GetAssetFetchStatus(NEVER_LOADS).Name} for it`)

	return "DONE", table.concat(findings, "; ")
end

--[[
    13. A report: for each RollOffMode, Echo's sampled curve beside the
    emitter's preset, each heard at five distances through an AudioAnalyzer
    on a listener of the job's own, given in decibels from the nearest
--]]

function Checks.curves(job: Job): (Verdict, string)
	local origin: Vector3 = (Workspace.CurrentCamera :: Camera).CFrame.Position
	local id: string = LOOPS[1]

	local ear: Attachment = job:own(Instance.new("Attachment"))
	ear.Parent = Workspace.Terrain
	ear.WorldPosition = origin

	local listener: AudioListener = Instance.new("AudioListener")
	listener.AudioInteractionGroup = CURVES_GROUP
	listener.Parent = ear

	local analyzer: AudioAnalyzer = Instance.new("AudioAnalyzer")
	analyzer.Parent = ear

	local heard: Wire = Instance.new("Wire")
	heard.SourceInstance = listener
	heard.TargetInstance = analyzer
	heard.Parent = ear

	-- The preset's rig plays the same recording at the voice's starting Volume
	local source: Attachment = job:own(Instance.new("Attachment"))
	source.Parent = Workspace.Terrain

	local emitter: AudioEmitter = Instance.new("AudioEmitter")
	emitter.AudioInteractionGroup = CURVES_GROUP
	emitter.DistanceAttenuationBounds = NumberRange.new(CURVE_MIN, CURVE_MAX)
	emitter.Parent = source

	local player: AudioPlayer = Instance.new("AudioPlayer")
	player.Asset = id
	player.Looping = true
	player.Volume = CURVE_VOLUME
	player.Parent = source

	local feed: Wire = Instance.new("Wire")
	feed.SourceInstance = player
	feed.TargetInstance = emitter
	feed.Parent = source

	job:wait(function (): boolean
		return player.IsReady
	end, LOAD_SECONDS, "the preset rig's AudioPlayer to load")

	local ref: Echo.Ref<Handle?> = Echo.createRef()
	for _, rollOff: RollOff in ROLL_OFFS do
		local element: Echo.Element = Echo.createElement("Sound", {
			SoundId = id,
			Looped = true,
			RollOffMode = rollOff.mode,
			RollOffMinDistance = CURVE_MIN,
			RollOffMaxDistance = CURVE_MAX,
			Ref = ref,
			[Echo.Util.Bus] = CURVES_BUS,
		})

		local root: Echo.Root = mount(job, nil, element, "AudioApi")
		local handle: Handle = job:need(ref.current, `{rollOff.mode.Name} handle`)
		emitter.DistanceAttenuationMode = rollOff.preset

		local echoReference: number, presetReference: number = 0, 0
		for index: number, distance: number in CURVE_DISTANCES do
			local point: Vector3 = origin + Vector3.yAxis * distance

			local voice: Voice, instance: Playing = job:play(handle, { at = point }, `Echo's {rollOff.mode.Name} voice`)
			job:wait(function (): boolean
				return Job.loaded(instance)
			end, LOAD_SECONDS, `Echo's {rollOff.mode.Name} voice to load`)

			local echoLevel: number = level(analyzer)
			handle:stop(voice)

			source.WorldPosition = point
			player.TimePosition = 0
			player:Play()
			local presetLevel: number = level(analyzer)
			player:Stop()

			if index == 1 then
				echoReference, presetReference = echoLevel, presetLevel
			end

			local echoText: string = `{string.format("%.4f", echoLevel)} ({decibels(echoLevel, echoReference)})`
			local presetText: string = `{string.format("%.4f", presetLevel)} ({decibels(presetLevel, presetReference)})`
			job:line(`{rollOff.mode.Name} at {distance} studs: Echo {echoText}, preset {presetText}`)
		end

		root:destroy()
	end

	return "DONE", `each RollOffMode heard at {#CURVE_DISTANCES} distances, Echo's curve beside the emitter preset`
end

return Checks
