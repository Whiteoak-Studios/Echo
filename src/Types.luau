--[[
    Every type that crosses from one of Echo's modules to another: the public
    ones the root re-exports, the prop key tokens, and the internal shapes of
    elements, voices, cache requests and the two backends
--]]

--!strict
export type Mode = "AudioApi" | "Legacy"

export type CacheSize = {
	initial: number,
	growAt: number,
	growBy: number,
	ceiling: number,
}

export type Bus = {
	group: SoundGroup?, -- The SoundGroup a Legacy voice joins
	fader: AudioFader?, -- The AudioFader a 2D Audio API voice wires into
	interactionGroup: string?, -- The AudioInteractionGroup a world Audio API voice's emitter joins
}

export type Config = {
	mode: Mode,
	cache: { [Mode]: CacheSize },
	caps: { [string]: number }?,
	buses: { [string]: Bus }?,
}

export type Props = { [any]: any }

export type Element = { read kind: string }

export type Component = (props: Props) -> Element

export type State<T> = { read current: T }

export type Ref<T> = { current: T }

export type Voice = { read instance: (Sound | AudioPlayer)? }

export type Overrides = { [string]: any }

export type Handle = {
	play: (self: Handle, overrides: Overrides?) -> Voice?,
	stop: (self: Handle, voice: Voice?, fade: number?) -> (),
	get: (self: Handle) -> Voice?,
	getAll: (self: Handle) -> { Voice },
}

export type Root = { destroy: (self: Root) -> () }

export type Mounted = {
	name: string?,
	soundId: string,
	volume: number,
	root: Instance | string | nil,
}

export type CacheCount = { inUse: number, size: number }

export type SpringApi = { start: (self: SpringApi, targets: { [string]: any }) -> any }

export type SignalCallback = (...any) -> ...(() -> ())

export type FragmentKey = { read name: "Echo.Fragment" }

export type EventKey = {
	read name: "Echo.Event.Ended" | "Echo.Event.Playing" | "Echo.Event.Looped" | "Echo.Event.Loaded",
}

export type ActionKey = { read name: "Echo.Action.Play" | "Echo.Action.Pause" }

export type SoundElement = {
	read kind: "Sound",
	properties: { [string]: any }, -- By name, each a value or a state
	events: { [EventKey]: (voice: Voice, ...any) -> ...any },
	actions: { [ActionKey]: State<boolean> },
	refs: { Ref<any> },
	attributes: { [string]: any },
	cap: string?, -- The cap group's name
	bus: string?, -- The bus's name
	effects: { [string]: EffectElement }, -- By child key
}

export type FragmentElement = {
	read kind: "Fragment",
	children: { Element },
}

export type EffectElement = {
	read kind: "Effect",
	className: string, -- One of the legacy effect classes, the keys of Constants.EFFECTS
	properties: { [string]: any },
}

export type VoiceToken = {
	instance: (Sound | AudioPlayer)?, -- Nil once the voice is back in the pool
	tree: Attachment,
	mode: Mode,
	order: number, -- Its start order, which caps and stealing read
	looped: boolean,
	group: string?,
	release: (voice: VoiceToken) -> (), -- Set by the element's handle, called before every give-back
}

export type TakeRequest = {
	looped: boolean,
	group: string?,
	limit: number?,
	release: (voice: VoiceToken) -> (),
}

export type VoiceEvents = {
	ended: () -> (),
	looped: (count: number) -> (),
	loaded: () -> (),
	playing: () -> (),
}

export type Backend = {
	setup: () -> (),
	template: () -> Attachment,
	playable: (tree: Attachment) -> Sound | AudioPlayer,
	check: (property: string, value: any) -> string?, -- The reason this Mode refuses the property, or nil
	apply: (tree: Attachment, property: string, value: any) -> boolean,
	effect: (tree: Attachment, className: string, key: string, properties: { [string]: any }) -> (),
	route: (tree: Attachment, bus: Bus?, world: boolean) -> (),
	place: (tree: Attachment, position: Vector3) -> (),
	play: (tree: Attachment) -> (),
	stop: (tree: Attachment) -> (),
	pause: (tree: Attachment) -> (),
	resume: (tree: Attachment) -> (),
	connect: (tree: Attachment, events: VoiceEvents) -> () -> (),
	clear: (tree: Attachment) -> (),
}

return {}
