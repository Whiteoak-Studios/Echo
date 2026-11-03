--[[
    At a ceiling of 400 with no voice free, a new take gives back the
    earliest-started one-shot and plays on it, a looping take included, and
    never takes a looping voice however early it started
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 400, growAt = 400, growBy = 50, ceiling = 400 }

-- The first two takes loop, then they alternate from a one-shot at the third
local LOOPS_FIRST: number = 2

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")

	Cache.create(MODE, SIZE, FakeBackend.new(env))

	local released: { any } = {}
	local function release(voice: any)
		table.insert(released, voice)
	end

	local voices: { any } = {}
	for take: number = 1, SIZE.ceiling do
		local looped: boolean = take <= LOOPS_FIRST or take % 2 == 0
		table.insert(voices, Cache.take(MODE, { looped = looped, release = release }))
	end

	local oneShot: any = Cache.take(MODE, { looped = false, release = release })
	local stolen: any = voices[LOOPS_FIRST + 1]

	if #released ~= 1 or released[1] ~= stolen then
		return false, "a one-shot at the ceiling did not give back the earliest-started one-shot"
	end

	if not oneShot or oneShot.tree ~= stolen.tree or stolen.instance ~= nil then
		return false, "the one-shot did not play on the voice it took"
	end

	local loop: any = Cache.take(MODE, { looped = true, release = release })
	local nextOneShot: any = voices[LOOPS_FIRST + 3]

	if #released ~= 2 or released[2] ~= nextOneShot or not loop or loop.tree ~= nextOneShot.tree then
		return false, "a looping take at the ceiling did not take the next earliest one-shot"
	end

	for take: number = 1, LOOPS_FIRST do
		if voices[take].instance == nil then
			return false, `the ceiling took the looping voice that started {take}`
		end
	end

	local count: any = Cache.count(MODE)
	if count.inUse ~= SIZE.ceiling or count.size ~= SIZE.ceiling then
		return false, `the pool reads {count.inUse} in use of {count.size} after stealing`
	end

	return true, nil
end
