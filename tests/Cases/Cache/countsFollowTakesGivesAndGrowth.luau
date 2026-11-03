--[[
    Each Mode's count reads its own voices in use and its pool's size after
    takes, gives and growth, and a Mode with no pool refuses a count and a
    take
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local LEGACY: string = "Legacy"
local AUDIO_API: string = "AudioApi"
local LEGACY_SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 3, ceiling = 10 }
local AUDIO_API_SIZE: { [string]: number } = { initial = 2, growAt = 2, growBy = 1, ceiling = 2 }
local FRAME: number = 1 / 60

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local terrain: any = env.game.Workspace.Terrain
	local frames: number = math.ceil(LEGACY_SIZE.growBy / env.require("Constants").GROW_PER_FRAME)

	local function release() end
	local function reads(mode: string, inUse: number, size: number): boolean
		local count: any = Cache.count(mode)
		return count.inUse == inUse and count.size == size
	end

	Cache.create(LEGACY, LEGACY_SIZE, FakeBackend.new(env))

	if pcall(Cache.count, AUDIO_API) or pcall(Cache.take, AUDIO_API, { looped = false, release = release }) then
		return false, "a Mode with no pool gave a count or a voice"
	end

	Cache.create(AUDIO_API, AUDIO_API_SIZE, FakeBackend.new(env))

	if not reads(LEGACY, 0, 4) or not reads(AUDIO_API, 0, 2) then
		return false, "a new pool does not read nothing in use of its initial size"
	end

	local first: any = Cache.take(LEGACY, { looped = false, release = release })
	if not reads(LEGACY, 1, 4) then
		return false, "a take did not count one in use"
	end

	-- Two left free meets the margin of initial less growAt, so the pool grows over its step's frames
	Cache.take(LEGACY, { looped = true, release = release })
	env.step(FRAME * frames)
	if not reads(LEGACY, 2, 7) or #terrain:GetChildren() ~= 7 + 2 then
		return false, "growing did not count its new voices"
	end

	Cache.give(first)
	if not reads(LEGACY, 1, 7) then
		return false, "a give did not count the voice back"
	end

	Cache.take(AUDIO_API, { looped = false, release = release })
	if not reads(AUDIO_API, 1, 2) or not reads(LEGACY, 1, 7) then
		return false, "a take in one Mode moved the other's count"
	end

	return true, nil
end
