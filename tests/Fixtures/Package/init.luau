--[[
    The smallest package the harness cases load: it hands back what its
    requires found at each depth and the globals the fake game gives it
--]]

--!strict
local Cellar = require(script.Parent.Cellar)
local Promise: any = require(script.Parent.Promise)

local Direct = require(script.Direct)
local Nested = require(script.Backends.Nested)

return {
	Cellar = Cellar,
	Promise = Promise,
	Direct = Direct,
	Nested = Nested,

	game = game,
	workspace = workspace,
	Instance = Instance,
	task = task,
	clock = os.clock,
	tick = tick,
	typeof = typeof,
	type = type,
	warn = warn,
	Vector3 = Vector3,
	Enum = Enum,
}
