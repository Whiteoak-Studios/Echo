--[[
    An event callback that throws leaves its voice whole: a throwing Playing
    still lets the play finish and return its playing voice, and a throwing
    Ended still finds its voice given back. The error surfaces as a thread's
    error, never out of the play
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local START: number = 2

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")
		local Cache: any = env.require("Cache")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local ref: any = Element.ref(nil)
		Root.mount(
			nil,
			Element.create("Sound", {
				SoundId = ID,
				TimePosition = START,
				Handle = ref,

				[Keys.Event.Playing] = function ()
					error("Playing threw")
				end,

				[Keys.Event.Ended] = function ()
					error("Ended threw")
				end,
			})
		)

		local handle: any = ref.current
		local played: boolean, voice: any = pcall(handle.play, handle)

		if not played then
			return false, `a throwing {mode} Playing callback threw out of play: {voice}`
		elseif not voice or not voice.instance or not voice.instance.IsPlaying then
			return false, `a throwing {mode} Playing callback left the play without a playing voice`
		elseif voice.instance.TimePosition ~= START then
			return false, `a throwing {mode} Playing callback cut the play short of its TimePosition`
		elseif #env.errors ~= 1 or string.find(env.errors[1], "Playing threw", 1, true) == nil then
			return false, `a throwing {mode} Playing callback's error did not surface once`
		end

		table.clear(env.errors)
		env.finish(voice.instance)

		if voice.instance ~= nil or Cache.count(mode).inUse ~= 0 then
			return false, `a throwing {mode} Ended callback left its voice out of the pool`
		elseif #env.errors ~= 1 or string.find(env.errors[1], "Ended threw", 1, true) == nil then
			return false, `a throwing {mode} Ended callback's error did not surface once`
		end

		table.clear(env.errors)

		if not handle:play() then
			return false, `a {mode} handle whose callbacks threw played nothing after`
		end

		table.clear(env.errors)
	end

	return true, nil
end
