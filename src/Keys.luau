--[[
    The unique tokens a game uses as prop keys, each named for messages and
    typed by its own name, and the markers that tell a state and a ref apart
--]]

--!strict
local Keys = {
	Fragment = { name = "Echo.Fragment" } :: { read name: "Echo.Fragment" },

	Event = {
		Ended = { name = "Echo.Event.Ended" } :: { read name: "Echo.Event.Ended" },
		Playing = { name = "Echo.Event.Playing" } :: { read name: "Echo.Event.Playing" },
		Looped = { name = "Echo.Event.Looped" } :: { read name: "Echo.Event.Looped" },
		Loaded = { name = "Echo.Event.Loaded" } :: { read name: "Echo.Event.Loaded" },
	},

	Action = {
		Play = { name = "Echo.Action.Play" } :: { read name: "Echo.Action.Play" },
		Pause = { name = "Echo.Action.Pause" } :: { read name: "Echo.Action.Pause" },
	},

	Util = {
		Cap = { name = "Echo.Util.Cap" } :: { read name: "Echo.Util.Cap" },
		Bus = { name = "Echo.Util.Bus" } :: { read name: "Echo.Util.Bus" },
	},

	State = {} :: { nil }, -- Set on every state and spring value by State.new
	Ref = {} :: { nil }, -- Set on every ref by Element.ref
}

return Keys
