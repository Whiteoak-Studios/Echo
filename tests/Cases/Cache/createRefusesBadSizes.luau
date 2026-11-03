--[[
    A pool size with a field that is no whole number of 1 or more, a growAt
    past its initial, a ceiling below it or only some growth fields fails at
    create naming the field and builds nothing, and initial alone is accepted
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local FIXED_MODE: string = "AudioApi"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local FIXED: { [string]: number } = { initial = 4 }

type Bad = {
	field: string,
	value: any,
}

-- Each one breaks the good size in one field, and a nil leaves that growth field out
local BAD: { Bad } = {
	{ field = "initial", value = 0 },
	{ field = "initial", value = 2.5 },
	{ field = "initial", value = "4" },
	{ field = "growAt", value = -1 },
	{ field = "growAt", value = 5 },
	{ field = "growBy", value = 0 },
	{ field = "growBy", value = 0 / 0 },
	{ field = "ceiling", value = math.huge },
	{ field = "ceiling", value = 3 },
	{ field = "growAt", value = nil },
	{ field = "growBy", value = nil },
	{ field = "ceiling", value = nil },
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local backend: FakeBackend.FakeBackend = FakeBackend.new(env)
	local terrain: any = env.game.Workspace.Terrain

	for _, bad: Bad in BAD do
		local size: { [string]: any } = table.clone(SIZE)
		size[bad.field] = bad.value

		local created: boolean, message: any = pcall(Cache.create, MODE, size, backend)
		if created then
			return false, `create took {bad.value} as the {bad.field}`
		elseif not tostring(message):find(bad.field, 1, true) then
			return false, `create refused {bad.value} as the {bad.field} without naming it: {message}`
		end
	end

	if #backend.calls ~= 0 or #terrain:GetChildren() ~= 0 then
		return false, "a refused create built a template or voices"
	end

	Cache.create(MODE, SIZE, backend)
	if #terrain:GetChildren() ~= SIZE.initial or #env.warnings ~= 0 then
		return false, "a good create after the refused ones did not fill its pool cleanly"
	end

	local fixed: boolean, reason: any = pcall(Cache.create, FIXED_MODE, FIXED, backend)
	if not fixed then
		return false, `create refused a pool of initial alone: {reason}`
	elseif Cache.count(FIXED_MODE).size ~= FIXED.initial or #env.warnings ~= 0 then
		return false, "a pool of initial alone did not fill to its initial cleanly"
	end

	return true, nil
end
