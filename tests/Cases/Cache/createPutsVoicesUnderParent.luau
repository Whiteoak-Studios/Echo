--[[
    A pool created with a parent makes its initial voices as that parent's
    children and leaves Terrain empty, and a pool created with no parent
    makes them under Terrain
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

return function (): (boolean, string | nil)
	-- 1) A folder under Workspace holds every voice of the pool given it
	local env: Environment.Environment = Environment.new()
	local terrain: any = env.game.Workspace.Terrain

	local folder: any = env.Instance.new("Folder")
	folder.Parent = env.game.Workspace

	env.require("Cache").create(MODE, SIZE, FakeBackend.new(env), folder)

	if #folder:GetChildren() ~= SIZE.initial then
		return false, `the parent holds {#folder:GetChildren()} voices, not {SIZE.initial}`
	elseif #terrain:GetChildren() ~= 0 then
		return false, `Terrain holds {#terrain:GetChildren()} voices of a pool given a parent`
	end

	-- 2) With no parent, Terrain holds them
	local bare: Environment.Environment = Environment.new()
	local bareTerrain: any = bare.game.Workspace.Terrain

	bare.require("Cache").create(MODE, SIZE, FakeBackend.new(bare))

	if #bareTerrain:GetChildren() ~= SIZE.initial then
		return false, `with no parent Terrain holds {#bareTerrain:GetChildren()} voices, not {SIZE.initial}`
	end

	return true, nil
end
