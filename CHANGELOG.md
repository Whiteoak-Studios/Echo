# Changelog

Every notable change to Echo is recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 8.0.0 - 2026-11-03

8.0.0 rewrites Echo whole. It keeps the React shape of 7.8.6, with components, `createElement`, `Fragment`, `root`, `useState`, `useSpring`, refs, events, actions and signals, and plays every sound from pools of voices in either of Roblox's sound systems. Most calls change what they take or return, so a game moves to it by hand.

### Moving from 7.8.6

1. Replace the dependency line with `Echo = "fadeluc-123/echo@^8.0.0"`. Echo now installs its own Promise and Cellar, so a game drops the `Promise` and `Sift` lines it listed only for Echo's sake.
2. Run the typed install in the README, then change `local Echo: any = require(Packages.Echo)` to the bare `local Echo = require(Packages.Echo)`.
3. Call `Echo.configure` once at client boot, before the first root, with the default Mode and a pool size for each Mode the game plays in.
4. Mount each tree with `Echo:root(target, element, mode?)`. Root a sound that follows a moving object on that object, play a one-shot at a point with `handle:play({ at = position })`, and play first-person and interface sounds from a 2D root, such as one named by a string. A root no longer makes or reuses a folder.
5. A ref now receives the element's handle, never a `Sound`. Read a sound's state through `ref.current:get()`, which gives the voice that is playing, and `voice.instance`, which is nil once that voice is done.
6. Play a one-shot with `handle:play()`, which starts a new voice each time. `[Echo.Action.Play]` now acts only when its state changes, so writing `true` again no longer restarts a sound.
7. Event callbacks now receive the voice first: `Looped` gets `(voice, loopCount)` where it got `(soundId, count)`, and `Playing` gets `(voice)` each time a voice starts where it got the `Playing` state. Remove any debounce on `Ended`, which now runs once per natural end and never on a stop.
8. Replace `[Echo.Util.Cache]` with `[Echo.Util.Cap]` and a limit in `config.caps`, and route a sound to a `SoundGroup` or an `AudioFader` with `[Echo.Util.Bus]` and `config.buses`.
9. Replace `Echo.createBinding(Echo.Bind.Area, ...)` with the game's own zone tracker firing a signal on enter and leave.
10. Fire signals by name, never through a table. A name that holds no signal errors in Studio and warns live, where 7.8.6 waited 5 seconds and warned.
11. Give every spring its fade time in its `config`. A spring whose config leaves out `duration` or `delay` takes 0 for it, where 7.8.6 moved over 1 second.
12. Give a child effect plain values, since a state there errors at mount, and drop any `Parent` or `Playing` prop, which now errors.
13. Mount every sound at client boot behind the loading screen, and have the loading screen wait on `Echo.preload`.

### Changed

- Echo's source is strict-mode `.luau` written for luau-lsp's new type checker, and a game requires it bare with full types after the typed install. 7.8.6 had to be required `: any`, since its types refused an event or action key in props, a setter called with a value and a component handed to `createElement`.
- An element is a description that owns no instance. Each play takes a pooled voice, sets the element's properties on it and gives it back once it ends, so Echo makes no instance per element or per play.
- `Echo:root(target, element, mode?)` mounts any element, at any depth, and returns a root with `destroy()`. A `BasePart`, `Attachment` or `Model` target is followed while a voice plays, and a voice whose target is destroyed keeps playing in full where it was. `nil`, a string or any other instance plays in 2D. 7.8.6's `Echo:root(parent, elements)` parented each sound's instance and made folders for a string or a missing parent.
- A ref receives the element's handle at mount, never an instance, and goes back to nil when its root is destroyed. `createRef` and `useRef` are typed as refs to a handle, so `useRef` takes a handle or nil.
- Every event callback receives the voice first. A voice that ends naturally goes back to the pool before its `Ended` callback runs, so `voice.instance` is nil inside it, and every callback runs on a thread of its own, so one that throws or yields never breaks the voice.
- `[Echo.Action.Play]` acts only when its state changes, and treats any value other than `true` as a stop. `[Echo.Action.Pause]` acts on the voices live when its state changes, and turning it `false` resumes only the voices it paused.
- `Echo.useSignal` runs every callback inside the call, in no set order, with no Promise. Every callback runs when one throws, and the first error is raised at the `useSignal` line. A name that holds no signal errors in Studio and warns live.
- `Echo.createSignal` returns the callback's disconnect.
- A spring whose config leaves out `duration` or `delay` takes 0 for it, so every fade's time comes from the game.
- `Name` is the element's own label, a string or a state holding one, which `Echo.getAll` reports. No voice is given it, and a play's override of it errors.
- A child effect's properties are plain values, set once per play, and a play's override changes them for that play.
- A sound's props are read by key before value. `Parent`, `Playing` and a function under a string key each error.
- Echo checks what a game passes before anything plays: `configure` errors on an unknown field and on a default Mode its `cache` gives no pool, a cap group or bus the configuration lacks errors at mount, a play's override is checked the way a property is, and `play` on a handle whose root was destroyed errors.
- Every require inside the package is relative, and Echo requires its own Promise and Cellar beside it. 7.8.6 required `ReplicatedStorage.Packages.Promise`, `.Sift` and `.Cache`, which broke in a game with other aliases.
- Echo is licensed under the Apache License 2.0. Versions through 7.8.6 were released under the MIT license.

### Added

- `Echo.configure(config)`, taking the default Mode, each Mode's pool size, each cap group's limit, the buses, and optionally `parent`, the instance every voice lives and plays in (`workspace.Terrain` when it is not given). It warns once at boot when the Audio API pool can hold more than 150 voices, past which the engine may leave the voices made last silent, and `warnAudioApiLimit = false` silences that warning.
- The Mode: `"Legacy"` plays a voice on a `Sound`, and `"AudioApi"` plays it on an `AudioPlayer` with its own `AudioEmitter` and `Wire`. The same element description plays in both, and a root's third argument overrides the default Mode. Audio API mode rebuilds the emitter's distance curve from the legacy roll-off properties and builds the matching Audio API effect for each legacy effect class.
- Pools of voices on Cellar, one per Mode, which grow by a set step up to a ceiling, adding a step's voices 5 a frame, or stay fixed at their initial size when given no growth fields. At the ceiling a new play takes the earliest-started one-shot and never a looping voice.
- Handles: `handle:play(overrides?)` returns the voice it started, `handle:stop(voice?, fade?)` stops one voice or all of the element's, fading when given a time, and `handle:get()` and `handle:getAll()` read the live voices. Overrides set any property for one play, a child effect's properties under its key and `at`, a world position.
- `[Echo.Util.Cap]` and `config.caps`, cap groups that several elements share. A play past a group's limit stops the group's earliest-started voice.
- `[Echo.Util.Bus]` and `config.buses`, which route an element's voices to the game's own `SoundGroup`, `AudioFader` and `AudioInteractionGroup`.
- `Echo.preload(priority?, ids?)`, a pass over every recorded SoundId, the priority roots' first and the given ids last, that holds each id on an idle `AudioPlayer` of its own for the rest of the session, so a pooled voice switched to it starts at once, and resolves with the ids not ready after 10 seconds.
- `Echo.getCache(mode?)`, one pool's voices in use and its size, and `Echo.getAll()`, every mounted element's name, SoundId, volume and root.
- `root:destroy()`, which stops the root's voices at once, ends its bindings and sets its refs back to nil.
- The exported types `Mode`, `Config`, `CacheSize`, `Bus`, `Element`, `Props`, `Component`, `State<T>`, `Ref<T>`, `Handle`, `Voice`, `Overrides`, `Root`, `Mounted`, `CacheCount` and `SpringApi`, reached as `Echo.Handle` and so on after the typed install. Each key in `Echo.Event`, `Echo.Action` and `Echo.Util` has a literal type of its own.
- Moonwave doc comments on the public API.

### Removed

- The area binding: `Echo.createBinding`, `Echo.Bind` with `Bind.Area`, and the zone tracker behind it. A game tracks its zones with its own tracker and fires a signal on enter and leave.
- `Echo.Util.Cache`. Every element plays from the cache with no key.
- `Echo.Signals`, the table 7.8.6 kept its signals in. A signal is reached by its name.
- The dependency on Sift (`csqrl/sift@0.0.11`).
- The ObjectCache line (`objectcache@2.4.0`), which nothing in Echo required. Echo's pools run on Cellar (`fadeluc-123/cellar@^0.1.0`).
- The third-party code 7.8.6 carried: the zone tracker from OT-AM and a Signal class from Roblox. Echo's signals run on a class of its own.

### Fixed

Each line names a known limit of 7.8.6 by its number and says how 8.0.0 behaves.

1. Requiring Echo connects nothing, tracks no character and makes no instance.
2. A spring moves on Heartbeat in Studio and live alike, and lands exactly on its target at its duration.
3. No root makes a folder, and a root with no target makes no new `Sounds` folder.
4. A bound property survives a set of another type, `nil` included: the set warns and is skipped, and the binding stays. Each set is one write, with no attribute beside it.
5. An action receives its state's value at mount, so `[Echo.Action.Play] = useState(true)` plays at mount.
6. `Echo.Event.Ended` runs once per natural end and never on a stop.
7. `Echo.Event.Loaded` fires, through `task.defer`, for a sound that is already loaded.
8. `useSignal` takes a name and looks its signal up directly, and a value that is not a string errors at the call.
9. A signal created again after `removeSignal` fires only its own callbacks, since `removeSignal` clears the name's entry.
10. Gone with the area binding, which numbered every area `Area1`.
11. A sound's props are read by key before value, so a value under one of Echo's keys is never taken for a ref or an event, and the cache needs no key.
12. The manifest lists no ObjectCache, and a game installs one Cellar, which Echo requires.
13. The README names no `Echo.Binds.Area` or `Echo.Bind`, and every Luau block in it parses and checks under the new type checker.
14. A throwing `createSignal` callback raises its error at the fire after every other callback under the name has run, and an error in `createSignal`'s own setup raises at the call.
15. `useSpring` makes a style only of a number.
16. A spring moves through negative values with no jump and no error.
17. A second `api:start` cancels the first and its Promise, so a fade interrupted by the opposite one ends at the new target, and a duration of 0 sets the targets at once.
18. A state's default reaches every property bound to it, an action's included, and a spring's styles do the same.
19. Removing an element after any sequence of sets never throws.
20. `createElement` and `root` take any nesting depth, so a component that returns another component's element mounts, and so does a bare `"Sound"` element handed to `root`.
21. Gone with the area binding, whose tracker waited for a `HumanoidRootPart` and missed characters already present.
22. `useSignal` builds no Promise, scans no other signal and copies nothing.
23. `createElement` with no props works, and a fragment refuses an entry that is neither a component nor an element.
