--[[
    A thirteenth take in a group of twelve that several elements share gives
    back the group's earliest-started voice and plays on it, leaving a voice
    outside the group and a group with no limit alone
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 32, growAt = 32, growBy = 8, ceiling = 64 }
local GROUP: string = "Gun/AKM/FirstPerson"
local UNCAPPED: string = "Ambience/Wind"
local LIMIT: number = 12
local ELEMENTS: number = 3

type Release = {
	element: number,
	voice: any,
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")

	Cache.create(MODE, SIZE, FakeBackend.new(env))

	local released: { Release } = {}

	-- Each element's handle sets its own release hook
	local function request(element: number, group: string?, limit: number?): { [string]: any }
		return {
			looped = false,
			group = group,
			limit = limit,
			release = function (voice: any)
				table.insert(released, { element = element, voice = voice })
			end,
		}
	end

	local outside: any = Cache.take(MODE, request(0, nil, nil))

	local grouped: { any } = {}
	for take: number = 1, LIMIT do
		table.insert(grouped, Cache.take(MODE, request(take % ELEMENTS + 1, GROUP, LIMIT)))
	end

	for take: number = 1, LIMIT + 1 do
		Cache.take(MODE, request(take % ELEMENTS + 1, UNCAPPED, nil))
	end

	if #released ~= 0 then
		return false, `takes inside the cap, or in a group with no limit, gave back {#released} voices`
	end

	local first: any = grouped[1]
	local tree: any = first.tree
	local thirteenth: any = Cache.take(MODE, request(2, GROUP, LIMIT))

	if #released ~= 1 or released[1].voice ~= first or released[1].element ~= 1 % ELEMENTS + 1 then
		return false, "the thirteenth take did not give back the group's earliest-started voice through its own element"
	end

	if first.instance ~= nil or not thirteenth or thirteenth.tree ~= tree or thirteenth.instance == nil then
		return false, "the thirteenth take did not play on the voice it freed"
	end

	if outside.instance == nil then
		return false, "the cap gave back a voice outside its group"
	end

	for index: number = 2, LIMIT do
		if grouped[index].instance == nil then
			return false, `the cap gave back the group's voice {index} as well`
		end
	end

	local inUse: number = Cache.count(MODE).inUse
	if inUse ~= 1 + LIMIT + LIMIT + 1 then
		return false, `{inUse} voices are in use after the cap`
	end

	return true, nil
end
