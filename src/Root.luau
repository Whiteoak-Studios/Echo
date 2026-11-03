--[[
    Echo's configuration and the roots a game mounts: the pools configure
    fills, each root's handles, the reads of every mounted element, and the
    SoundIds the preload pass takes from a list of roots
--]]

--!strict
local Root = {}
Root.__index = Root

local AudioApi = require(script.Parent.Backends.AudioApi)
local Cache = require(script.Parent.Cache)
local Constants = require(script.Parent.Constants)
local Element = require(script.Parent.Element)
local Handle = require(script.Parent.Handle)
local Legacy = require(script.Parent.Backends.Legacy)
local Properties = require(script.Parent.Backends.Properties)

-- Each Mode's backend
local BACKENDS: { [Mode]: Backend } = {
	Legacy = Legacy,
	AudioApi = AudioApi,
}

local Types = require(script.Parent.Types)

type Backend = Types.Backend
type CacheSize = Types.CacheSize
type Config = Types.Config
type Element = Types.Element
type HandleOptions = Types.HandleOptions
type Mode = Types.Mode
type Mounted = Types.Mounted
type SoundElement = Types.SoundElement

type Fields = {
	_target: Instance | string | nil,
	_handles: { Handle.Handle }, -- One per sound, in mount order
	_sounds: { SoundElement }, -- Each handle's element, whose refs the root sets
	_destroyed: boolean,
}

local configuration: Config? = nil -- Set once, by configure
local Roots: { Self } = {} -- Every live root, in mount order

local function isCount(value: any): boolean
	return type(value) == "number" and value >= 1 and value % 1 == 0
end

local function isMode(value: any): boolean
	return table.find(Constants.MODES, value) ~= nil
end

local function isA(value: any, className: string): boolean
	return typeof(value) == "Instance" and (value :: Instance):IsA(className)
end

local function configured(): Config
	local config: Config? = configuration
	if not config then
		error("Echo.configure must run before the first root")
	end

	return config
end

local function checkSize(mode: string, size: any)
	for _, field: string in Constants.CACHE_SIZE_FIELDS do
		local value: any = size[field]

		-- Only initial is required, and a growth field is checked when given
		if (value ~= nil or field == "initial") and not isCount(value) then
			error(`Echo: config.cache.{mode}.{field} is a whole number of 1 or more, not {value}`)
		end
	end

	local given: boolean = false
	local missing: string? = nil
	for _, field: string in Constants.GROWTH_FIELDS do
		if size[field] ~= nil then
			given = true
		elseif not missing then
			missing = field
		end
	end

	-- A pool given none of the growth fields is fixed at its initial
	if not given then
		return
	elseif missing then
		error(`Echo: config.cache.{mode}.{missing} is missing; growAt, growBy and ceiling come together or not at all`)
	elseif size.growAt > size.initial then
		error(`Echo: config.cache.{mode}.growAt is at most its initial, not {size.growAt}`)
	elseif size.ceiling < size.initial then
		error(`Echo: config.cache.{mode}.ceiling is at least its initial, not {size.ceiling}`)
	end
end

local function checkCache(cache: any)
	if type(cache) ~= "table" then
		error(`Echo: config.cache maps each Mode to its pool's size, not {typeof(cache)}`)
	end

	for mode: any, size: any in cache do
		if not isMode(mode) then
			error(`Echo: config.cache.{tostring(mode)} names no Mode; a Mode is "AudioApi" or "Legacy"`)
		elseif type(size) ~= "table" then
			error(`Echo: config.cache.{mode} is a table of the pool's size, not {typeof(size)}`)
		end

		checkSize(mode, size)
	end
end

local function checkCaps(caps: any)
	if caps == nil then
		return
	elseif type(caps) ~= "table" then
		error(`Echo: config.caps maps each cap group's name to its limit, not {typeof(caps)}`)
	end

	for group: any, limit: any in caps do
		if type(group) ~= "string" then
			error(`Echo: config.caps holds a key {tostring(group)}, which is no cap group's name`)
		elseif not isCount(limit) then
			error(`Echo: config.caps["{group}"] is a whole number of 1 or more, not {limit}`)
		end
	end
end

local function checkBuses(buses: any)
	if buses == nil then
		return
	elseif type(buses) ~= "table" then
		error(`Echo: config.buses maps each bus's name to its objects, not {typeof(buses)}`)
	end

	for name: any, bus: any in buses do
		if type(name) ~= "string" then
			error(`Echo: config.buses holds a key {tostring(name)}, which is no bus's name`)
		elseif type(bus) ~= "table" then
			error(`Echo: config.buses.{name} is a table of the bus's objects, not {typeof(bus)}`)
		elseif bus.group ~= nil and not isA(bus.group, "SoundGroup") then
			error(`Echo: config.buses.{name}.group is a SoundGroup or nil, not {typeof(bus.group)}`)
		elseif bus.fader ~= nil and not isA(bus.fader, "AudioFader") then
			error(`Echo: config.buses.{name}.fader is an AudioFader or nil, not {typeof(bus.fader)}`)
		elseif bus.interactionGroup ~= nil and type(bus.interactionGroup) ~= "string" then
			error(`Echo: config.buses.{name}.interactionGroup is a string or nil, not {typeof(bus.interactionGroup)}`)
		end
	end
end

local function checkParent(parent: any)
	if parent == nil then
		return
	elseif typeof(parent) ~= "Instance" then
		error(`Echo: config.parent is an Instance in the DataModel or nil, not {typeof(parent)}`)
	end

	local instance = parent :: Instance
	if not instance:IsDescendantOf(game) then
		error(`Echo: config.parent is an Instance in the DataModel, and {instance:GetFullName()} is outside it`)
	end
end

-- Past what it renders, the engine itself silences the newest Audio API voices, which Echo's stealing never sees
local function warnAboveLimit(config: Config)
	local size: CacheSize? = config.cache.AudioApi
	local voices: number? = size and (size.ceiling or size.initial)

	if not voices or voices <= Constants.AUDIO_API_VOICE_LIMIT or config.warnAudioApiLimit == false then
		return
	end

	local pool: string = `config.cache.AudioApi can hold {voices} voices`
	local above: string = `more than the Audio API's soft limit of {Constants.AUDIO_API_VOICE_LIMIT}`
	local silent: string = "so voices past what the engine renders may stay silent"
	local silence: string = "set config.warnAudioApiLimit = false to silence this"

	warn(`Echo: {pool}, {above}, {silent}; {silence}`)
end

--[[
    Takes the game's configuration once, refusing by name any field it
    cannot use before it does anything, then warns when the Audio API pool
    is above its soft limit, sets up each Mode config.cache sizes and fills
    that Mode's pool under config.parent
--]]

function Root.configure(config: Config)
	if configuration then
		error("Echo: configure runs once, and it has run already")
	elseif type(config) ~= "table" then
		error(`Echo: configure takes a table, not {typeof(config)}`)
	end

	for field: any in config :: any do
		if not Constants.CONFIG_FIELDS[field] then
			local fields: string = "mode, cache, caps, buses, parent and warnAudioApiLimit"
			error(`Echo: config.{tostring(field)} is no field configure takes; it takes {fields}`)
		end
	end

	checkCache(config.cache)
	if not isMode(config.mode) or not config.cache[config.mode] then
		error(`Echo: config.mode is a Mode config.cache sizes, not {tostring(config.mode)}`)
	end

	checkCaps(config.caps)
	checkBuses(config.buses)
	checkParent(config.parent)

	local warning: any = config.warnAudioApiLimit
	if warning ~= nil and type(warning) ~= "boolean" then
		error(`Echo: config.warnAudioApiLimit is a boolean or nil, not {typeof(warning)}`)
	end

	warnAboveLimit(config)

	for _, mode: Mode in Constants.MODES do
		local size: CacheSize? = config.cache[mode]
		if size then
			local backend: Backend = BACKENDS[mode]
			backend.setup()
			Cache.create(mode, size, backend, config.parent)
		end
	end

	configuration = config
end

function Root.defaultMode(): Mode
	return configured().mode
end

--[[
    Mounts an element tree as a root in a Mode, the default one when none
    is given. Every sound is checked before anything binds, so a failed
    mount leaves nothing behind; then each ref gets its element's handle
    and the bindings and actions connect. No root makes an instance

    @ target | what its voices follow, or a string naming the root, or nil
--]]

function Root.mount(target: Instance | string | nil, element: Element, mode: Mode?): Self
	local config: Config = configured()
	local chosen: Mode = mode or config.mode
	local kind: string = typeof(target)

	if not config.cache[chosen] then
		error(`Echo: a root's Mode is one config.cache sizes, not {tostring(chosen)}`)
	elseif kind ~= "nil" and kind ~= "Instance" and kind ~= "string" then
		error(`Echo: a root's target is an Instance, a string or nil, not {kind}`)
	end

	local sounds: { SoundElement } = Element.sounds(element)
	local options: HandleOptions = {
		mode = chosen,
		backend = BACKENDS[chosen],
		target = target,
		config = config,
	}

	local handles: { Handle.Handle } = {}
	for _, sound: SoundElement in sounds do
		table.insert(handles, Handle.new(sound, options))
	end

	for index: number, sound: SoundElement in sounds do
		for _, ref: Types.Ref<any> in sound.refs do
			ref.current = handles[index]
		end
	end

	local root: Self = setmetatable({
		_target = target,
		_handles = handles,
		_sounds = sounds,
		_destroyed = false,
	}, Root)

	table.insert(Roots, root)

	for _, handle: Handle.Handle in handles do
		handle:bind()
	end

	return root
end

--[[
    Gives back every live voice of the root at once, ends its bindings and
    actions, sets each ref still holding its handle back to nil and drops
    the root from the reads. A second call does nothing
--]]

function Root.destroy(self: Self)
	if self._destroyed then
		return
	end

	self._destroyed = true

	local index: number? = table.find(Roots, self)
	if index then
		table.remove(Roots, index)
	end

	for position: number, handle: Handle.Handle in self._handles do
		handle:destroy()

		for _, ref: Types.Ref<any> in self._sounds[position].refs do
			if ref.current == handle then
				ref.current = nil
			end
		end
	end
end

--[[
    Every element of every live root, in mount order: its Name, SoundId and
    Volume now, each read the way a play reads it and falling back to a
    legacy Sound's own, and its root's target
--]]

function Root.getAll(): { Mounted }
	local defaultVolume: number = Properties.read(Properties.probe("Sound"), "Volume")
	local mounted: { Mounted } = {}

	for _, root: Self in Roots do
		for _, handle: Handle.Handle in root._handles do
			local name: any = handle:property(Constants.LABEL)
			local soundId: any = handle:property("SoundId")
			local volume: any = handle:property("Volume")

			table.insert(mounted, {
				name = type(name) == "string" and name or nil,
				soundId = type(soundId) == "string" and soundId or "",
				volume = type(volume) == "number" and volume or defaultVolume,
				root = root._target,
			})
		end
	end

	return mounted
end

--[[
    Each given root's SoundIds now, in mount order. A destroyed root gives
    none, and a value that is no root errors, naming it
--]]

function Root.ids(roots: { Types.Root }): { string }
	if type(roots) ~= "table" then
		error(`Echo: the priority roots are a list of roots, not {typeof(roots)}`)
	end

	local ids: { string } = {}
	for index: any, given: any in roots :: any do
		if getmetatable(given) ~= Root then
			error(`Echo: priority entry {tostring(index)} is {typeof(given)} {tostring(given)}, not a root Echo made`)
		end

		local root: Self = given
		if root._destroyed then
			continue
		end

		for _, handle: Handle.Handle in root._handles do
			local id: any = handle:property("SoundId")
			if type(id) == "string" then
				table.insert(ids, id)
			end
		end
	end

	return ids
end

type Self = typeof(setmetatable({} :: Fields, Root))

return Root
