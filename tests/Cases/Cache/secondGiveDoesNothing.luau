--[[
    Giving back a voice that is already back does nothing and raises
    nothing: a second give, a give from inside its own release hook, and a
    give of a voice the cap took whose tree another voice now plays on
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 4, growAt = 1, growBy = 1, ceiling = 8 }
local GROUP: string = "Radio"
local LIMIT: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local backend: FakeBackend.FakeBackend = FakeBackend.new(env)

	Cache.create(MODE, SIZE, backend)

	-- The clears since a given point in the call list, since a later voice may play on the same tree
	local function clearsSince(start: number): number
		local count: number = 0
		for index: number = start + 1, #backend.calls do
			if backend.calls[index].name == "clear" then
				count += 1
			end
		end

		return count
	end

	local releases: number = 0
	local voice: any = Cache.take(MODE, {
		looped = false,
		release = function ()
			releases += 1
		end,
	})

	local start: number = #backend.calls
	Cache.give(voice)
	Cache.give(voice)

	if releases ~= 1 or clearsSince(start) ~= 1 then
		return false, `a second give ran the release hook {releases} times and clear {clearsSince(start)} times`
	end

	local inner: any = Cache.take(MODE, {
		looped = false,
		release = function (given: any)
			releases += 1
			Cache.give(given)
		end,
	})

	start = #backend.calls
	Cache.give(inner)

	if releases ~= 2 or clearsSince(start) ~= 1 or inner.instance ~= nil then
		return false, "a give from inside the release hook gave the voice back twice"
	end

	local capped: any = Cache.take(MODE, { looped = false, group = GROUP, limit = LIMIT, release = function () end })
	local current: any = Cache.take(MODE, { looped = false, group = GROUP, limit = LIMIT, release = function () end })

	if capped.instance ~= nil or current.tree ~= capped.tree then
		return false, "the cap did not hand the capped voice's tree to the next take"
	end

	Cache.give(capped)

	if current.instance == nil or Cache.count(MODE).inUse ~= 1 then
		return false, "a give of a voice the cap took gave back the voice now playing on its tree"
	end

	if #env.warnings ~= 0 then
		return false, `a give of a voice already back warned: {env.warnings[1]}`
	end

	return true, nil
end
