--[[
    A voice given back has its release hook and the backend's clear run
    before Cellar takes it back under Terrain, its instance set to nil, and
    is never parented to nil on the way
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 2, growAt = 1, growBy = 1, ceiling = 4 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local backend: FakeBackend.FakeBackend = FakeBackend.new(env)
	local terrain: any = env.game.Workspace.Terrain

	Cache.create(MODE, SIZE, backend)

	-- A folder outside Terrain, so the parent Cellar's rebound writes back is what shows it ran
	local holder: any = env.Instance.new("Folder")
	holder.Parent = env.game.Workspace

	local order: { string } = {}
	local releasedWith: any = nil
	local parentAtClear: any = nil

	local clear: (tree: any) -> () = backend.clear
	backend.clear = function (tree: any)
		table.insert(order, "clear")
		parentAtClear = tree.Parent
		clear(tree)
	end

	local voice: any = Cache.take(MODE, {
		looped = false,
		release = function (given: any)
			table.insert(order, "release")
			releasedWith = given
			given.tree.Parent = holder
		end,
	})

	local tree: any = voice.tree
	if tree.Parent ~= terrain or voice.instance ~= tree:FindFirstChild("Sound") then
		return false, "a taken voice is not a pooled tree under Terrain playing its own Sound"
	end

	local parentedToNil: boolean = false
	tree.AncestryChanged:Connect(function (_: any, parent: any)
		if parent == nil then
			parentedToNil = true
		end
	end)

	Cache.give(voice)

	if order[1] ~= "release" or order[2] ~= "clear" or releasedWith ~= voice then
		return false, `the give ran {table.concat(order, ", ")}, not the voice's release hook and then clear`
	end

	if parentAtClear ~= holder or tree.Parent ~= terrain then
		return false, "clear did not run before Cellar gave the tree back under Terrain"
	end

	if parentedToNil or voice.instance ~= nil then
		return false, "the given-back voice was parented to nil or kept its instance"
	end

	if Cache.count(MODE).inUse ~= 0 then
		return false, "the given-back voice still counts as in use"
	end

	local again: any = Cache.take(MODE, { looped = false, release = function () end })
	if again.tree ~= tree or voice.instance ~= nil then
		return false, "the given-back tree was not the next one out, or its old voice reached it"
	end

	return true, nil
end
