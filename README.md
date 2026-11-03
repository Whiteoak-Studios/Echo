# Echo

Declarative sound for Roblox, shaped like React. A game writes each sound as a component that returns an element, binds the element's properties to states and springs, and mounts it in a root. Gameplay plays a sound by firing a named signal, so it never touches a sound instance, and a state change writes the one thing bound to it and re-renders nothing.

## Contents

- [What Echo is](#what-echo-is)
- [Install](#install)
- [A short example](#a-short-example)
- [How each part works](#how-each-part-works)
- [Limits](#limits)
- [API](#api)
- [Working on Echo](#working-on-echo)
- [License](#license)

## What Echo is

Neither a `Sound` nor an `AudioPlayer` overlaps itself, so a gun that fires faster than its recording lasts needs another instance for every shot. Echo describes each sound once, at client boot, as an element that owns no instance, and plays it from a pool of voices it clones once on [Cellar](https://github.com/Whiteoak-Studios/Cellar). Gameplay asks for a sound by firing its signal, so the code that sets sound properties lives in the sound's own module instead of in every system that makes a noise.

A play takes a free voice, gives it the element's recording and properties, plays it, and gives the voice back once it ends, cleared of everything the play set. Mounting an element and recording its asset id stay cheap, so a game can mount every weapon take at boot.

Echo plays through either of Roblox's two sound systems, and the choice is called the Mode. `"Legacy"` plays each voice on a `Sound`, and `"AudioApi"` plays it on an `AudioPlayer` with its own `AudioEmitter` and `Wire`. A game sets one default Mode at boot and can play any root in the other, and the same element description plays in both, so a game's sound modules never change with the Mode.

Echo requires on the client only. Its signals stay in the client's own process and it does no networking, so a server event reaches a sound through the game's own networking and a `useSignal` call on the client. Requiring Echo connects nothing and makes no instance. Echo holds no game values: every pool size, cap, range and fade reaches it from the game's configuration. Layer weights, equalizer values, the speed-of-sound delay and picking a take stay in the game too.

Its source is strict-mode Luau written for luau-lsp's new type checker, and a game requires it with full types. 8.0.0 is a rewrite of 7.8.6 that changes most of its API, and `CHANGELOG.md` lists everything that changed and how a game moves.

## Install

Echo is the Wally package `fadeluc-123/echo`, realm `shared`. Add it to your game's `wally.toml` under `[dependencies]`:

```toml
[dependencies]
Echo = "fadeluc-123/echo@^8.0.0"
```

`^8.0.0` takes any 8.x release and never 9.0.0. Echo brings its own Promise (`evaera/promise@^4.0.0`) and Cellar (`fadeluc-123/cellar@^0.1.0`), which Wally installs beside it, so a game lists neither for Echo's sake.

Require Echo on the client only. `Echo.configure` errors on the server.

### Typed install

Echo is fully typed, but Wally hides the types. It installs each package under `Packages/_Index/` and puts a one-line file at `Packages/Echo` that points at it, and that file loses every exported type, so `require(Packages.Echo)` comes back as `any`. Run these three commands after every install, in this order, from one Lune script in `.lune/` so none of them gets skipped:

```sh
wally install
rojo sourcemap sourcemap.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
```

`wally install` installs the packages. `rojo sourcemap` writes a map of your place to `sourcemap.json`; `sourcemap.project.json` is the project file a Whiteoak game builds its sourcemap from, so name whichever project file maps your place. `wally-package-types` reads that map and rewrites the one-line files with the types included. It fails on a second pass over files it has already rewritten, so run the whole sequence again from `wally install` rather than repeating the last step.

Echo's types are written for luau-lsp's new type checker. luau-lsp's command line and its VS Code extension both run the old checker unless told otherwise, so pass `--flag:LuauSolverV2=true` to every `luau-lsp analyze`, in CI and by hand, and give the editor the same flags in `.vscode/settings.json`:

```json
{
	"luau-lsp.sourcemap.rojoProjectFile": "sourcemap.project.json",
	"luau-lsp.fflags.enableNewSolver": true,
	"luau-lsp.fflags.enableByDefault": true,
	"luau-lsp.fflags.sync": false
}
```

The first line names the project file the editor builds its sourcemap from. `enableNewSolver` turns the new checker on, `enableByDefault` turns on every boolean Luau flag the way `luau-lsp analyze` does, and `sync: false` stops the extension copying Roblox's live Luau flags, so a change Roblox makes to them never reaches your editor unannounced.

Then require Echo bare, with no annotation, as `local Echo = require(Packages.Echo)` with `Packages` set to `ReplicatedStorage.Packages`, the way every example below does. An annotation on that line would replace the module's own type, and every function's type with it. Bare, every call into Echo is checked: a misspelled handle method, a setter given the wrong type, a Mode outside `"AudioApi"` and `"Legacy"`, a pool size missing a field and `Echo.root` called with a dot are all type errors. The exported types are there by name, such as `Echo.Handle` and `Echo.Element`, and the public functions carry Moonwave doc comments, so the editor shows each one's notes on hover. The types use read-only properties, which the old checker cannot parse, so a game still on the old checker sees errors that Echo's types do not mean.

## A short example

The examples in this README are files in a game laid out the way Whiteoak's games are. The tuning lives in one config module, `ReplicatedStorage.Shared.Config.Sounds`, and the client's sound modules sit in `PlayerScripts.Client.Modules.Sounds`. Every recording is a stand-in uploaded by Roblox or its licensed partner Pro Sound Effects, which any experience may play.

The config module, which every example reads its numbers from:

```lua
--[[
    Tuning for the client's sounds: Echo's pools, cap groups and bus, and
    each sound's recordings, volume, range, fade and signal names
--]]

--!strict
return {
	-- Each Mode's voices: 300 cloned at boot, 50 more once 290 are in use, never past 400
	pools = {
		Legacy = { initial = 300, growAt = 290, growBy = 50, ceiling = 400 },
		AudioApi = { initial = 300, growAt = 290, growBy = 50, ceiling = 400 },
	},

	effects = {
		bus = "Effects",
		interactionGroup = "Effects",
		volume = 1,
	},

	reward = {
		signal = "Reward/Chime",
		soundId = "rbxassetid://10128760939", -- RBLX UI Select 01
		volume = 0.5,
		distortion = 0.25,
	},

	rifle = {
		signal = "Gun/Rifle/Fire",
		capGroup = "Gun/Rifle/Remote",
		cap = 8, -- Other players' rifle shots playing at once
		soundId = "rbxassetid://9114725984", -- Gun Single Shot 1
		volume = 0.8,
		fullUntil = 28, -- Studs a shot plays at full volume within
		range = 500, -- Studs past which a shot is silent
		muffle = -12, -- Decibels of high end a shot loses through a wall
	},

	footsteps = {
		signal = "Footstep",
		capGroup = "Footsteps/World",
		cap = 32, -- Footsteps playing at once
		takes = {
			"rbxassetid://108235777827778", -- PlayerStep_Dirt_01
			"rbxassetid://79623150381806", -- PlayerStep_Dirt_02
		},
		volume = 0.4,
	},

	arctic = {
		enter = "Arctic/Enter",
		leave = "Arctic/Leave",
		soundId = "rbxassetid://1516791621", -- Rain Effect
		volume = 0.4,
		fade = 2, -- Seconds the bed takes to swell in or fade out
	},

	radio = {
		soundId = "rbxassetid://15675069601", -- Roblox_UI_Loop_Calm_Music
		volume = 0.3,
		fade = 0.5, -- Seconds the radio takes to fade out when it is turned off
	},

	spin = {
		trigger = "Gun/Minigun/Trigger",
		pause = "Game/Pause",
		soundId = "rbxassetid://9116361270", -- Machine Gun Bursts 1
		volume = 0.7,
		distortion = 0.4,
		overheatLoops = 4, -- Loops the barrel spins before it overheats and stops
	},
}
```

The reward chime, `Client.Modules.Sounds.Reward`, is a component: a function that returns an element.

```lua
--[[
    The reward chime: a 2D one-shot with a touch of distortion, played as a
    new voice each time gameplay fires its signal
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Echo = require(Packages.Echo)

local REWARD_SIGNAL: string = require(ReplicatedStorage.Shared.Config.Sounds).reward.signal
local REWARD_SOUND_ID: string = require(ReplicatedStorage.Shared.Config.Sounds).reward.soundId
local REWARD_VOLUME: number = require(ReplicatedStorage.Shared.Config.Sounds).reward.volume
local REWARD_DISTORTION: number = require(ReplicatedStorage.Shared.Config.Sounds).reward.distortion

return function (): Echo.Element
	local chime: Echo.Ref<Echo.Handle?> = Echo.createRef()

	-- Lives for the client session, as the root does
	Echo.createSignal(REWARD_SIGNAL, function ()
		local handle: Echo.Handle? = chime.current
		if handle then
			handle:play()
		end
	end)

	return Echo.createElement("Sound", {
		Name = "Reward",
		SoundId = REWARD_SOUND_ID,
		Volume = REWARD_VOLUME,
		ref = chime,
	}, {
		Distortion = Echo.createElement("DistortionSoundEffect", { Level = REWARD_DISTORTION }),
	})
end
```

A LocalScript in `StarterPlayerScripts` boots it:

```lua
--[[
    The client's sounds at boot: configures Echo, mounts the reward chime
    in a 2D root, and plays it once
--]]

--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Player = Players.LocalPlayer
local Client = Player.PlayerScripts.Client

local Echo = require(Packages.Echo)

local Reward = require(Client.Modules.Sounds.Reward)

local LEGACY_POOL: Echo.CacheSize = require(ReplicatedStorage.Shared.Config.Sounds).pools.Legacy
local REWARD_SIGNAL: string = require(ReplicatedStorage.Shared.Config.Sounds).reward.signal

Echo.configure({
	mode = "Legacy",
	cache = { Legacy = LEGACY_POOL },
})

Echo:root("Interface", Echo.createElement(Reward))

-- Gameplay fires the signal from anywhere on the client
Echo.useSignal(REWARD_SIGNAL)
```

`configure` makes the Legacy pool and clones its 300 voices. `Echo.createElement(Reward)` calls the component once, which registers the signal and returns the chime's element. `Echo:root` mounts that element under the name `"Interface"`, and a string target plays every voice of the chime in 2D. At the mount the chime's ref receives its handle, so each fire of `"Reward/Chime"` calls `handle:play()`, which takes a free voice from the pool, gives it the chime's recording, volume and distortion, and plays it. Two fires close together play two voices that overlap, and each voice goes back to the pool when its recording ends.

## How each part works

Every block below is a whole file in the game the short example started, and each passes luau-lsp's new type checker against Echo with no diagnostic. The modules sit in `Client.Modules.Sounds`, and the preload section ends in a boot that replaces the short example's LocalScript.

### Configuration and the Mode

`Echo.configure(config)` runs once, on the client, at boot and before the first root. It errors on a second call, on the server, and on any value it cannot use, naming the field, and it checks every field before it does anything.

| Field | Holds |
|---|---|
| `mode` | The game's default Mode, `"AudioApi"` or `"Legacy"`. It must be a Mode `cache` sizes. |
| `cache` | Each Mode's pool size, as `{ [Mode]: { initial, growAt, growBy, ceiling } }`. A Mode left out has no pool, and a root in it errors. |
| `caps` | Optional. Each cap group's name and its limit, a whole number of 1 or more ([Caps and buses](#caps-and-buses)). |
| `buses` | Optional. Each bus's name and the game's own mixing objects for it ([Caps and buses](#caps-and-buses)). |

`configure` fills each pool it names at once. Each of the four sizes is a whole number of 1 or more, `growAt` is at most `initial` and `ceiling` is at least `initial`. A pool starts with `initial` voices and grows by `growBy` each time its free voices fall to `initial - growAt`, never past `ceiling`. With 300, 290, 50 and 400, the pool grows to 350 when 290 voices are in use and to 400 when 340 are. At the ceiling with no free voice, a new play takes that Mode's earliest-started one-shot, which stops at once and fires no `Ended`, and never takes a looping voice. With nothing but looping voices playing at the ceiling, the play starts nothing.

Each Mode's voice is one tree, cloned from one template, with an `Attachment` under `workspace.Terrain` at its root:

| | Legacy | Audio API |
|---|---|---|
| A voice | An `Attachment` holding one `Sound` | An `Attachment` holding an `AudioPlayer`, an `AudioEmitter` and the `Wire` from the player's last stage to its output |
| A 2D play | The `Sound` moves into the `Echo` folder Echo makes under `SoundService` at `configure` | The wire points at its bus's `AudioFader`, or at the `AudioDeviceOutput` Echo makes at `configure` |
| A world play | The `Sound` stays under the `Attachment`, so it is heard at the `Attachment`'s position | The wire points at the emitter |
| A play | `TimePosition = 0`, `Play()` | `Stop()`, `TimePosition = 0`, `Play()` |
| Pause and resume | `Pause()`, `Resume()` | `Stop()`, `Play()`, which keeps `TimePosition` |

A configuration with both Modes, the cap groups and an effects bus, as a module, `Client.Modules.Sounds.Configure`, that the boot calls in place of the short example's own `configure`:

```lua
--[[
    Configures Echo once at client boot: Legacy as the default Mode, a pool
    for each Mode, the cap groups, and the effects bus in both Modes
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Packages = ReplicatedStorage.Packages

local Echo = require(Packages.Echo)

local LEGACY_POOL: Echo.CacheSize = require(ReplicatedStorage.Shared.Config.Sounds).pools.Legacy
local AUDIO_API_POOL: Echo.CacheSize = require(ReplicatedStorage.Shared.Config.Sounds).pools.AudioApi
local RIFLE_CAP_GROUP: string = require(ReplicatedStorage.Shared.Config.Sounds).rifle.capGroup
local RIFLE_CAP: number = require(ReplicatedStorage.Shared.Config.Sounds).rifle.cap
local FOOTSTEP_CAP_GROUP: string = require(ReplicatedStorage.Shared.Config.Sounds).footsteps.capGroup
local FOOTSTEP_CAP: number = require(ReplicatedStorage.Shared.Config.Sounds).footsteps.cap
local EFFECTS_BUS: string = require(ReplicatedStorage.Shared.Config.Sounds).effects.bus
local EFFECTS_INTERACTION_GROUP: string = require(ReplicatedStorage.Shared.Config.Sounds).effects.interactionGroup
local EFFECTS_VOLUME: number = require(ReplicatedStorage.Shared.Config.Sounds).effects.volume

local function wire(source: Instance, target: Instance)
	local connection: Wire = Instance.new("Wire")
	connection.SourceInstance = source
	connection.TargetInstance = target
	connection.Parent = source
end

return function ()
	-- A Legacy voice on the bus joins this group
	local group: SoundGroup = Instance.new("SoundGroup")
	group.Name = EFFECTS_BUS
	group.Volume = EFFECTS_VOLUME
	group.Parent = SoundService

	-- A 2D Audio API voice on the bus wires into this fader, which goes on to the speakers
	local fader: AudioFader = Instance.new("AudioFader")
	fader.Volume = EFFECTS_VOLUME
	fader.Parent = SoundService

	local speakers: AudioDeviceOutput = Instance.new("AudioDeviceOutput")
	speakers.Parent = SoundService
	wire(fader, speakers)

	-- A world Audio API voice on the bus is heard through a listener in the bus's interaction group
	local listener: AudioListener = Instance.new("AudioListener")
	listener.AudioInteractionGroup = EFFECTS_INTERACTION_GROUP
	listener.Parent = Workspace.CurrentCamera
	wire(listener, fader)

	Echo.configure({
		mode = "Legacy",
		cache = { Legacy = LEGACY_POOL, AudioApi = AUDIO_API_POOL },
		caps = { [RIFLE_CAP_GROUP] = RIFLE_CAP, [FOOTSTEP_CAP_GROUP] = FOOTSTEP_CAP },
		buses = {
			[EFFECTS_BUS] = { group = group, fader = fader, interactionGroup = EFFECTS_INTERACTION_GROUP },
		},
	})
end
```

The `cache` and `caps` tables are written in the call from single values. Under the new checker a table read whole from a config module is typed by its own fields, so `require(...).pools` does not check as `{ [Mode]: CacheSize }`, while a table written in the call does.

### Elements, effects and props

`Echo.createElement(kind, props?, children?)` returns an `Element`, a description that owns no instance. `kind` is one of:

- `"Sound"`, the one element that plays.
- One of the nine effect classes, written with its legacy name: `EqualizerSoundEffect`, `DistortionSoundEffect`, `ReverbSoundEffect`, `ChorusSoundEffect`, `CompressorSoundEffect`, `EchoSoundEffect`, `FlangeSoundEffect`, `PitchShiftSoundEffect` or `TremoloSoundEffect`.
- A component, a function called at once with `props`, whose element comes back as it is. A component may return another component's element, at any depth.
- `Echo.Fragment`, whose `props` is a list of components and elements. Each component in it is called with an empty props table.

Any other kind errors, and a missing `props` is an empty table. Only a sound takes children, and only effect elements, keyed by name. An effect element anywhere else errors at mount.

A sound's props are read by key before value:

1. A key from `Echo.Event`, `Echo.Action` or `Echo.Util` ([Events and actions](#events-and-actions), [Caps and buses](#caps-and-buses)). A value of the wrong kind under one errors at the call.
2. `Attributes`, a table of attributes set on each voice while it plays the element and cleared when the voice goes back.
3. By value under a string key: a ref from `createRef` or `useRef` receives the element's handle, a `useState` or `useSpring` value is bound, and any other value sets the property of that name.

A function under a string key errors, and so do `Parent` and `Playing`, which are Echo's own; play a sound through its handle or with `Echo.Action.Play`. A key that is neither a string nor one of Echo's errors too.

Properties are named as on a legacy `Sound` in both Modes. In Legacy mode any writable `Sound` property works. In Audio API mode these are the properties a sound takes, and any other errors at mount, naming it, so a sound module that works in one Mode never fails silently in the other:

| Element property | Legacy | Audio API |
|---|---|---|
| `SoundId` | `Sound.SoundId` | `AudioPlayer.Asset` |
| `Volume`, `PlaybackSpeed`, `TimePosition` | the `Sound`'s own | the `AudioPlayer`'s, same names |
| `Looped` | `Sound.Looped` | `AudioPlayer.Looping` |
| `PlaybackRegion`, `LoopRegion` | the `Sound`'s own | the `AudioPlayer`'s, same names |
| `RollOffMode`, `RollOffMinDistance`, `RollOffMaxDistance` | the `Sound`'s own | the emitter's distance curve, rebuilt from all three |

`Name` is the element's own label, a string or a state holding one, which `Echo.getAll` reports. No voice is given it, so both Modes take it, and a play that overrides it errors.

Every property is checked against its root's Mode when the root mounts, and a mount that fails leaves nothing behind.

An effect child's properties are plain values, set on the voice each time it plays the element; a state there errors at mount. A play can change them for that one play ([Refs, handles and voices](#refs-handles-and-voices)). An effect element never sets `Enabled`, `Bypass`, `Parent` or `Name`, which Echo drives. A voice gets an effect of a class and key the first time it plays an element that has one and keeps it, turned off, when it goes back, so effect instances are made only on a voice's first use of one. In Audio API mode Echo builds the matching class and copies each property of the same name:

| Legacy | Audio API |
|---|---|
| `EqualizerSoundEffect` | `AudioEqualizer` |
| `DistortionSoundEffect` | `AudioDistortion` |
| `ReverbSoundEffect` | `AudioReverb` |
| `ChorusSoundEffect` | `AudioChorus` |
| `CompressorSoundEffect` | `AudioCompressor` |
| `EchoSoundEffect` | `AudioEcho` |
| `FlangeSoundEffect` | `AudioFlanger` |
| `PitchShiftSoundEffect` | `AudioPitchShifter` |
| `TremoloSoundEffect` | `AudioTremolo` |

A property with no match on the Audio API class errors at mount. The effects sit in the voice's chain between the player and its output in order of each effect's `Priority`, highest first, then by key, and `Priority` is copied to nothing. Since an element names the legacy class, a property only the Audio API class has, such as `AudioEqualizer.MidRange`, is refused in both Modes.

Another player's rifle shot, `Client.Modules.Sounds.Rifle`, uses most of these:

```lua
--[[
    Another player's rifle shot: a world voice at the muzzle on the effects
    bus, at most eight at once, its high end cut when a wall is in the way
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Echo = require(Packages.Echo)

local RIFLE_SIGNAL: string = require(ReplicatedStorage.Shared.Config.Sounds).rifle.signal
local RIFLE_CAP_GROUP: string = require(ReplicatedStorage.Shared.Config.Sounds).rifle.capGroup
local RIFLE_SOUND_ID: string = require(ReplicatedStorage.Shared.Config.Sounds).rifle.soundId
local RIFLE_VOLUME: number = require(ReplicatedStorage.Shared.Config.Sounds).rifle.volume
local RIFLE_FULL_UNTIL: number = require(ReplicatedStorage.Shared.Config.Sounds).rifle.fullUntil
local RIFLE_RANGE: number = require(ReplicatedStorage.Shared.Config.Sounds).rifle.range
local RIFLE_MUFFLE: number = require(ReplicatedStorage.Shared.Config.Sounds).rifle.muffle
local EFFECTS_BUS: string = require(ReplicatedStorage.Shared.Config.Sounds).effects.bus

return function (): Echo.Element
	local rifle: Echo.Ref<Echo.Handle?> = Echo.createRef()

	-- Lives for the client session, as the root does
	Echo.createSignal(RIFLE_SIGNAL, function (muzzle: Vector3, muffled: boolean)
		local handle: Echo.Handle? = rifle.current
		if not handle then
			return
		end

		-- The cut is for this one play, and the voice's equalizer is flat again when it goes back
		handle:play({
			at = muzzle,
			Equalizer = muffled and { HighGain = RIFLE_MUFFLE } or nil,
		})
	end)

	return Echo.createElement("Sound", {
		Name = "Rifle",
		SoundId = RIFLE_SOUND_ID,
		Volume = RIFLE_VOLUME,
		RollOffMode = Enum.RollOffMode.Linear,
		RollOffMinDistance = RIFLE_FULL_UNTIL,
		RollOffMaxDistance = RIFLE_RANGE,
		Attributes = { weapon = "Rifle" },
		ref = rifle,

		[Echo.Util.Cap] = RIFLE_CAP_GROUP,
		[Echo.Util.Bus] = EFFECTS_BUS,
	}, {
		Equalizer = Echo.createElement("EqualizerSoundEffect"),
	})
end
```

The equalizer child takes no props, so each play sets nothing on it unless that play's override does. When a voice goes back, Echo sets every property and effect property its play wrote back to its default.

In Audio API mode the three roll-off properties rebuild the emitter's distance curve with the legacy formulas: `Inverse` is `min / d`, `Linear` is `(max - d) / (max - min)`, `LinearSquare` is that squared, and `InverseTapered` is the lesser of `Inverse` and `LinearSquare`, each full below `min` and silent past `max`. The curve is sampled at 32 points between `min` and `max`, spaced geometrically on distance plus one, so the Inverse curve stays close to the legacy one near `min`. A voice starts from the legacy `Sound`'s roll-off, `Inverse` from 10 to 10,000 studs. A write that leaves `min` at or above `max` keeps the voice's last valid curve until the other end arrives. Every other mapped property of an Audio API voice starts at the legacy `Sound`'s default, `Volume` 0.5 among them, so an element that sets none plays at the same level in both Modes.

### Roots and targets

`Echo:root(target, element, mode?)`, called with a colon, mounts an element tree and returns a `Root`. `mode` plays the root in that Mode in place of the default, and must be a Mode `configure` gave a pool. A root before `configure` errors. `root:destroy()` stops every voice of the root at once, ends its bindings and actions and sets its refs back to nil, and a second call does nothing.

The target sets where the root's voices play:

- A `BasePart`, `Attachment` or `Model` is followed while a voice plays. One Heartbeat connection, held only while some voice follows a target, writes each such voice's position from its target every frame. The voice is never parented to the target, so a voice whose target is destroyed or leaves the DataModel keeps playing in full at the target's last position.
- `nil`, a string or any other instance plays in 2D. A string also names the root in `Echo.getAll`.
- A play with `at` is a world voice at that point, whatever its root's target, and never follows.

A play that starts after its root's target has left the DataModel follows nothing and is heard where its pooled voice was parked, so a game destroys a root whose target is gone. No root makes a folder or any instance of its own.

A first-person sound plays from a 2D root, never under a viewmodel or `Tool`, so a shot keeps playing after an unequip.

The mount module, `Client.Modules.Sounds.Mount`, which the boot calls once `configure` has run. It uses the sounds from the sections below:

```lua
--[[
    Mounts the client's sounds once Echo is configured: the 2D and per-play
    sounds in roots of their own, and the radio and turret on their parts
--]]

--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Packages = ReplicatedStorage.Packages
local Player = Players.LocalPlayer
local Client = Player.PlayerScripts.Client

local Echo = require(Packages.Echo)

local Arctic = require(Client.Modules.Sounds.Arctic)
local Footstep = require(Client.Modules.Sounds.Footstep)
local Radio = require(Client.Modules.Sounds.Radio)
local Reward = require(Client.Modules.Sounds.Reward)
local Rifle = require(Client.Modules.Sounds.Rifle)
local Spin = require(Client.Modules.Sounds.Spin)

local Shelf = Workspace:WaitForChild("Shelf") :: BasePart -- Boot-time wait: the map may still be loading
local Turret = Workspace:WaitForChild("Turret") :: Model

return function (): { [string]: Echo.Root }
	local roots: { [string]: Echo.Root } = {
		interface = Echo:root("Interface", Echo.createElement(Echo.Fragment, { Reward, Arctic })),
		weapons = Echo:root("Weapons", Echo.createElement(Echo.Fragment, { Rifle, Footstep })),
		radio = Echo:root(Shelf, Radio:element()),
		turret = Echo:root(Turret, Echo.createElement(Spin), "AudioApi"),
	}

	-- A root whose target is gone plays where its voices were parked, so it goes with the turret
	Turret.Destroying:Connect(function ()
		roots.turret:destroy()
	end)

	return roots
end
```

The rifle and footstep roots are 2D, and each of their plays passes `at`, so every shot and step is a world voice at the point gameplay gives. The radio follows its shelf, and the minigun's spin follows the turret and plays in Audio API mode under the Legacy default.

### State and springs

`Echo.useState(default)` returns `(state, set)`. A state can be bound to any number of properties, an action's included. Each binding takes the state's value at mount and at every play, and `set(value)` writes the value to every live voice the state is bound to, one write each, and re-renders nothing. A value whose type differs from the property's warns and skips that write, and the binding stays. `state.current` reads the value, and its type makes it read-only.

`Echo.useSpring(builder)` calls `builder` once and returns `(styles, api)`. Each number in the table it returns becomes a style, a state that binds like one from `useState`, and every other value is ignored except `config`, which gives the spring's `duration` and `delay` in seconds. A config that leaves either out takes 0 for it, so a spring with no config moves at once, and a fade's time is always the game's.

`api:start(targets)` returns a Promise. Each named style moves linearly from where it is to its target over the duration, after the delay, on Heartbeat in Studio and live alike, and lands exactly on its target, a negative one included. A `config` in the targets replaces the spring's own for that start. A second `start` cancels the first and its Promise, so a fade interrupted by the opposite one ends at the new target, and a duration of 0 sets the targets at once. A target for a name the spring does not hold, or one that is no number, errors at the call.

A voice fading out under `handle:stop` takes no further writes to its `Volume`, so a spring or state bound to it cannot pull it back up.

The arctic zone's ambience bed, `Client.Modules.Sounds.Arctic`, crossfades with a spring:

```lua
--[[
    The arctic zone's ambience bed: a 2D loop that swells in as the player
    enters the zone, fades out as they leave, and stops once it is silent
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Echo = require(Packages.Echo)

local ARCTIC_ENTER: string = require(ReplicatedStorage.Shared.Config.Sounds).arctic.enter
local ARCTIC_LEAVE: string = require(ReplicatedStorage.Shared.Config.Sounds).arctic.leave
local ARCTIC_SOUND_ID: string = require(ReplicatedStorage.Shared.Config.Sounds).arctic.soundId
local ARCTIC_VOLUME: number = require(ReplicatedStorage.Shared.Config.Sounds).arctic.volume
local ARCTIC_FADE: number = require(ReplicatedStorage.Shared.Config.Sounds).arctic.fade

return function (): Echo.Element
	local playing, setPlaying = Echo.useState(false)
	local styles, api = Echo.useSpring(function ()
		return {
			volume = 0,
			config = { duration = ARCTIC_FADE },
		}
	end)

	-- The game's own zone tracker fires these as the player crosses the zone's edge
	Echo.createSignal(ARCTIC_ENTER, function ()
		setPlaying(true)
		api:start({ volume = ARCTIC_VOLUME })
	end)

	-- An enter during the fade cancels this start's Promise, so the bed keeps playing
	Echo.createSignal(ARCTIC_LEAVE, function ()
		api:start({ volume = 0 }):andThen(function ()
			setPlaying(false)
		end)
	end)

	return Echo.createElement("Sound", {
		Name = "Arctic",
		SoundId = ARCTIC_SOUND_ID,
		Looped = true,
		Volume = styles.volume,

		[Echo.Action.Play] = playing,
	})
end
```

Echo has no area binding, so the game's own zone tracker fires the two signals. The same shape retunes a heartbeat: bind its `PlaybackSpeed` to a `useState` value, and each set reaches the voice that is playing and the next play.

### Refs, handles and voices

`Echo.createRef()` and `Echo.useRef(initial)` return `{ current = ... }`, typed `Echo.Ref<Echo.Handle?>`, so `useRef` takes a handle or nil. A ref handed to an element under any string key receives the element's handle when its root mounts, never an instance, and goes back to nil when its root is destroyed.

The handle plays and stops the element's voices:

- `handle:play(overrides?)` starts a voice and returns it. It returns nil only when its Mode's pool is at its ceiling with nothing but looping voices playing. The overrides set any property for that one play, by the same names as the element's props, such as `SoundId`, `RollOffMaxDistance`, `Volume` and `PlaybackSpeed`, a child effect's properties under the child's key, such as `Equalizer = { HighGain = -6 }`, and `at`, a `Vector3` world position. Each override is checked the way a property is at mount, so one the root's Mode refuses errors at the call, naming it. A handle whose root was destroyed errors on `play`.
- `handle:stop(voice?, fade?)` stops that voice, or every live voice of the element when no voice is given. With `fade`, a number of seconds of 0 or more, the voice's `Volume` falls linearly to 0 over that time before the voice goes back. A voice stopped again while it fades stops at once, and a voice that has already ended, been taken or been stopped is left alone with no error, so a game may keep a voice past its end.
- `handle:get()` returns the element's most recently started live voice, or nil.
- `handle:getAll()` returns every live voice of the element, oldest first.

A `Voice` lasts one play. While it plays, `voice.instance` is the pooled `Sound` or `AudioPlayer`, for reading properties such as `TimePosition`. Once the voice is back in the pool it is nil, so a voice a game kept can never reach another element's play. Read the instance and never write to it; the `Voice` type makes the `instance` field itself read-only. A nil `instance` is how a game tells a voice has finished, since `Ended` never fires for a voice Echo took or stopped.

A play sets each property it plays with, `TimePosition = 0` and the effects directly, and sets a `TimePosition` the element or its overrides give once the voice has started. Echo never times anything from `TimeLength`, since an unloaded sound reports a length of 0.

The radio on the shelf, `Client.Modules.Sounds.Radio`, reads its place in the track through its ref:

```lua
--[[
    The radio on the shelf: its loop plays until the player turns it off,
    fading out, and its place in the track is read from its playing voice
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Echo = require(Packages.Echo)

local RADIO_SOUND_ID: string = require(ReplicatedStorage.Shared.Config.Sounds).radio.soundId
local RADIO_VOLUME: number = require(ReplicatedStorage.Shared.Config.Sounds).radio.volume
local RADIO_FADE: number = require(ReplicatedStorage.Shared.Config.Sounds).radio.fade

local Radio = {
	_ref = Echo.createRef(), -- Holds the radio's handle once its root mounts it
}

function Radio.element(self: Self): Echo.Element
	return Echo.createElement("Sound", {
		Name = "Radio",
		SoundId = RADIO_SOUND_ID,
		Volume = RADIO_VOLUME,
		Looped = true,
		ref = self._ref,
	})
end

--[[
    Turns the radio on, unless a voice of it is playing already
--]]

function Radio.play(self: Self)
	local handle: Echo.Handle? = self._ref.current
	if handle and not handle:get() then
		handle:play()
	end
end

--[[
    Turns the radio off, fading out every voice of it
--]]

function Radio.stop(self: Self)
	local handle: Echo.Handle? = self._ref.current
	if handle then
		handle:stop(nil, RADIO_FADE)
	end
end

--[[
    Seconds into its track the radio is, or nil while it is off
--]]

function Radio.position(self: Self): number?
	local handle: Echo.Handle? = self._ref.current
	local voice: Echo.Voice? = handle and handle:get()
	local instance: (Sound | AudioPlayer)? = voice and voice.instance

	return instance and instance.TimePosition
end

type Self = typeof(Radio)

return Radio
```

### Events and actions

An event callback goes under an `Echo.Event` key and receives the voice first:

| Key | Runs | Receives |
|---|---|---|
| `Echo.Event.Ended` | Once per natural end, never on a stop or a take | `(voice)` |
| `Echo.Event.Looped` | At each loop | `(voice, loopCount)` |
| `Echo.Event.Loaded` | When the asset loads, or through `task.defer` when it is loaded already | `(voice)` |
| `Echo.Event.Playing` | Each time a voice starts | `(voice)` |

A voice that ends naturally goes back to the pool before its `Ended` callback runs, so `voice.instance` is nil inside the callback and the next play can take that voice. Each callback runs on a thread of its own, so one that throws or yields never breaks the voice or the play that fired it, and its error shows as that thread's. A callback that returns a function has it run as cleanup as soon as the callback returns, and the element's handler for that event is dropped for every later voice. A voice back in the pool fires none of its callbacks.

An action goes under an `Echo.Action` key and takes a state:

- `[Echo.Action.Play] = state` plays a new voice when the state turns `true`, the state's value at mount included, and stops every live voice of the element when it turns to anything else. It acts only when the value changes, so a `true` written while the state already holds `true` starts nothing, and a loop held while a condition holds never stacks voices.
- `[Echo.Action.Pause] = state` pauses every live voice when the state turns `true` and resumes them when it turns `false`, acting only on a change in the same way. It acts only on the voices live when its state changes, so a voice started while the state holds `true` plays, and turning `false` resumes only the voices it paused that are still live. Its value at mount acts on nothing.

The minigun's barrel spin, `Client.Modules.Sounds.Spin`, a loop held while the trigger is down:

```lua
--[[
    The minigun's barrel spin: a loop held while the trigger is down, paused
    with the game, and stopped once the barrel overheats
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Echo = require(Packages.Echo)

local SPIN_TRIGGER: string = require(ReplicatedStorage.Shared.Config.Sounds).spin.trigger
local SPIN_PAUSE: string = require(ReplicatedStorage.Shared.Config.Sounds).spin.pause
local SPIN_SOUND_ID: string = require(ReplicatedStorage.Shared.Config.Sounds).spin.soundId
local SPIN_VOLUME: number = require(ReplicatedStorage.Shared.Config.Sounds).spin.volume
local SPIN_DISTORTION: number = require(ReplicatedStorage.Shared.Config.Sounds).spin.distortion
local SPIN_OVERHEAT_LOOPS: number = require(ReplicatedStorage.Shared.Config.Sounds).spin.overheatLoops

return function (): Echo.Element
	local spinning, setSpinning = Echo.useState(false)
	local paused, setPaused = Echo.useState(false)

	-- Lives for the client session, as the root does
	Echo.createSignal(SPIN_TRIGGER, function (held: boolean)
		setSpinning(held)
	end)

	Echo.createSignal(SPIN_PAUSE, function (pause: boolean)
		setPaused(pause)
	end)

	return Echo.createElement("Sound", {
		Name = "Spin",
		SoundId = SPIN_SOUND_ID,
		Volume = SPIN_VOLUME,
		Looped = true,

		[Echo.Action.Play] = spinning,
		[Echo.Action.Pause] = paused,

		[Echo.Event.Looped] = function (_voice: Echo.Voice, loopCount: number)
			if loopCount >= SPIN_OVERHEAT_LOOPS then
				setSpinning(false)
			end
		end,
	}, {
		Distortion = Echo.createElement("DistortionSoundEffect", { Level = SPIN_DISTORTION }),
	})
end
```

Setting the state to `false` on overheat stops the voice, and the next trigger pull turns it `true` again and starts a new one.

### Caps and buses

`[Echo.Util.Cap] = "Gun/Rifle/Remote"` puts an element in a cap group, and `config.caps` gives each group's limit. A play past the limit first stops the group's earliest-started voice. Elements share a group by naming it, so the takes of one sound can share one cap, and a cap on a single element is a group of one. The cap is checked before the pool, so a capped play frees its own voice first. A group counts its live voices in both Modes' pools, since an element joins it by name whatever its root's Mode. A group `config.caps` does not hold errors at mount.

`[Echo.Util.Bus] = "Effects"` routes an element's voices to that bus in `config.buses`, which holds the game's own objects:

| Field | The object | Used by |
|---|---|---|
| `group` | A `SoundGroup` | A Legacy voice, which joins it |
| `fader` | An `AudioFader` | A 2D Audio API voice, which wires into it |
| `interactionGroup` | An `AudioInteractionGroup` name | A world Audio API voice, whose emitter joins it |

The game makes these objects and sets their volumes, as the configure module above does. Echo makes no `AudioListener`, so a world Audio API voice on a bus is heard through a listener the game keeps in that bus's interaction group, and a fader is heard once the game wires it to an output. An element with no bus plays straight to the output: a Legacy voice joins no `SoundGroup`, and a 2D Audio API voice wires into Echo's own `AudioDeviceOutput`. An element whose bus `config.buses` does not hold errors at mount.

Every player's footsteps, `Client.Modules.Sounds.Footstep`, share one cap group, and each play picks its take:

```lua
--[[
    Every player's footsteps: one element with no SoundId of its own, each
    play taking the take its signal names at the foot's position
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Echo = require(Packages.Echo)

local FOOTSTEP_SIGNAL: string = require(ReplicatedStorage.Shared.Config.Sounds).footsteps.signal
local FOOTSTEP_CAP_GROUP: string = require(ReplicatedStorage.Shared.Config.Sounds).footsteps.capGroup
local FOOTSTEP_TAKES: { string } = require(ReplicatedStorage.Shared.Config.Sounds).footsteps.takes
local FOOTSTEP_VOLUME: number = require(ReplicatedStorage.Shared.Config.Sounds).footsteps.volume

return function (): Echo.Element
	local step: Echo.Ref<Echo.Handle?> = Echo.createRef()

	-- Lives for the client session, as the root does
	Echo.createSignal(FOOTSTEP_SIGNAL, function (foot: Vector3, take: number)
		local handle: Echo.Handle? = step.current
		local soundId: string? = FOOTSTEP_TAKES[take]
		if handle and soundId then
			handle:play({ SoundId = soundId, at = foot })
		end
	end)

	return Echo.createElement("Sound", {
		Name = "Footstep",
		Volume = FOOTSTEP_VOLUME,
		ref = step,

		[Echo.Util.Cap] = FOOTSTEP_CAP_GROUP,
	})
end
```

The takes reach Echo only as `SoundId` overrides, so no element records them, and the boot hands them to `preload`.

### Signals

- `Echo.createSignal(name, callback)` registers a callback under a name and returns its disconnect, which is safe to call more than once. A callback that returns a function is unsubscribed in the fire that called it, and the function then runs at once, inside that fire.
- `Echo.useSignal(name, ...)` looks the name up directly and calls each callback under it with the arguments, inside the call, with no scan, no copy and no Promise. Every callback runs when one throws, and the first error is then raised at the `useSignal` line. A callback that yields holds up the code that fired it. The callbacks under one name run in no set order, and one subscribed during a fire runs from the next fire.
- A name that holds no signal errors in Studio and warns outside it, so a misspelled name fails loudly while you test and never throws out of live gameplay code.
- `Echo.removeSignal(name)` clears the name's entry, so a signal made again under it fires only its own callbacks. A name stays registered after its last callback disconnects, so firing it does nothing until `removeSignal` clears it.

A signal's name is a string, and any other value errors at the call. Keep every name in one config module, as these examples do. The calls gameplay makes, `Client.Modules.Sounds.Cues`:

```lua
--[[
    The calls gameplay makes for sound: each fires a sound's signal with
    what that sound needs, and none of them touches a voice
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Echo = require(Packages.Echo)

local REWARD_SIGNAL: string = require(ReplicatedStorage.Shared.Config.Sounds).reward.signal
local RIFLE_SIGNAL: string = require(ReplicatedStorage.Shared.Config.Sounds).rifle.signal
local FOOTSTEP_SIGNAL: string = require(ReplicatedStorage.Shared.Config.Sounds).footsteps.signal
local SPIN_TRIGGER: string = require(ReplicatedStorage.Shared.Config.Sounds).spin.trigger

local Cues = {}

function Cues.reward()
	Echo.useSignal(REWARD_SIGNAL)
end

function Cues.shot(muzzle: Vector3, muffled: boolean)
	Echo.useSignal(RIFLE_SIGNAL, muzzle, muffled)
end

function Cues.step(foot: Vector3, take: number)
	Echo.useSignal(FOOTSTEP_SIGNAL, foot, take)
end

function Cues.trigger(held: boolean)
	Echo.useSignal(SPIN_TRIGGER, held)
end

return Cues
```

### Preload and the two reads

`Echo.preload(priority?, ids?)` returns a Promise. Its one `ContentProvider:PreloadAsync` pass takes the SoundIds of the elements under the `priority` roots first, then every other SoundId Echo has recorded, then `ids`, the takes a game plays only as `SoundId` overrides, with each duplicate dropped. `createElement` records each sound's SoundId as it makes the element, a state's value at that moment for a bound one. An empty SoundId names no asset and never joins the pass, and a destroyed root in `priority` gives none.

The Promise resolves with the ids that failed to load, an empty list when none did, so one asset that fails never fails or stalls a loading screen. An id the pass never reports a status for counts as failed. With no id to load it resolves an empty list and makes no pass. It rejects only when `PreloadAsync` itself throws. An entry of `priority` that is not a root Echo made, or an entry of `ids` that is not a string, errors at the call. Assets must be authorized for the experience, or they fail at startup.

Mount every sound at client boot, behind the loading screen, and let the loading screen wait on this Promise. The boot that ties the walkthrough together, a LocalScript in `StarterPlayerScripts` in place of the short example's:

```lua
--[[
    The client's sound boot: configures Echo, mounts every sound, and loads
    their recordings behind the loading screen, the weapons first
--]]

--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Player = Players.LocalPlayer
local Client = Player.PlayerScripts.Client

local Echo = require(Packages.Echo)

local Configure = require(Client.Modules.Sounds.Configure)
local Mount = require(Client.Modules.Sounds.Mount)

local FOOTSTEP_TAKES: { string } = require(ReplicatedStorage.Shared.Config.Sounds).footsteps.takes

Configure()
local roots: { [string]: Echo.Root } = Mount()

-- The footstep takes play only as SoundId overrides, so the pass is handed them
Echo.preload({ roots.weapons }, FOOTSTEP_TAKES)
	:andThen(function (failed: { string })
		for _, id: string in failed do
			warn(`Echo could not load {id}`)
		end
	end)
	:catch(error)
```

A loading screen chains its own step onto the same Promise.

The two reads come from Echo's own counts and records, so they cost nothing on a play:

- `Echo.getCache(mode?)` returns `{ inUse, size }` for one Mode's pool, the default Mode's when none is given. A Mode `config.cache` does not size errors, naming it, and so does a read before `configure`.
- `Echo.getAll()` returns every element of every live root, in mount order, as `{ name, soundId, volume, root }`: its `Name` or nil, its `SoundId` and `Volume` now, and its root's target. An element that sets no `SoundId` reads `""`, and one that sets no `Volume` reads a legacy `Sound`'s default.

A debug overlay's line built from both, `Client.Modules.Sounds.Counts`:

```lua
--[[
    The debug overlay's sound line: each pool's voices in use against its
    size, and how many elements are mounted with no SoundId of their own
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Echo = require(Packages.Echo)

return function (): string
	local legacy: Echo.CacheCount = Echo.getCache("Legacy")
	local audioApi: Echo.CacheCount = Echo.getCache("AudioApi")

	local silent: number = 0
	for _, mounted: Echo.Mounted in Echo.getAll() do
		if mounted.soundId == "" then
			silent += 1
		end
	end

	local pools: string = `Legacy {legacy.inUse}/{legacy.size}, Audio API {audioApi.inUse}/{audioApi.size}`

	return `{pools}, {silent} elements with no SoundId`
end
```

In the game above, the line counts the footstep element, which sets no SoundId of its own.

## Limits

- Echo runs on the client only. `configure` errors on the server, and signals never cross the network.
- `configure` runs once, before the first root, and a root mounted before it errors.
- A pool never grows past its ceiling. At the ceiling with no free voice, a play takes the earliest-started one-shot of its Mode, which stops at once with no `Ended`, and with nothing but loops playing it starts nothing: `handle:play` returns nil, and `Echo.Action.Play` plays nothing.
- A pool grows inside the play that brings it to its growth point, cloning up to `growBy` voices on that frame. In Cellar's benchmark one voice tree took 39 to 67 µs to clone, so a growth step of 50 costs about 2 to 3.4 ms.
- A voice goes back at its natural end, a stop, its cap or the ceiling, and Echo never times a play from `TimeLength`, so a one-shot whose asset never loads and never ends holds its voice until a stop, its cap or the ceiling takes it.
- A play that starts after its root's target has left the DataModel is heard where its pooled voice was parked. Destroy a root whose target is gone.
- Never write to `voice.instance`. When a voice goes back, Echo sets back only what it wrote, so a game's own write can carry into that voice's next play, whichever element plays it.
- Audio API mode takes only the properties in the table under [Elements, effects and props](#elements-effects-and-props), and an effect element only properties its Audio API class shares with the legacy class. A sound module that sets any other errors at mount in that Mode.
- A child effect's properties are plain values, never states.
- Echo makes no `AudioListener`. A world Audio API voice is heard only through a listener the game keeps in its emitter's interaction group, which is the bus's for a voice on a bus.
- A signal callback runs inside `useSignal`, so one that yields holds up the gameplay code that fired it.
- An unregistered signal name errors in Studio and only warns outside it.
- `Echo.Action.Pause`'s value at mount acts on nothing.
- Values under the `Echo.Event`, `Echo.Action` and `Echo.Util` keys are not type-checked, since a props table is typed `{ [any]: any }`. `createElement` checks them when it runs.
- Echo's types are written for the new type checker. The old checker cannot parse their read-only properties and reports false errors on a props table.

## API

Every function is called with a dot on the table the require returns, except `Echo:root`, which takes a colon.

| Member | Returns | What it does |
|---|---|---|
| `Echo.configure(config: Config)` | nothing | Takes the configuration once, on the client, before the first root, and fills each pool. Errors on the server, on a second call and on any value it cannot use. |
| `Echo:root(target: Instance \| string \| nil, element: Element, mode: Mode?)` | `Root` | Mounts an element tree, in `mode` or the default Mode. |
| `Echo.createElement(kind: string \| Component \| typeof(Echo.Fragment), props: Props?, children: { [string]: Element }?)` | `Element` | Makes a sound, an effect, a component's element or a fragment. |
| `Echo.Fragment` | | The kind of an element that groups a list of components and elements. |
| `Echo.useState(default: T)` | `State<T>`, `(value: T) -> ()` | Makes a state and its setter. |
| `Echo.useSpring(builder: () -> { [string]: any })` | `{ [string]: State<number> }`, `SpringApi` | Makes a spring's styles and its `start`. |
| `Echo.createRef()` | `Ref<Handle?>` | Makes an empty ref. |
| `Echo.useRef(initial: Handle?)` | `Ref<Handle?>` | Makes a ref holding `initial`. |
| `Echo.createSignal(name: string, callback: (...any) -> ...(() -> ()))` | `() -> ()` | Registers a callback under a name and returns its disconnect. |
| `Echo.useSignal(name: string, ...: any)` | nothing | Calls every callback under the name, inside the call. |
| `Echo.removeSignal(name: string)` | nothing | Clears the name's entry. |
| `Echo.preload(priority: { Root }?, ids: { string }?)` | Promise of `{ string }` | Preloads in one pass and resolves with the ids that failed. |
| `Echo.getCache(mode: Mode?)` | `CacheCount` | One pool's voices in use and its size. |
| `Echo.getAll()` | `{ Mounted }` | Every mounted element. |
| `Echo.Event.Ended`, `.Looped`, `.Loaded`, `.Playing` | | The event keys of a sound's props. |
| `Echo.Action.Play`, `.Pause` | | The action keys of a sound's props, each taking a state. |
| `Echo.Util.Cap`, `.Bus` | | The keys that name an element's cap group and bus. |
| `root:destroy()` | nothing | Stops the root's voices at once, ends its bindings and sets its refs back to nil. |
| `handle:play(overrides: Overrides?)` | `Voice?` | Starts a voice, or returns nil at the ceiling with only loops playing. |
| `handle:stop(voice: Voice?, fade: number?)` | nothing | Stops one voice or all of the element's, fading over `fade` seconds. |
| `handle:get()` | `Voice?` | The most recently started live voice. |
| `handle:getAll()` | `{ Voice }` | Every live voice, oldest first. |
| `api:start(targets: { [string]: any })` | Promise | Moves each named style to its target, canceling the start before it. |

The exported types, reached as `Echo.Mode`, `Echo.Handle` and so on after the typed install:

| Type | Shape |
|---|---|
| `Mode` | `"AudioApi" \| "Legacy"` |
| `Config` | `{ mode: Mode, cache: { [Mode]: CacheSize }, caps: { [string]: number }?, buses: { [string]: Bus }? }` |
| `CacheSize` | `{ initial: number, growAt: number, growBy: number, ceiling: number }` |
| `Bus` | `{ group: SoundGroup?, fader: AudioFader?, interactionGroup: string? }` |
| `Element` | `{ read kind: string }` |
| `Props` | `{ [any]: any }` |
| `Component` | `(props: Props) -> Element` |
| `State<T>` | `{ read current: T }` |
| `Ref<T>` | `{ current: T }` |
| `Handle` | `play`, `stop`, `get` and `getAll`, as above |
| `Voice` | `{ read instance: (Sound \| AudioPlayer)? }` |
| `Overrides` | `{ [string]: any }` |
| `Root` | `destroy`, as above |
| `Mounted` | `{ name: string?, soundId: string, volume: number, root: Instance \| string \| nil }` |
| `CacheCount` | `{ inUse: number, size: number }` |
| `SpringApi` | `start`, as above |

Each key in `Echo.Event`, `Echo.Action` and `Echo.Util` has a literal type of its own, so `Echo.createElement(Echo.Event.Ended)` is a type error.

## Working on Echo

```sh
rokit install
wally install
lune run tests
```

`rokit install` installs the tools `rokit.toml` pins: Rojo 7.7.0, Wally 0.3.2, StyLua 2.5.2, selene 0.31.0, wally-package-types 1.6.2, Lune 0.10.5 and luau-lsp 1.70.0. `wally install` puts Promise and Cellar in `Packages/`. `lune run tests` runs every case under `tests/Cases/` in path order, each under a fresh fake game that `tests/Environment.luau` builds, with fake `Sound` and `AudioPlayer` instances whose play state a case drives and a fake clock it advances, so the suite tests events, the cache and both Modes without audio. A run where every case passes prints one line and exits with code 0:

```text
151 cases passed
```

The run stops at the first case that fails, printing `Failed`, the case's path under `tests/Cases/` and the reason, and exits with code 1. Text after `tests` runs only the cases whose path starts with it, such as `lune run tests Signals/`.

Every known bug in 7.8.6 has a twin case under `tests/Legacy/`, written to the fixed behavior, so it fails on 7.8.6. `lune run legacy` exports 7.8.6's `src/` from its commit, `606a8ec`, into the gitignored `.legacy/src`, and `lune run tests legacy` runs every twin against it, reporting each as passed or failed with a count at the end. A red legacy run is the record that each case failed on 7.8.6 before the fix, and CI never runs it.

CI's `check` job runs four gates on every pull request, every push to `main` and every release tag: Format, Lint, Analyze and Tests. Each runs the same way by hand from the repo folder, once `rokit install` and `wally install` have run:

```sh
lune run format
git diff --exit-code
selene src dev
rojo sourcemap dev.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
curl -sSfL https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau -o globalTypes.d.luau
luau-lsp analyze --platform=roblox --flag:LuauSolverV2=true --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --ignore="Packages/**" --formatter=gnu src dev
lune run tests
```

Format is the first two lines. `lune run format` runs StyLua over the repo's Luau and puts back the space StyLua takes out after `function` in an anonymous function, and `git diff` then fails on any change it left, so stage your own work first. Lint is `selene`. Analyze needs a sourcemap built from `dev.project.json`, the typed links in `Packages/` and Roblox's type definitions, which the next three lines make, and runs luau-lsp under the new checker. Lint and Analyze cover `dev/` beside `src/`, since Lune cannot run the dev place's scripts and a change to the public API that broke them would otherwise show only in the next live run. Tests is the Lune suite. A release tag such as `v8.0.0` publishes once the gates pass, and only when the tag matches the version in `wally.toml`.

Lune has no audio, so playback, preload and both Modes are proven only in the Studio dev place, `132561817220520`. To serve Echo into it:

1. Open the dev place in Roblox Studio.
2. In the repo folder, run `rojo serve dev.project.json`. It serves on port 34884, the `servePort` in `dev.project.json`.
3. Click Connect in the Rojo plugin, then start a play.

`dev.project.json` mounts `src/` at `ReplicatedStorage.Packages.Echo`, beside Promise, Cellar and `_Index` from `Packages/`, the shape a game's install has, so `wally install` runs before the first serve. The scripts in `dev/` run the live run's checks, the sound pool benchmark and the audible test there against the same public API a game calls. Nothing in `dev/` ships, since `default.project.json` maps only `src/`. Make a timing run with nothing else loading the machine, and throw away a run that overlapped other work.

## License

Echo is licensed under the Apache License 2.0, in `LICENSE`. Versions through 7.8.6 were released under the MIT license.
