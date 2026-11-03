--[[
    A burst of fifty takes in one cap group never holds more voices than the
    group's limit, gives one back for each take past it, and makes no
    instance on any take
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 16, growAt = 16, growBy = 4, ceiling = 32 }
local GROUP: string = "Gun/AKM/FirstPerson"
local LIMIT: number = 12
local BURST: number = 50

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local backend: FakeBackend.FakeBackend = FakeBackend.new(env)
	local terrain: any = env.game.Workspace.Terrain

	Cache.create(MODE, SIZE, backend)

	local released: number = 0
	local function release()
		released += 1
	end

	for take: number = 1, BURST do
		local voice: any = Cache.take(MODE, { looped = false, group = GROUP, limit = LIMIT, release = release })
		if not voice or not voice.instance then
			return false, `take {take} of the burst gave no playing voice`
		end

		local inUse: number = Cache.count(MODE).inUse
		if inUse > LIMIT then
			return false, `take {take} left {inUse} voices playing, past the group's limit of {LIMIT}`
		end
	end

	if released ~= BURST - LIMIT or Cache.count(MODE).inUse ~= LIMIT then
		return false, `the burst gave back {released} voices and holds {Cache.count(MODE).inUse}`
	end

	local templates: number = 0
	for _, call: FakeBackend.Call in backend.calls do
		if call.name == "template" then
			templates += 1
		end
	end

	if templates ~= 1 or #terrain:GetChildren() ~= SIZE.initial then
		return false, `the burst built {templates} templates and left {#terrain:GetChildren()} voices under Terrain`
	end

	return true, nil
end
