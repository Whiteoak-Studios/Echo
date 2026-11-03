--[[
    A stand-in Backend over one environment's fake instances, which plays
    nothing and records every call it takes, in order, for the cases that
    drive the cache
--]]

--!strict
local Environment = require("../Environment")

export type Call = {
	name: string,
	args: { any }, -- What the call was given, in order
}

-- Every function a Backend has, beside the calls they took
export type FakeBackend = {
	calls: { Call },
	[string]: any,
}

local FakeBackend = {}

--[[
    Builds the fake. Its template is an Attachment holding a Sound, so
    playable finds a voice's Sound, and place moves the tree; every other
    function only records, check and checkEffect refusing nothing
--]]

function FakeBackend.new(env: Environment.Environment): FakeBackend
	local calls: { Call } = {}

	local function record(name: string, ...: any)
		table.insert(calls, { name = name, args = { ... } })
	end

	return {
		calls = calls,

		setup = function ()
			record("setup")
		end,

		template = function (): any
			record("template")

			local tree: any = env.Instance.new("Attachment")
			local sound: any = env.Instance.new("Sound")
			sound.Parent = tree

			return tree
		end,

		playable = function (tree: any): any
			record("playable", tree)

			return tree:FindFirstChild("Sound")
		end,

		check = function (property: string, value: any): string?
			record("check", property, value)

			return nil
		end,

		checkEffect = function (className: string, property: string, value: any): string?
			record("checkEffect", className, property, value)

			return nil
		end,

		apply = function (tree: any, property: string, value: any): boolean
			record("apply", tree, property, value)

			return true
		end,

		effect = function (tree: any, className: string, key: string, properties: { [string]: any })
			record("effect", tree, className, key, properties)
		end,

		route = function (tree: any, bus: any, world: boolean)
			record("route", tree, bus, world)
		end,

		place = function (tree: any, position: any)
			record("place", tree, position)
			tree.WorldPosition = position
		end,

		play = function (tree: any)
			record("play", tree)
		end,

		stop = function (tree: any)
			record("stop", tree)
		end,

		pause = function (tree: any)
			record("pause", tree)
		end,

		resume = function (tree: any)
			record("resume", tree)
		end,

		-- The disconnect it gives records its own call, as "disconnect" with the tree
		connect = function (tree: any, events: any): () -> ()
			record("connect", tree, events)

			return function ()
				record("disconnect", tree)
			end
		end,

		clear = function (tree: any)
			record("clear", tree)
		end,
	}
end

return FakeBackend
