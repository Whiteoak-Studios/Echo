--[[
    Every following voice shares one Heartbeat connection, released once
    none follows, whether by nil, a give or a target leaving, and a target
    no voice can follow never holds one
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 8, growAt = 1, growBy = 1, ceiling = 16 }
local FRAME: number = 1 / 60

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local backend: FakeBackend.FakeBackend = FakeBackend.new(env)
	local new: (className: string) -> any = env.Instance.new
	local workspace: any = env.game.Workspace
	local heartbeat: any = env.game:GetService("RunService").Heartbeat
	local Vector3: any = roblox.Vector3

	Cache.create(MODE, SIZE, backend)

	local function take(): any
		return Cache.take(MODE, { looped = false, release = function () end })
	end

	local function partAt(position: any, parent: any): any
		local part: any = new("Part")
		part.Position = position
		part.Parent = parent

		return part
	end

	local first: any = take()
	local second: any = take()
	local firstPart: any = partAt(Vector3.new(1, 0, 0), workspace)
	local secondPart: any = partAt(Vector3.new(2, 0, 0), workspace)

	Cache.follow(first, firstPart)
	Cache.follow(second, secondPart)
	if env.connections(heartbeat) ~= 1 then
		return false, `two following voices hold {env.connections(heartbeat)} Heartbeat connections`
	end

	Cache.follow(first, nil)
	firstPart.Position = Vector3.new(5, 0, 0)
	env.step(FRAME)
	if first.tree.WorldPosition ~= Vector3.new(1, 0, 0) or env.connections(heartbeat) ~= 1 then
		return false, "a voice told to follow nil kept following, or dropped the other voice's connection"
	end

	Cache.give(second)
	if env.connections(heartbeat) ~= 0 then
		return false, "giving back the last following voice kept the Heartbeat connection"
	end

	local third: any = take()
	local thirdPart: any = partAt(Vector3.new(3, 0, 0), workspace)
	Cache.follow(third, thirdPart)
	thirdPart:Destroy()
	env.step(FRAME)
	if env.connections(heartbeat) ~= 0 then
		return false, "a voice whose target left the DataModel kept the Heartbeat connection"
	end

	-- None of these is a target a voice follows
	local fourth: any = take()
	local given: any = take()
	Cache.give(given)

	local start: number = #backend.calls
	Cache.follow(fourth, new("Folder"))
	Cache.follow(fourth, partAt(Vector3.new(4, 0, 0), nil))
	Cache.follow(given, partAt(Vector3.new(6, 0, 0), workspace))
	env.step(FRAME)

	if #backend.calls ~= start or env.connections(heartbeat) ~= 0 then
		return false, "a folder, a part outside the DataModel or a given-back voice was followed"
	end

	return true, nil
end
