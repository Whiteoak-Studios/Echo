--[[
    The handle a mounted sound element gives its refs: it plays the element's
    voices from the cache, stops and fades them, and carries the element's
    bindings, actions and events to every voice it has live
--]]

--!strict
local Handle = {}
Handle.__index = Handle

local RunService = game:GetService("RunService")

local Cache = require(script.Parent.Cache)
local Constants = require(script.Parent.Constants)
local Keys = require(script.Parent.Keys)
local State = require(script.Parent.State)

local Types = require(script.Parent.Types)

type Backend = Types.Backend
type Bus = Types.Bus
type Config = Types.Config
type EffectElement = Types.EffectElement
type EventKey = Types.EventKey
type HandleOptions = Types.HandleOptions
type Mode = Types.Mode
type Overrides = Types.Overrides
type SoundElement = Types.SoundElement
type State<T> = Types.State<T>
type Voice = Types.Voice
type VoiceToken = Types.VoiceToken

type Callback = (voice: Voice, ...any) -> ...any

type Fields = {
	_element: SoundElement,
	_mode: Mode,
	_backend: Backend,
	_target: Instance | string | nil,
	_limit: number?, -- Its cap group's limit, nil with no group
	_bus: Bus?,
	_handlers: { [EventKey]: Callback }, -- The element's, less each one whose callback returned a cleanup
	_live: { VoiceToken }, -- Oldest first
	_disconnects: { [VoiceToken]: () -> () }, -- Each live voice's events, ended by the release hook
	_fades: { [VoiceToken]: RBXScriptConnection }, -- Each fading voice's Heartbeat, ended by the release hook
	_paused: { [VoiceToken]: boolean }, -- The voices Echo.Action.Pause paused, which it resumes
	_subscriptions: { () -> () }, -- Each binding's and action's, ended by destroy
	_destroyed: boolean,
}

-- A property's value now: a bound state's current, or the value itself
local function current(value: any): any
	if State.is(value) then
		return State.get(value)
	end

	return value
end

-- A voice under a root whose target is one of these follows it in the world
local function followable(target: Instance | string | nil): boolean
	if typeof(target) ~= "Instance" then
		return false
	end

	local instance: Instance = target :: Instance
	return instance:IsA("BasePart") or instance:IsA("Attachment") or instance:IsA("Model")
end

--[[
    Makes the handle for one sound element in one root. Every property and
    effect property the element sets is checked against its Mode, its label
    as a string or nil, and its cap group and bus against the configuration,
    before anything binds
--]]

function Handle.new(element: SoundElement, options: HandleOptions): Self
	local backend: Backend = options.backend
	local config: Config = options.config

	for name: string, value: any in element.properties do
		local given: any = current(value)
		if name == Constants.LABEL then
			if given ~= nil and type(given) ~= "string" then
				error(`Echo can't mount a Sound's {name}, the label getAll reads: it is a string, not {typeof(given)}`)
			end

			continue
		end

		local reason: string? = backend.check(name, given)
		if reason then
			error(`Echo can't mount a Sound's {name}: {reason}`)
		end
	end

	for key: string, effect: EffectElement in element.effects do
		for property: string, value: any in effect.properties do
			local reason: string? = backend.checkEffect(effect.className, property, value)
			if reason then
				error(`Echo can't mount a Sound's {key} effect: {reason}`)
			end
		end
	end

	local caps: { [string]: number } = config.caps or {}
	local buses: { [string]: Bus } = config.buses or {}
	local group: string? = element.cap
	local busName: string? = element.bus

	if group and not caps[group] then
		error(`Echo can't mount a Sound in cap group "{group}", which config.caps holds no limit for`)
	elseif busName and not buses[busName] then
		error(`Echo can't mount a Sound on bus "{busName}", which config.buses does not hold`)
	end

	return setmetatable({
		_element = element,
		_mode = options.mode,
		_backend = backend,
		_target = options.target,
		_limit = group and caps[group] or nil,
		_bus = busName and buses[busName] or nil,
		_handlers = table.clone(element.events),
		_live = {} :: { VoiceToken },
		_disconnects = {} :: { [VoiceToken]: () -> () },
		_fades = {} :: { [VoiceToken]: RBXScriptConnection },
		_paused = {} :: { [VoiceToken]: boolean },
		_subscriptions = {} :: { () -> () },
		_destroyed = false,
	}, Handle)
end

--[[
    Connects the element's bindings and actions for its root's life. Each
    set of a bound state writes once to every live voice, and an action acts
    only when its state's value changes, Echo.Action.Play on its value now
    as well
--]]

function Handle.bind(self: Self)
	-- The label is read where it is bound, so no set of it reaches a voice
	for name: string, value: any in self._element.properties do
		if name ~= Constants.LABEL and State.is(value) then
			table.insert(
				self._subscriptions,
				State.subscribe(value, function (set: any)
					self:_write(name, set)
				end)
			)
		end
	end

	local play: State<boolean>? = self._element.actions[Keys.Action.Play]
	if play then
		local last: any = State.get(play)
		table.insert(
			self._subscriptions,
			State.subscribe(play, function (value: any)
				if value == last then
					return
				end

				last = value
				if value == true then
					self:play()
				else
					self:stop()
				end
			end)
		)

		if last == true then
			self:play()
		end
	end

	local pause: State<boolean>? = self._element.actions[Keys.Action.Pause]
	if pause then
		local last: any = State.get(pause)
		table.insert(
			self._subscriptions,
			State.subscribe(pause, function (value: any)
				if value == last then
					return
				end

				local held: boolean = last == true
				last = value
				if value == true then
					self:_pause()
				elseif held then
					self:_resume()
				end
			end)
		)
	end
end

--[[
    Starts a voice of the element and gives it, or nil when the Mode's pool
    is at its ceiling with nothing but loops playing. An override stands in
    for the element's own value for this one play, checked first the way a
    mount checks a property, and at plays the voice at that point

    @ overrides | properties by name, an effect's under its key, and at
--]]

function Handle.play(self: Self, overrides: Overrides?): Voice?
	if self._destroyed then
		error("Echo: this handle's root was destroyed, so it plays nothing", 2)
	end

	local given: Overrides = overrides or {}
	if type(given) ~= "table" then
		error(`Echo: play takes a table of overrides, not {typeof(given)}`, 2)
	end

	local at: Vector3? = self:_check(given)
	local element: SoundElement = self._element
	local backend: Backend = self._backend

	-- The value each property plays at, its override standing in for the element's own, and never the label
	local values: { [string]: any } = {}
	for name: string, value: any in element.properties do
		if name ~= Constants.LABEL then
			values[name] = current(value)
		end
	end

	for key: string, value: any in given do
		if key ~= "at" and not element.effects[key] then
			values[key] = value
		end
	end

	local taken: VoiceToken? = Cache.take(self._mode, {
		looped = values.Looped == true,
		group = element.cap,
		limit = self._limit,
		release = function (released: VoiceToken)
			self:_drop(released)
		end,
	})

	if not taken then
		return nil
	end

	local voice: VoiceToken = taken
	local tree: Attachment = voice.tree
	table.insert(self._live, voice)

	-- A TimePosition goes in after the play, which rewinds
	for name: string, value: any in values do
		if name ~= "TimePosition" then
			backend.apply(tree, name, value)
		end
	end

	for key: string, effect: EffectElement in element.effects do
		local properties: { [string]: any } = table.clone(effect.properties)
		for property: string, value: any in given[key] or {} do
			properties[property] = value
		end

		backend.effect(tree, effect.className, key, properties)
	end

	local world: boolean = at ~= nil or followable(self._target)
	backend.route(tree, self._bus, world)

	if at then
		backend.place(tree, at)
	elseif world then
		Cache.follow(voice, self._target :: Instance)
	end

	local instance: Instance = voice.instance :: Instance
	for name: string, value: any in element.attributes do
		instance:SetAttribute(name, value)
	end

	-- Connected after the new SoundId is written, so the backend's already-loaded check reads this play's
	-- asset, and before the play, which calls playing
	self._disconnects[voice] = backend.connect(tree, {
		ended = function ()
			Cache.give(voice)
			self:_dispatch(Keys.Event.Ended, voice)
		end,

		looped = function (count: number)
			self:_dispatch(Keys.Event.Looped, voice, count)
		end,

		loaded = function ()
			self:_dispatch(Keys.Event.Loaded, voice)
		end,

		playing = function ()
			self:_dispatch(Keys.Event.Playing, voice)
		end,
	})

	backend.play(tree)

	-- A Playing callback may have stopped the voice already
	if values.TimePosition ~= nil and voice.instance then
		backend.apply(tree, "TimePosition", values.TimePosition)
	end

	return voice
end

--[[
    Checks a play's overrides the way a mount checks properties, erroring
    at the play's caller on the first it refuses, and gives the play's at
--]]

function Handle._check(self: Self, overrides: Overrides): Vector3?
	local backend: Backend = self._backend
	local at: Vector3? = nil

	for key: any, value: any in overrides do
		if key == "at" then
			if typeof(value) ~= "Vector3" then
				error(`Echo: play's at takes a Vector3, not {typeof(value)}`, 3)
			end

			at = value
			continue
		elseif type(key) ~= "string" then
			error(`Echo: play's override key {tostring(key)} is not a string`, 3)
		elseif key == Constants.LABEL then
			error(`Echo: play can't override {key}, the element's own label, which no voice is given`, 3)
		end

		local effect: EffectElement? = self._element.effects[key]
		if not effect then
			local reason: string? = backend.check(key, value)
			if reason then
				error(`Echo: play can't override {key}: {reason}`, 3)
			end

			continue
		elseif type(value) ~= "table" then
			error(`Echo: play's {key} override takes a table of the effect's properties, not {typeof(value)}`, 3)
		end

		for property: any, setting: any in value do
			if type(property) ~= "string" then
				error(`Echo: play's {key} override names a property {tostring(property)}, which is not a string`, 3)
			end

			local reason: string? = backend.checkEffect(effect.className, property, setting)
			if reason then
				error(`Echo: play can't override the {key} effect: {reason}`, 3)
			end
		end
	end

	return at
end

--[[
    Runs the element's callback for an event on a thread of its own, so one
    that throws or yields leaves the voice and the play that fired it whole.
    A callback that returns a function has it run at once, and the
    element's handler for that event is dropped for every later voice
--]]

function Handle._dispatch(self: Self, key: EventKey, voice: VoiceToken, ...: any)
	local found: Callback? = self._handlers[key]
	if not found then
		return
	end

	local callback: Callback = found
	task.spawn(function (...: any)
		local cleanup: any = callback(voice, ...)
		if type(cleanup) ~= "function" then
			return
		end

		if self._handlers[key] == callback then
			self._handlers[key] = nil
		end

		(cleanup :: () -> ())()
	end, ...)
end

--[[
    The release hook the cache calls before it clears a voice: the voice
    leaves the live list, its events disconnect and its fade ends
--]]

function Handle._drop(self: Self, voice: VoiceToken)
	local index: number? = table.find(self._live, voice)
	if index then
		table.remove(self._live, index)
	end

	local disconnect: (() -> ())? = self._disconnects[voice]
	self._disconnects[voice] = nil
	if disconnect then
		disconnect()
	end

	local fade: RBXScriptConnection? = self._fades[voice]
	self._fades[voice] = nil
	if fade then
		fade:Disconnect()
	end

	self._paused[voice] = nil
end

--[[
    Stops a live voice, or every live voice of the element when none is
    given, at once or fading out over the given seconds. A voice that is not
    live here, one that ended, was taken or was stopped among them, is left
    alone

    @ fade | seconds the voice's Volume falls to 0 over before it goes back
--]]

function Handle.stop(self: Self, voice: Voice?, fade: number?)
	if fade ~= nil and not (type(fade) == "number" and fade >= 0 and fade < math.huge) then
		error(`Echo: stop's fade is seconds, 0 or more, not {typeof(fade)} {fade}`, 2)
	end

	if voice == nil then
		for _, live: VoiceToken in table.clone(self._live) do
			self:_stopOne(live, fade)
		end

		return
	end

	for _, live: VoiceToken in self._live do
		if live == voice then
			self:_stopOne(live, fade)
			return
		end
	end
end

--[[
    Gives a voice back at once, or moves its Volume linearly to 0 over the
    fade first, measured on the clock and given back at its deadline. A voice
    stopped again while it fades goes back at once
--]]

function Handle._stopOne(self: Self, voice: VoiceToken, fade: number?)
	if not fade or fade == 0 or self._fades[voice] then
		Cache.give(voice)
		return
	end

	local seconds: number = fade
	local from: number = (voice.instance :: Sound | AudioPlayer).Volume
	local started: number = os.clock()
	local deadline: number = started + seconds

	-- Ended by the release hook, which the give at the deadline runs
	self._fades[voice] = RunService.Heartbeat:Connect(function ()
		local now: number = os.clock()
		if now < deadline then
			self._backend.apply(voice.tree, "Volume", from * (1 - (now - started) / seconds))
		else
			Cache.give(voice)
		end
	end)
end

-- Writes a bound state's set to every live voice, a fading voice's Volume aside
function Handle._write(self: Self, name: string, value: any)
	for _, voice: VoiceToken in self._live do
		if name == "Volume" and self._fades[voice] then
			continue
		end

		if self._backend.apply(voice.tree, name, value) and name == "Looped" then
			voice.looped = value == true
		end
	end
end

function Handle._pause(self: Self)
	for _, voice: VoiceToken in self._live do
		self._paused[voice] = true
		self._backend.pause(voice.tree)
	end
end

function Handle._resume(self: Self)
	for voice: VoiceToken in self._paused do
		self._backend.resume(voice.tree)
	end

	table.clear(self._paused)
end

--[[
    The most recently started live voice, or nil
--]]

function Handle.get(self: Self): Voice?
	return self._live[#self._live]
end

--[[
    A fresh list of every live voice, oldest first
--]]

function Handle.getAll(self: Self): { Voice }
	local voices: { Voice } = {}
	for _, voice: VoiceToken in self._live do
		table.insert(voices, voice)
	end

	return voices
end

--[[
    The element's value for a property now: a bound state's current, the
    value the element set, or nil
--]]

function Handle.property(self: Self, name: string): any
	return current(self._element.properties[name])
end

--[[
    Ends the element's bindings and actions and gives back every live voice
    at once, after which a play errors; a second call does nothing
--]]

function Handle.destroy(self: Self)
	if self._destroyed then
		return
	end

	self._destroyed = true
	for _, unsubscribe: () -> () in self._subscriptions do
		unsubscribe()
	end

	table.clear(self._subscriptions)

	for _, voice: VoiceToken in table.clone(self._live) do
		Cache.give(voice)
	end
end

export type Handle = Self
type Self = typeof(setmetatable({} :: Fields, Handle))

return Handle
