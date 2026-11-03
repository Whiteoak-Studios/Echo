--[[
    The legacy backend: a voice is an Attachment holding one Sound, heard in
    2D from SoundService's Echo folder or in the world under its Attachment,
    with its effects as SoundEffects under the Sound
--]]

--!strict
local SoundService = game:GetService("SoundService")

local Constants = require(script.Parent.Parent.Constants)
local Properties = require(script.Parent.Properties)
local Types = require(script.Parent.Parent.Types)

type Backend = Types.Backend
type Bus = Types.Bus
type VoiceEvents = Types.VoiceEvents

type Effect = {
	instance: SoundEffect,
	written: { [string]: boolean }, -- Each property a play set since the last clear
}

type Voice = {
	sound: Sound,
	live: boolean, -- From Echo's play to its stop, pause or a natural end; an Ended outside it is ignored
	loops: number, -- Since the last play
	events: VoiceEvents?, -- The callbacks connect holds, whose playing a play calls
	applied: { [string]: boolean }, -- Each property apply wrote since the last clear
	effects: { [string]: Effect }, -- By class, then key
}

-- Each voice's state, by its tree, dropped when the pool destroys the tree
local Voices: { [Attachment]: Voice } = {}

local Folder: Instance? = nil -- SoundService's Echo folder, found or made by setup

local Legacy = {}

--[[
    A voice's state, made the first time Echo meets its tree, when the
    tree's Sound is still under its Attachment as the template left it
--]]

local function voiceOf(tree: Attachment): Voice
	local known: Voice? = Voices[tree]
	if known then
		return known
	end

	local sound = tree:FindFirstChild("Sound") :: Sound?
	if not sound then
		error(`{tree:GetFullName()} holds no Sound, so it is no clone of Legacy.template()`, 3)
	end

	local voice: Voice = {
		sound = sound,
		live = false,
		loops = 0,
		events = nil,
		applied = {},
		effects = {},
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
	voice.sound:Stop()
end

--[[
    Finds or makes the one folder under SoundService a 2D voice's Sound
    plays from, which the Audio API backend's output shares
--]]

function Legacy.setup()
	local folder: Instance? = SoundService:FindFirstChild(Constants.FOLDER_NAME)
	if not folder then
		local created: Folder = Instance.new("Folder")
		created.Name = Constants.FOLDER_NAME
		created.Parent = SoundService
		folder = created
	end

	Folder = folder
end

--[[
    The tree the pool clones for each voice: an Attachment holding one
    Sound, archivable and unparented
--]]

function Legacy.template(): Attachment
	local tree: Attachment = Instance.new("Attachment")
	local sound: Sound = Instance.new("Sound")
	sound.Parent = tree

	return tree
end

function Legacy.playable(tree: Attachment): Sound | AudioPlayer
	return voiceOf(tree).sound
end

--[[
    The reason a legacy Sound refuses a property, or nil. It refuses the
    properties Echo sets itself, any the Sound lacks or cannot write, and a
    value the engine would refuse, a nil value being a state's empty default
--]]

function Legacy.check(property: string, value: any): string?
	if Constants.REFUSED_PROPERTIES[property] then
		return `Echo sets a voice's {property} itself`
	elseif property == "SoundGroup" then
		return "Echo sets a voice's SoundGroup from its element's bus"
	end

	return Properties.refusal(Properties.probe("Sound"), property, value)
end

--[[
    The reason a child effect of a legacy effect class refuses a property,
    or nil, by the same rules as check
--]]

function Legacy.checkEffect(className: string, property: string, value: any): string?
	if not Constants.EFFECTS[className] then
		return `{className} is no effect class Echo takes`
	elseif Constants.EFFECT_REFUSED_PROPERTIES[property] then
		return `Echo sets an effect's {property} itself`
	end

	return Properties.refusal(Properties.probe(className), property, value)
end

--[[
    Writes one property to the voice's Sound, warning and returning false
    when the engine refuses the value
--]]

function Legacy.apply(tree: Attachment, property: string, value: any): boolean
	local voice: Voice = voiceOf(tree)
	if not Properties.assign(voice.sound, property, value) then
		return false
	end

	voice.applied[property] = true

	return true
end

--[[
    Adds the effect under the Sound the first time the voice plays one of
    this class and key, then on every play enables it and sets its
    properties
--]]

function Legacy.effect(tree: Attachment, className: string, key: string, properties: { [string]: any })
	local voice: Voice = voiceOf(tree)
	local id: string = `{className}/{key}`

	local effect: Effect? = voice.effects[id]
	if not effect then
		local instance = (Instance.new :: any)(className) :: SoundEffect
		instance.Name = key
		instance.Parent = voice.sound

		effect = { instance = instance, written = {} }
		voice.effects[id] = effect
	end

	local found: Effect = effect :: Effect
	found.instance.Enabled = true

	for property: string, value: any in properties do
		if Properties.assign(found.instance, property, value) then
			found.written[property] = true
		end
	end
end

--[[
    A 2D voice's Sound plays from SoundService's Echo folder and a world
    voice's from under its Attachment, in its bus's SoundGroup when it has
    one
--]]

function Legacy.route(tree: Attachment, bus: Bus?, world: boolean)
	local sound: Sound = voiceOf(tree).sound
	local folder: Instance? = Folder

	if not world and not folder then
		error("Legacy.route ran before Legacy.setup made SoundService's Echo folder", 2)
	end

	sound.Parent = world and tree or folder
	sound.SoundGroup = bus and bus.group or nil
end

function Legacy.place(tree: Attachment, position: Vector3)
	tree.WorldPosition = position
end

--[[
    Plays from the start, since a Sound plays from the TimePosition a
    script last set, then tells the connected element
--]]

function Legacy.play(tree: Attachment)
	local voice: Voice = voiceOf(tree)
	voice.sound.TimePosition = 0
	voice.sound:Play()
	voice.live = true
	voice.loops = 0

	local events: VoiceEvents? = voice.events
	if events then
		events.playing()
	end
end

function Legacy.stop(tree: Attachment)
	halt(voiceOf(tree))
end

function Legacy.pause(tree: Attachment)
	local voice: Voice = voiceOf(tree)
	voice.live = false
	voice.sound:Pause()
end

function Legacy.resume(tree: Attachment)
	local voice: Voice = voiceOf(tree)
	voice.sound:Resume()
	voice.live = true
end

--[[
    Connects an element's callbacks to the voice until the returned
    disconnect runs, which is safe to call twice. Ended reaches it once per
    natural end and never after Echo's own stop, and Loaded through a defer
    when the Sound has already loaded
--]]

function Legacy.connect(tree: Attachment, events: VoiceEvents): () -> ()
	local voice: Voice = voiceOf(tree)
	local sound: Sound = voice.sound
	local connected: boolean = true
	voice.events = events

	local connections: { RBXScriptConnection } = {
		-- A deferred Ended can arrive after a new play, which the Sound playing again gives away
		sound.Ended:Connect(function ()
			if connected and voice.live and not sound.IsPlaying then
				voice.live = false
				events.ended()
			end
		end),

		sound.DidLoop:Connect(function ()
			if connected and voice.live then
				voice.loops += 1
				events.looped(voice.loops)
			end
		end),

		sound.Loaded:Connect(function ()
			if connected then
				events.loaded()
			end
		end),
	}

	-- Loaded never fires again for a Sound that has already loaded
	if sound.IsLoaded then
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
    attributes, its effects disabled with their defaults, its Sound under
    its Attachment in no SoundGroup, and every property a play wrote back
    to the template's value
--]]

function Legacy.clear(tree: Attachment)
	local voice: Voice = voiceOf(tree)
	local sound: Sound = voice.sound

	halt(voice)

	local defaults: Instance = Properties.probe("Sound")
	for property: string in voice.applied do
		Properties.write(sound, property, Properties.read(defaults, property))
	end

	table.clear(voice.applied)

	sound.SoundId = ""
	for name: string in sound:GetAttributes() do
		sound:SetAttribute(name, nil)
	end

	for _, effect: Effect in voice.effects do
		local instance: SoundEffect = effect.instance
		instance.Enabled = false

		local effectDefaults: Instance = Properties.probe(instance.ClassName)
		for property: string in effect.written do
			Properties.write(instance, property, Properties.read(effectDefaults, property))
		end

		table.clear(effect.written)
	end

	sound.Parent = tree
	sound.SoundGroup = nil
end

local Backend: Backend = Legacy

return Backend
