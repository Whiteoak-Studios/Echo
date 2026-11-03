--[[
    A growth step makes GROW_PER_FRAME voices each Heartbeat and fewer on its
    last, on one Heartbeat connection that two pools growing at once share,
    held only until every step has made its voices
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local LEGACY: string = "Legacy"
local AUDIO_API: string = "AudioApi"
local FRAME: number = 1 / 60
local AFTER: number = 30 -- Frames run once every step has ended, in which nothing more is made

-- The Legacy step's voices past its first two frames, which its third and last frame makes
local REMAINDER: number = 2

type Row = {
	act: () -> (),
	legacy: number, -- The Legacy pool's size after the act
	audioApi: number,
	connections: number, -- The Heartbeat connections held after the act
	when: string,
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local terrain: any = env.game.Workspace.Terrain
	local heartbeat: any = env.game:GetService("RunService").Heartbeat
	local perFrame: number = env.require("Constants").GROW_PER_FRAME

	-- Five takes leave the Legacy pool at its margin, and four empty the Audio API pool, whose ceiling cuts its step
	local legacySize: { [string]: number } =
		{ initial = 10, growAt = 5, growBy = perFrame * 2 + REMAINDER, ceiling = 100 }
	local audioApiSize: { [string]: number } =
		{ initial = 4, growAt = 4, growBy = perFrame * 4, ceiling = 4 + perFrame }
	local legacyEnd: number = legacySize.initial + legacySize.growBy
	local audioApiEnd: number = audioApiSize.ceiling

	Cache.create(LEGACY, legacySize, FakeBackend.new(env))
	Cache.create(AUDIO_API, audioApiSize, FakeBackend.new(env))

	local function release() end

	local function take(mode: string, count: number): () -> ()
		return function ()
			for _ = 1, count do
				Cache.take(mode, { looped = false, release = release })
			end
		end
	end

	local function frames(count: number): () -> ()
		return function ()
			env.step(FRAME * count)
		end
	end

	local rows: { Row } = {
		{ act = frames(1), legacy = 10, audioApi = 4, connections = 0, when = "before any take" },
		{
			act = take(LEGACY, 5),
			legacy = 10,
			audioApi = 4,
			connections = 1,
			when = "right after the Legacy step started",
		},
		{
			act = frames(1),
			legacy = 10 + perFrame,
			audioApi = 4,
			connections = 1,
			when = "one frame into the Legacy step",
		},
		{
			act = take(AUDIO_API, 4),
			legacy = 10 + perFrame,
			audioApi = 4,
			connections = 1,
			when = "right after the Audio API step joined the running one",
		},
		{
			act = frames(1),
			legacy = 10 + perFrame * 2,
			audioApi = audioApiEnd,
			connections = 1,
			when = "two frames into the Legacy step",
		},
		{
			act = frames(1),
			legacy = legacyEnd,
			audioApi = audioApiEnd,
			connections = 0,
			when = "once both steps ended",
		},
		{
			act = frames(AFTER),
			legacy = legacyEnd,
			audioApi = audioApiEnd,
			connections = 0,
			when = `{AFTER} frames on`,
		},
	}

	for _, row: Row in rows do
		row.act()

		local legacy: number, audioApi: number = Cache.count(LEGACY).size, Cache.count(AUDIO_API).size
		local held: number, children: number = env.connections(heartbeat), #terrain:GetChildren()

		if legacy ~= row.legacy or audioApi ~= row.audioApi or children ~= legacy + audioApi then
			local holding: string = `{legacy} and {audioApi} with {children} under Terrain`
			return false, `{row.when} the pools hold {holding}, not {row.legacy} and {row.audioApi}`
		elseif held ~= row.connections then
			return false, `{row.when} the pools hold {held} Heartbeat connections, not {row.connections}`
		end
	end

	return true, nil
end
