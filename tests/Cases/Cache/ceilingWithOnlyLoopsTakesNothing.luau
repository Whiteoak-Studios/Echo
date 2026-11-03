--[[
    A pool at its ceiling with nothing but looping voices out gives no voice
    to a one-shot or a loop and stops none of them, and takes again once a
    loop is given back
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 4, growAt = 4, growBy = 2, ceiling = 6 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")

	Cache.create(MODE, SIZE, FakeBackend.new(env))

	local released: number = 0
	local function release()
		released += 1
	end

	local loops: { any } = {}
	for _ = 1, SIZE.ceiling do
		table.insert(loops, Cache.take(MODE, { looped = true, release = release }))
	end

	if Cache.take(MODE, { looped = false, release = release }) ~= nil then
		return false, "a one-shot got a voice from a pool of nothing but loops at its ceiling"
	end

	if Cache.take(MODE, { looped = true, release = release }) ~= nil then
		return false, "a loop got a voice from a pool of nothing but loops at its ceiling"
	end

	if released ~= 0 then
		return false, `the refused takes gave back {released} loops`
	end

	for index: number, loop: any in loops do
		if loop.instance == nil then
			return false, `loop {index} lost its voice to a refused take`
		end
	end

	local count: any = Cache.count(MODE)
	if count.inUse ~= SIZE.ceiling or count.size ~= SIZE.ceiling then
		return false, `the pool reads {count.inUse} in use of {count.size}`
	end

	Cache.give(loops[1])
	local after: any = Cache.take(MODE, { looped = false, release = release })
	if not after or after.tree ~= loops[1].tree then
		return false, "a take after a loop was given back got no voice"
	end

	return true, nil
end
