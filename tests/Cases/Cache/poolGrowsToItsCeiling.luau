--[[
    A pool of 300 that grows by 50 when ten voices are left free reaches 350
    with 290 voices in use and 400 with 340, then stops at its ceiling, every
    voice cloned under Terrain from the one template
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 300, growAt = 290, growBy = 50, ceiling = 400 }

-- Each in-use count to take up to, and the pool's size there
local STEPS: { { number } } = {
	{ 289, 300 },
	{ 290, 350 },
	{ 339, 350 },
	{ 340, 400 },
	{ 400, 400 },
	{ 401, 400 },
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local backend: FakeBackend.FakeBackend = FakeBackend.new(env)
	local terrain: any = env.game.Workspace.Terrain

	Cache.create(MODE, SIZE, backend)

	local function release() end

	local taken: number = 0
	for _, step: { number } in STEPS do
		local takes: number, size: number = step[1], step[2]

		for _ = taken + 1, takes do
			if not Cache.take(MODE, { looped = false, release = release }) then
				return false, `take {taken + 1} gave no voice`
			end

			taken += 1
		end

		local count: any = Cache.count(MODE)
		if count.size ~= size then
			return false, `after {takes} takes the pool holds {count.size} voices, not {size}`
		end

		if #terrain:GetChildren() ~= size then
			return false, `after {takes} takes Terrain holds {#terrain:GetChildren()} voices, not {size}`
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
