--[[
    A take that finds no free voice while a growth step runs gets a voice
    made at once, the size reading one more at once, and the step still ends
    with initial and growBy voices in all
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 4, growAt = 4, growBy = 10, ceiling = 40 }
local FRAME: number = 1 / 60
local AHEAD: number = 3 -- Takes past the initial before any frame of the step runs
local AFTER: number = 60 -- Frames run once the step should have ended

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local terrain: any = env.game.Workspace.Terrain
	local heartbeat: any = env.game:GetService("RunService").Heartbeat

	Cache.create(MODE, SIZE, FakeBackend.new(env))

	local function take(): any
		return Cache.take(MODE, { looped = false, release = function () end })
	end

	-- Every initial voice out meets the margin, so the step starts with nothing made yet
	for _ = 1, SIZE.initial do
		take()
	end

	if Cache.count(MODE).size ~= SIZE.initial then
		return false, `the take that started the step left the pool at {Cache.count(MODE).size} voices`
	end

	for ahead: number = 1, AHEAD do
		local voice: any = take()
		if not voice or not voice.instance then
			return false, `take {ahead} past the initial waited on the step instead of playing at once`
		end

		local count: any = Cache.count(MODE)
		if count.size ~= SIZE.initial + ahead or count.inUse ~= SIZE.initial + ahead then
			return false, `take {ahead} past the initial left the pool at {count.inUse} in use of {count.size}`
		end
	end

	env.step(FRAME * AFTER)

	local size: number, children: number = Cache.count(MODE).size, #terrain:GetChildren()
	if size ~= SIZE.initial + SIZE.growBy or children ~= size then
		return false, `the step ended at {size} voices with {children} under Terrain, not {SIZE.initial + SIZE.growBy}`
	elseif env.connections(heartbeat) ~= 0 then
		return false, "the ended step kept its Heartbeat connection"
	end

	return true, nil
end
