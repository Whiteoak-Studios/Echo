--[[
    A pool of 300 that grows by 50 when ten voices are left free still holds
    300 at 290 voices in use and 350 once its step's frames pass, then 400 at
    340, and stops at its ceiling, every voice cloned from the one template
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 300, growAt = 290, growBy = 50, ceiling = 400 }
local FRAME: number = 1 / 60

-- Each in-use count to take up to, the pool's size right after, and its size once a step's frames pass
local STEPS: { { number } } = {
	{ 289, 300, 300 },
	{ 290, 300, 350 },
	{ 339, 350, 350 },
	{ 340, 350, 400 },
	{ 400, 400, 400 },
	{ 401, 400, 400 },
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local backend: FakeBackend.FakeBackend = FakeBackend.new(env)
	local terrain: any = env.game.Workspace.Terrain
	local frames: number = math.ceil(SIZE.growBy / env.require("Constants").GROW_PER_FRAME)

	Cache.create(MODE, SIZE, backend)

	local function release() end

	-- The pool's size and Terrain's voices, which match whenever the pool reads true
	local function holds(size: number, when: string): string?
		local count: number, children: number = Cache.count(MODE).size, #terrain:GetChildren()
		if count ~= size or children ~= size then
			return `{when} the pool holds {count} voices with {children} under Terrain, not {size}`
		end

		return nil
	end

	local taken: number = 0
	for _, step: { number } in STEPS do
		local takes: number, size: number, grown: number = step[1], step[2], step[3]

		for _ = taken + 1, takes do
			if not Cache.take(MODE, { looped = false, release = release }) then
				return false, `take {taken + 1} gave no voice`
			end

			taken += 1
		end

		local right: string? = holds(size, `right after {takes} takes`)
		if right then
			return false, right
		end

		env.step(FRAME * frames)

		local later: string? = holds(grown, `{frames} frames after {takes} takes`)
		if later then
			return false, later
		end
	end

	local templates: number = 0
	for _, call: FakeBackend.Call in backend.calls do
		if call.name == "template" then
			templates += 1
		end
	end

	if templates ~= 1 then
		return false, `growing built {templates} templates`
	end

	return true, nil
end
