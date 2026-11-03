--[[
    Echo's public table: the elements a game writes its sounds as, the
    states, springs and refs it binds them to, the roots that play them from
    pooled voices, its configuration, named signals, preload and two reads
--]]

--!strict
local RunService = game:GetService("RunService")

local Cache = require(script.Cache)
local Element = require(script.Element)
local Keys = require(script.Keys)
local Preload = require(script.Preload)
local Root = require(script.Root)
local Signals = require(script.Signals)
local Spring = require(script.Spring)
local State = require(script.State)

local Types = require(script.Types)

export type Mode = Types.Mode
export type Config = Types.Config
export type CacheSize = Types.CacheSize
export type Bus = Types.Bus
export type Element = Types.Element
export type Props = Types.Props
export type Component = Types.Component
export type State<T> = Types.State<T>
export type Ref<T> = Types.Ref<T>
export type Handle = Types.Handle
export type Voice = Types.Voice
export type Overrides = Types.Overrides
export type Root = Types.Root
export type Mounted = Types.Mounted
export type CacheCount = Types.CacheCount
export type SpringApi = Types.SpringApi

--- @class Echo
--- Sounds written the way React writes an interface: a game describes each
--- sound as an element, binds its properties to states and springs, mounts
--- it in a root and plays it through its handle or by firing a named
--- signal. Echo runs on the client only, and requiring it connects nothing

local Echo = {
	--- @prop Fragment FragmentKey
	--- @within Echo
	--- The kind of an element that groups a list of components and elements,
	--- as in `Echo.createElement(Echo.Fragment, { Gunshot, Echo.createElement("Sound", props) })`
	Fragment = Keys.Fragment,

	--- @prop Event { Ended, Playing, Looped, Loaded }
	--- @within Echo
	--- The event keys of a sound's props. Each callback receives the voice
	--- first: `Ended` runs once per natural end and never on a stop, `Looped`
	--- also gets the loop count, `Loaded` runs through `task.defer` when the
	--- asset is loaded already, and `Playing` runs each time a voice starts.
	--- A callback that returns a function has it run as cleanup, and the
	--- element's handler for that event is dropped
	Event = Keys.Event,

	--- @prop Action { Play, Pause }
	--- @within Echo
	--- The action keys of a sound's props, each taking a boolean state.
	--- `Play` plays a new voice when its state turns true, its value at mount
	--- included, and stops every live voice when it turns false. `Pause`
	--- pauses every live voice when its state turns true and resumes them
	--- when it turns false. Each acts only when its state's value changes
	Action = Keys.Action,

	--- @prop Util { Cap, Bus }
	--- @within Echo
	--- The utility keys of a sound's props, each taking a name from the
	--- configuration: `Cap` puts the element in a cap group of
	--- `config.caps`, and `Bus` routes its voices to a bus of `config.buses`
	Util = Keys.Util,

	--- Makes an element, a description that owns no instance: a `"Sound"`,
	--- one of the nine legacy effect classes, the element a component
	--- returns for its props at any depth, or a fragment of components and
	--- elements. A missing `props` is an empty table, and only a sound takes
	--- children, each an effect element under its key
	--- @function createElement
	--- @within Echo
	--- @param kind string | Component | FragmentKey -- "Sound", an effect class, a component or Echo.Fragment
	--- @param props Props? -- Properties by name, refs, states and springs, and the Event, Action and Util keys
	--- @param children { [string]: Element }? -- A sound's effect elements, by key
	--- @return Element
	createElement = Element.create,

	--- Makes a state holding `default` and gives its setter. Each binding
	--- takes the state's value at mount and at every play, and each set
	--- writes once to every live voice bound to it, re-rendering nothing
	--- @function useState
	--- @within Echo
	--- @param default T -- The state's first value
	--- @return State<T> -- The state, for a prop or an action
	--- @return (value: T) -> () -- Its setter
	useState = State.new,

	--- Builds a spring from the table `builder` returns: each number in it
	--- becomes a style that binds like a state, and its `config` gives the
	--- `duration` and `delay` in seconds, each 0 when left out. `api:start`
	--- moves each named style linearly to its target and returns a Promise
	--- @function useSpring
	--- @within Echo
	--- @param builder () -> { [string]: any } -- Each style's first value by name, and a config
	--- @return { [string]: State<number> } -- The styles, for props
	--- @return SpringApi -- Its start
	useSpring = Spring.new :: (builder: () -> { [string]: any }) -> ({ [string]: State<number> }, SpringApi),

	--- Makes a ref holding `initial`. A ref handed to an element under any
	--- string key receives the element's handle at mount, and goes back to
	--- nil when its root is destroyed
	--- @function useRef
	--- @within Echo
	--- @param initial Handle? -- What the ref holds until its element mounts
	--- @return Ref<Handle?>
	useRef = Element.ref :: (initial: Handle?) -> Ref<Handle?>,

	--- Registers a callback under a name and returns its disconnect. A
	--- callback that returns a function has it run as cleanup, and the
	--- callback is unsubscribed
	--- @function createSignal
	--- @within Echo
	--- @param name string -- The signal's name, such as "Gun/Fire"
	--- @param callback (...any) -> ...(() -> ()) -- Runs on every fire of the name, with its arguments
	--- @return () -> () -- Its disconnect, safe to call more than once
	createSignal = Signals.create,

	--- Calls every callback under a name with the given arguments, inside
	--- this call. Every callback runs when one throws, and the first error is
	--- raised here. A name that holds no signal errors in Studio and warns
	--- outside it
	--- @function useSignal
	--- @within Echo
	--- @param name string -- The signal's name
	--- @param ... any -- What each callback receives
	useSignal = Signals.fire,

	--- Clears a name's entry, so a signal created again under it fires only
	--- its own callbacks
	--- @function removeSignal
	--- @within Echo
	--- @param name string -- The signal's name
	removeSignal = Signals.remove,

	--- Every element of every live root, in mount order: its `Name` or nil,
	--- its `SoundId` and `Volume` now, and its root's target
	--- @function getAll
	--- @within Echo
	--- @return { Mounted }
	getAll = Root.getAll,
}

--- Takes the game's configuration once, at boot and before the first root:
--- the default Mode, each Mode's pool size, each cap group's limit and the
--- buses. It errors on the server, on a second call and on any value it
--- cannot use, naming the field
--- @function configure
--- @within Echo
--- @param config Config

function Echo.configure(config: Config)
	if not RunService:IsClient() then
		error("Echo plays its sounds on the client only, so configure runs there and not on the server", 2)
	end

	Root.configure(config)
end

--- Mounts an element tree and returns its root, in the default Mode or in
--- `mode`. A root's voices follow `target` while they play when it is a
--- BasePart, Attachment or Model, and play in 2D for nil, a string or any
--- other instance; a string also names the root in `getAll`
--- @method root
--- @within Echo
--- @param target Instance | string | nil -- What the root's voices follow, or a string naming it
--- @param element Element -- The tree to mount
--- @param mode Mode? -- The Mode this root plays in, in place of the default
--- @return Root -- Its destroy stops its voices at once and sets its refs back to nil

function Echo:root(target: Instance | string | nil, element: Element, mode: Mode?): Root
	return Root.mount(target, element, mode) :: Root
end

--- Makes an empty ref, which an element hands its handle to at mount
--- @function createRef
--- @within Echo
--- @return Ref<Handle?>

function Echo.createRef(): Ref<Handle?>
	return Element.ref(nil :: Handle?)
end

--- Preloads in one `ContentProvider:PreloadAsync` pass the SoundIds of the
--- elements under the `priority` roots first, then every other SoundId Echo
--- has recorded, then `ids`, each once. The Promise resolves with the ids
--- that failed to load, an empty list when none did. A priority entry that
--- is no root, or an id that is no string, errors at the call
--- @function preload
--- @within Echo
--- @param priority { Root }? -- The roots whose sounds load first
--- @param ids { string }? -- The ids that load last, such as takes a game plays only as SoundId overrides
--- @return Promise<{ string }>

function Echo.preload(priority: { Root }?, ids: { string }?): any
	return Preload.run(Root.ids(priority or {}), ids)
end

--- One Mode's pool, the default Mode's when none is given, as its voices in
--- use and its size, from Echo's own counts. A Mode `config.cache` does
--- not size errors
--- @function getCache
--- @within Echo
--- @param mode Mode? -- The pool's Mode
--- @return CacheCount

function Echo.getCache(mode: Mode?): CacheCount
	return Cache.count(mode or Root.defaultMode())
end

type Self = typeof(Echo)

return Echo
