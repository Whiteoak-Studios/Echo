--[[
    The dev place's settings: Echo's pools, cap group and buses, the
    stand-in recordings by role, and each count, distance, duration and
    deadline the live run, the benchmarks and the audible test take
--]]

--!strict
return {
	mode = "Legacy", -- The default Mode, which a root naming AudioApi overrides
	pool = { initial = 300, growAt = 290, growBy = 50, ceiling = 400 }, -- Each Mode's pool, the benchmark's size
	voicesFolder = "EchoDevVoices", -- The Folder under Workspace that both pools' voices live and play in

	-- The one bus: its SoundGroup and AudioFader, and the interaction group its listener at the camera hears
	bus = { name = "Effects", interactionGroup = "Effects", volume = 1 },

	-- Every recording is Roblox's own or its partner Pro Sound Effects', which any experience may play
	recordings = {
		oneShots = {
			"rbxassetid://9114725984",
			"rbxassetid://9114726497",
			"rbxassetid://9114726253",
			"rbxassetid://9114726684",
			"rbxassetid://9114726695",
			"rbxassetid://9114726893",
			"rbxassetid://9114726947",
			"rbxassetid://9114726956",
			"rbxassetid://9114727096",
			"rbxassetid://9114727110",
			"rbxassetid://9114729302",
			"rbxassetid://9114729298",
		},

		-- Kept for b2, played by nothing in a play session before it preloads them
		b2 = {
			"rbxassetid://3149249837",
			"rbxassetid://12222132",
			"rbxassetid://12222065",
			"rbxassetid://12222084",
			"rbxassetid://11900833",
			"rbxassetid://12222005",
		},

		-- Kept for b4, one for each Mode, held by nothing through its idle
		b4 = { "rbxassetid://12222030", "rbxassetid://17283613561" },

		rapidFire = { "rbxassetid://9116361270", "rbxassetid://9116357058" },
		footsteps = { "rbxassetid://108235777827778", "rbxassetid://79623150381806", "rbxassetid://9118252696" },
		loops = { "rbxassetid://1516791621", "rbxassetid://15675069601" },
		interface = { "rbxassetid://10066931761", "rbxassetid://10128760939", "rbxassetid://15675059323" },
		neverLoads = "rbxassetid://1", -- No asset has this id, so it never loads
	},

	-- Seconds a job waits for each thing before it fails naming it
	deadlines = { load = 15, preload = 60, ended = 15, character = 30, settle = 1 },

	distance = 20, -- Studs from the camera a world play sits
	tolerance = 0.01, -- How far a position, a gain or a curve point may read from what was set
	propSize = Vector3.new(1, 1, 1), -- The Part a root follows in outlives

	preload = { priority = 4, others = 4 }, -- One-shots under the priority root, then under the other root
	engine = { cut = 0.2, seek = 0.5, endedMargin = 0.5, curve = { [0] = 1, [20] = 0.5, [80] = 0 } },
	cut = 0.2, -- Seconds of play before outlives destroys the Part and unequip the Tool
	fade = { seconds = 0.5, tolerance = 0.15 },
	restart = { cut = 0.3, maxDistance = 60 },
	effects = { highGain = -6 },
	neverLoadsWatch = 30,

	-- The emitter presets beside Echo's sampled curve, heard only by the curves job's own listener
	curves = {
		bus = "Curves",
		interactionGroup = "EchoDevCurves",
		min = 10,
		max = 100,
		distances = { 5, 10, 25, 50, 90 },
		volume = 0.5, -- A legacy Sound's default, which an Audio API voice starts at
		settle = 0.3,
		window = 0.5,
	},

	b1 = { plays = 101, maxFrames = 120 },
	b3 = { voices = 150, idle = 10, busy = 10, radius = 60, seed = 8 },
	b4 = { idle = 600 },

	audible = {
		wall = { forward = 15, right = 10, size = Vector3.new(16, 16, 2) },
		open = { forward = 30, right = -10 },
		behind = { forward = 30, right = 10 },
		footsteps = { forward = 30, from = -10, to = 40, stepSeconds = 0.4, walkSpeed = 16 },
		rapidFire = { group = "EchoDev/RapidFire", limit = 12, signal = "EchoDev/RapidFire", fires = 20, seconds = 2 },
		listen = 2.5, -- Seconds each one-shot is given to play out
		gap = 1, -- Seconds of quiet between two parts of the sequence
		rapidHold = 3,
		loopVolume = 0.5,
		loopHold = 3,
		crossfade = 2,
		interfaceGap = 0.6,
	},

	-- The click jobs, each ending at whichever of the two runs out first
	click = {
		clicks = 20, -- Clicks a click job measures
		seconds = 120, -- Seconds a click job takes clicks for
	},

	-- The panel's buttons, in the order the timing runs go
	panel = { "b2", "b1", "b3", "b4", "audible", "audibleLegacy", "click", "clickLegacy" },
}
