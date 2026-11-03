--[[
    Destroying a root after any sequence of sets, refused ones among them,
    never throws, in either Mode; it gives every live voice back at once,
    later sets write nothing, and a second destroy does nothing (limit 19)
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local QUIET: number = 0.25
local LOUD: number = 0.75
local WRONG: string = "loud"

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")
		local State: any = env.require("State")
		local Cache: any = env.require("Cache")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local ref: any = Element.ref(nil)
		local volume: any, setVolume: (value: any) -> () = State.new(QUIET)
		local looped: any, setLooped: (value: any) -> () = State.new(false)
		local playing: any, setPlaying: (value: any) -> () = State.new(true)
		local paused: any, setPaused: (value: any) -> () = State.new(false)

		local root: any = Root.mount(
			nil,
			Element.create("Sound", {
				SoundId = ID,
				Volume = volume,
				Looped = looped,
				Handle = ref,
				[Keys.Action.Play] = playing,
				[Keys.Action.Pause] = paused,
			})
		)

		local handle: any = ref.current
		local voices: { any } = { handle:get(), handle:play() }

		setVolume(LOUD)
		setVolume(nil)
		setVolume(WRONG)
		setLooped(WRONG)
		setLooped(true)
		setPaused(true)
		setPlaying(WRONG)
		setPlaying(true)
		setVolume(QUIET)

		local destroyed: boolean, message: any = pcall(root.destroy, root)
		if not destroyed or #env.errors ~= 0 then
			return false, `destroying a {mode} root after its sets threw: {message or env.errors[1]}`
		end

		for _, voice: any in voices do
			if voice.instance ~= nil then
				return false, `destroying a {mode} root left a voice with its instance`
			end
		end

		if Cache.count(mode).inUse ~= 0 then
			return false, `destroying a {mode} root left {Cache.count(mode).inUse} voices in use`
		end

		local warnings: number = #env.warnings
		setVolume(WRONG)
		setPlaying(false)
		setPlaying(true)

		local again: boolean, againMessage: any = pcall(root.destroy, root)
		if not again or #env.errors ~= 0 then
			return false, `a second destroy of a {mode} root threw: {againMessage or env.errors[1]}`
		elseif #env.warnings ~= warnings or Cache.count(mode).inUse ~= 0 then
			return false, `a set after destroying a {mode} root still wrote or played`
		end
	end

	return true, nil
end
