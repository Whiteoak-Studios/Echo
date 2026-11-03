--[[
    A pool size that is not whole numbers of 1 or more, whose growAt exceeds
    its initial or whose ceiling is below it, fails at create naming the
    field, and declares and builds nothing
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

type Bad = {
	field: string,
	value: any,
}

-- Each one breaks the good size in one field
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

	return true, nil
end
