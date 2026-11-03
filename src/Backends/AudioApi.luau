--[[
    The Audio API backend: a voice is an Attachment holding an AudioPlayer
    and an AudioEmitter, wired from the player through its effects to the
    emitter, its bus's fader or Echo's own AudioDeviceOutput
--]]

--!strict
local SoundService = game:GetService("SoundService")

local Constants = require(script.Parent.Parent.Constants)
local Legacy = require(script.Parent.Legacy)
local Properties = require(script.Parent.Properties)
local RollOff = require(script.Parent.RollOff)
local Types = require(script.Parent.Parent.Types)

-- A voice's emitter starts on a legacy Sound's own roll-off
local DEFAULT_CURVE: { [number]: number } =
	RollOff.points(Constants.ROLL_OFF_MODE, Constants.ROLL_OFF_MIN_DISTANCE, Constants.ROLL_OFF_MAX_DISTANCE)

type Backend = Types.Backend
type Bus = Types.Bus
type VoiceEvents = Types.VoiceEvents

-- The three legacy properties the emitter's curve is built from, by their own names
type Curve = {
	RollOffMode: Enum.RollOffMode,
	RollOffMinDistance: number,
	RollOffMaxDistance: number,
}

type Effect = {
	instance: Instance,
	key: string,
	priority: number, -- Orders the chain, highest first, since no Audio API effect has a Priority
	written: { [string]: boolean }, -- Each property a play set since the last clear
}

type Voice = {
	player: AudioPlayer,
	emitter: AudioEmitter,
	wires: { Wire }, -- The Wire out of each stage of the chain, the player's first
	chain: { Effect }, -- In wiring order
	effects: { [string]: Effect }, -- By class, then key
	output: Instance?, -- Where the chain ends, nil while the voice is unrouted
	curve: Curve?, -- What apply wrote to the curve since the last clear, nil while the template's holds
	live: boolean, -- From Echo's play to its stop, pause or a natural end; an Ended outside it is ignored
	loops: number, -- Since the last play
	events: VoiceEvents?, -- The callbacks connect holds, whose playing a play calls
	applied: { [string]: boolean }, -- Each mapped element property apply wrote since the last clear
}

-- Each voice's state, by its tree, dropped when the pool destroys the tree
local Voices: { [Attachment]: Voice } = {}

local Output: AudioDeviceOutput? = nil -- Echo's own output in SoundService's Echo folder, found or made by setup

local AudioApi = {}

--[[
    Puts a mapped property at a legacy Sound's default, so an element that
    never sets it sounds the same in both Modes, or at the player's own
    default where the player refuses the legacy value
--]]

local function resetToLegacy(player: AudioPlayer, property: string, mapped: string)
	local legacy: any = Properties.read(Properties.probe("Sound"), property)
	if not pcall(Properties.write, player, mapped, legacy) then
		Properties.write(player, mapped, Properties.read(Properties.probe("AudioPlayer"), mapped))
	end
end

--[[
    The reason one of the curve's three properties refuses a value, or nil
--]]

local function curveRefusal(property: string, value: any): string?
	if property == "RollOffMode" then
		if typeof(value) == "EnumItem" and value.EnumType == Enum.RollOffMode then
			return nil
		end

		return `RollOffMode takes an Enum.RollOffMode item, not {typeof(value)} {value}`
	elseif type(value) == "number" and value >= 0 and value < math.huge then
		return nil
	end

	return `{property} takes a distance of 0 or more studs, not {typeof(value)} {value}`
end

--[[
    A voice's state, made the first time Echo meets its tree, whose
    children still carry the names the template gave them
--]]

local function voiceOf(tree: Attachment): Voice
	local known: Voice? = Voices[tree]
	if known then
		return known
	end

	local player = tree:FindFirstChild("AudioPlayer") :: AudioPlayer?
	local emitter = tree:FindFirstChild("AudioEmitter") :: AudioEmitter?
	local wire = tree:FindFirstChild("Wire") :: Wire?

	if not player or not emitter or not wire then
		error(
			`{tree:GetFullName()} lacks its AudioPlayer, AudioEmitter or Wire, so it is no clone of AudioApi.template()`,
			3
		)
	end

	local voice: Voice = {
		player = player,
		emitter = emitter,
		wires = { wire },
		chain = {},
		effects = {},
		output = nil,
		curve = nil,
		live = false,
		loops = 0,
		events = nil,
		applied = {},
	}

	Voices[tree] = voice

	-- Disconnected by the tree's own destruction, which is when the pool removes an idle voice
	tree.Destroying:Once(function ()
		Voices[tree] = nil
	end)

	return voice
end

local function halt(voice: Voice)
	voice.live = false
	voice.player:Stop()
end

--[[
    Wires the player through its effects, highest Priority first and then
    by key, to its output. Both ends of every Wire are set each time, so no
    Wire keeps an end from before
--]]

local function rewire(tree: Attachment, voice: Voice)
	table.sort(voice.chain, function (first: Effect, second: Effect): boolean
		if first.priority ~= second.priority then
			return first.priority > second.priority
		elseif first.key ~= second.key then
			return first.key < second.key
		end

		return first.instance.ClassName < second.instance.ClassName
	end)

	local stages: { Instance } = { voice.player }
	for _, effect: Effect in voice.chain do
		table.insert(stages, effect.instance)
	end

	for index: number, source: Instance in stages do
		local wire: Wire? = voice.wires[index]
		if not wire then
			local created: Wire = Instance.new("Wire")
			created.Parent = tree
			table.insert(voice.wires, created)
			wire = created
		end

		local target: Instance? = stages[index + 1] or voice.output
		local found: Wire = wire :: Wire
		found.SourceInstance = source
		found.TargetInstance = target :: any -- Nil leaves an unrouted voice with no output
	end
end

--[[
    Finds or makes SoundService's Echo folder, which the legacy backend
    shares, and the one AudioDeviceOutput in it that a 2D voice with no bus
    plays to
--]]

function AudioApi.setup()
	Legacy.setup()

	local folder = SoundService:FindFirstChild(Constants.FOLDER_NAME) :: Instance
	local output = folder:FindFirstChild("AudioDeviceOutput") :: AudioDeviceOutput?

	if not output then
		local created: AudioDeviceOutput = Instance.new("AudioDeviceOutput")
		created.Parent = folder
		output = created
	end

	Output = output
end

--[[
    The tree the pool clones for each voice: an Attachment holding an
    AudioPlayer on a legacy Sound's defaults, an AudioEmitter on its curve
    and a Wire out of the player that ends nowhere, archivable and unparented
--]]

function AudioApi.template(): Attachment
	local tree: Attachment = Instance.new("Attachment")

	local player: AudioPlayer = Instance.new("AudioPlayer")
	for property: string, mapped: string in Constants.AUDIO_API_PROPERTIES do
		resetToLegacy(player, property, mapped)
	end

	player.Parent = tree

	local emitter: AudioEmitter = Instance.new("AudioEmitter")
	emitter:SetDistanceAttenuation(DEFAULT_CURVE)
	emitter.Parent = tree

	local wire: Wire = Instance.new("Wire")
	wire.SourceInstance = player
	wire.Parent = tree

	return tree
end

function AudioApi.playable(tree: Attachment): Sound | AudioPlayer
	return voiceOf(tree).player
end

--[[
    The reason Audio API mode refuses a sound property, or nil. It takes
    only the properties it maps to the player and the three the curve is
    built from, each value checked as a legacy Sound would take it
--]]

function AudioApi.check(property: string, value: any): string?
	if Constants.CURVE_PROPERTIES[property] then
		if value == nil then
			return nil
		end

		return curveRefusal(property, value)
	elseif not Constants.AUDIO_API_PROPERTIES[property] then
		return `Audio API mode takes no {property}, which an AudioPlayer has nothing to map to`
	end

	return Legacy.check(property, value)
end

--[[
    The reason Audio API mode refuses a property of a child effect of a
    legacy effect class, or nil: the legacy class must take it, and its
    Audio API class must have a property of the same name, but for Priority,
    which orders the chain
--]]

function AudioApi.checkEffect(className: string, property: string, value: any): string?
	local reason: string? = Legacy.checkEffect(className, property, value)
	if reason or property == "Priority" then
		return reason
	end

	local mapped: string = Constants.EFFECTS[className]
	if not pcall(Properties.read, Properties.probe(mapped), property) then
		return `{mapped} has no {property} for {className}'s to reach`
	end

	return nil
end

--[[
    Writes one property to the voice, warning and returning false when it
    refuses the value. The three roll-off properties rebuild the emitter's
    curve from all three
--]]

function AudioApi.apply(tree: Attachment, property: string, value: any): boolean
	local voice: Voice = voiceOf(tree)

	local target: string? = Constants.AUDIO_API_PROPERTIES[property]
	if target then
		if not Properties.assign(voice.player, target, value) then
			return false
		end

		voice.applied[property] = true

		return true
	elseif not Constants.CURVE_PROPERTIES[property] then
		warn(`Echo left {property}, which Audio API mode does not take`)
		return false
	end

	local reason: string? = curveRefusal(property, value)
	if reason then
		warn(`Echo left {property}: {reason}`)
		return false
	end

	local curve: Curve = voice.curve
		or {
			RollOffMode = Constants.ROLL_OFF_MODE,
			RollOffMinDistance = Constants.ROLL_OFF_MIN_DISTANCE,
			RollOffMaxDistance = Constants.ROLL_OFF_MAX_DISTANCE,
		}

	Properties.write(curve, property, value)
	voice.curve = curve

	-- A play writes the three in any order, so a min not yet below its max waits for the other end
	if curve.RollOffMinDistance < curve.RollOffMaxDistance then
		voice.emitter:SetDistanceAttenuation(
			RollOff.points(curve.RollOffMode, curve.RollOffMinDistance, curve.RollOffMaxDistance)
		)
	end

	return true
end

--[[
    Adds the matching Audio API effect to the chain the first time the
    voice plays one of this class and key, then on every play enables it,
    sets its properties and rewires the chain in Priority order
--]]

function AudioApi.effect(tree: Attachment, className: string, key: string, properties: { [string]: any })
	local voice: Voice = voiceOf(tree)
	local id: string = `{className}/{key}`

	local effect: Effect? = voice.effects[id]
	if not effect then
		local instance = (Instance.new :: any)(Constants.EFFECTS[className]) :: Instance
		instance.Name = key
		instance.Parent = tree

		effect = { instance = instance, key = key, priority = 0, written = {} }
		voice.effects[id] = effect
		table.insert(voice.chain, effect :: Effect)
	end

	local found: Effect = effect :: Effect
	Properties.write(found.instance, "Bypass", false)

	for property: string, value: any in properties do
		if property ~= "Priority" then
			if Properties.assign(found.instance, property, value) then
				found.written[property] = true
			end
		elseif type(value) == "number" then
			found.priority = value
		else
			warn(`Echo left {className}.Priority, which refused {typeof(value)} {value}: it takes a number`)
		end
	end

	rewire(tree, voice)
end

--[[
    The chain of a world voice ends at its emitter, in its bus's interaction
    group when it has one, and a 2D voice's at its bus's fader or Echo's
    own output
--]]

function AudioApi.route(tree: Attachment, bus: Bus?, world: boolean)
	local voice: Voice = voiceOf(tree)
	local output: AudioDeviceOutput? = Output

	if not output then
		error("AudioApi.route ran before AudioApi.setup made Echo's AudioDeviceOutput", 2)
	end

	voice.output = world and voice.emitter or (bus and bus.fader or output)
	voice.emitter.AudioInteractionGroup = world and bus and bus.interactionGroup or ""

	rewire(tree, voice)
end

function AudioApi.place(tree: Attachment, position: Vector3)
	tree.WorldPosition = position
end

--[[
    Restarts the player, since its Play never rewinds, then tells the
    connected element. An Ended its own Stop gives is ignored
--]]

function AudioApi.play(tree: Attachment)
	local voice: Voice = voiceOf(tree)
	local player: AudioPlayer = voice.player

	halt(voice)

	player.TimePosition = 0
	player:Play()
	voice.live = true
	voice.loops = 0

	local events: VoiceEvents? = voice.events
	if events then
		events.playing()
	end
end

function AudioApi.stop(tree: Attachment)
	halt(voiceOf(tree))
end

-- A player's Stop keeps its TimePosition, so a pause is a stop and a resume is a play
function AudioApi.pause(tree: Attachment)
	halt(voiceOf(tree))
end

function AudioApi.resume(tree: Attachment)
	local voice: Voice = voiceOf(tree)
	voice.player:Play()
	voice.live = true
end

--[[
    Connects an element's callbacks to the voice until the returned
    disconnect runs, which is safe to call twice. Ended reaches it once per
    natural end and never after Echo's own stop, Looped with the loops
    counted since the last play, and Loaded when the player turns ready, or
    through a defer when it already is
--]]

function AudioApi.connect(tree: Attachment, events: VoiceEvents): () -> ()
	local voice: Voice = voiceOf(tree)
	local player: AudioPlayer = voice.player
	local connected: boolean = true

	voice.events = events

	local connections: { RBXScriptConnection } = {
		-- A deferred Ended can arrive after a new play, which the player playing again gives away
		player.Ended:Connect(function ()
			if connected and voice.live and not player.IsPlaying then
				voice.live = false
				events.ended()
			end
		end),

		player.Looped:Connect(function ()
			if connected and voice.live then
				voice.loops += 1
				events.looped(voice.loops)
			end
		end),

		player:GetPropertyChangedSignal("IsReady"):Connect(function ()
			if connected and player.IsReady then
				events.loaded()
			end
		end),
	}

	if player.IsReady then
		task.defer(function ()
			if connected then
				events.loaded()
			end
		end)
	end

	return function ()
		if not connected then
			return
		end

		connected = false
		if voice.events == events then
			voice.events = nil
		end

		for _, connection: RBXScriptConnection in connections do
			connection:Disconnect()
		end
	end
end

--[[
    Stops the voice and puts it back as the template left it: no asset or
    attributes, its effects bypassed with their defaults, no output, its
    emitter on the template's curve in no interaction group, and every
    property a play wrote back to the template's value
--]]

function AudioApi.clear(tree: Attachment)
	local voice: Voice = voiceOf(tree)
	local player: AudioPlayer = voice.player

	halt(voice)

	for property: string in voice.applied do
		resetToLegacy(player, property, Constants.AUDIO_API_PROPERTIES[property])
	end

	table.clear(voice.applied)

	if voice.curve then
		voice.emitter:SetDistanceAttenuation(DEFAULT_CURVE)
		voice.curve = nil
	end

	player.Asset = ""
	for name: string in player:GetAttributes() do
		player:SetAttribute(name, nil)
	end

	for _, effect: Effect in voice.chain do
		Properties.write(effect.instance, "Bypass", true)
		effect.priority = 0

		local effectDefaults: Instance = Properties.probe(effect.instance.ClassName)
		for property: string in effect.written do
			Properties.write(effect.instance, property, Properties.read(effectDefaults, property))
		end

		table.clear(effect.written)
	end

	voice.output = nil
	voice.emitter.AudioInteractionGroup = ""
	rewire(tree, voice)
end

local Backend: Backend = AudioApi

return Backend
