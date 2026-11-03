--[[
    A set of a bound Looped reaches each live voice's instance and the
    cache's record of it, so at the ceiling a voice that came to loop is
    never taken by a one-shot, in either Mode
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 1, growAt = 1, growBy = 1, ceiling = 1 }

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local State: any = env.require("State")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local looped: any, setLooped: (value: any) -> () = State.new(false)
		local bed: any = Element.ref(nil)
		local shot: any = Element.ref(nil)

		Root.mount(nil, Element.create("Sound", { SoundId = ID, Looped = looped, Handle = bed }))
		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = shot }))

		local voice: any = bed.current:play()
		setLooped(true)

		local instanceLoops: boolean
		if voice.instance:IsA("Sound") then
			instanceLoops = voice.instance.Looped
		else
			instanceLoops = voice.instance.Looping
		end

		if not voice.looped or not instanceLoops then
			return false, `a {mode} set of Looped to true did not reach the live voice`
		elseif shot.current:play() ~= nil or voice.instance == nil then
			return false, `a one-shot at the {mode} ceiling took a voice that came to loop`
		end

		setLooped(false)
		if voice.looped then
			return false, `a {mode} set of Looped to false did not reach the cache's record`
		elseif shot.current:play() == nil or voice.instance ~= nil then
			return false, `a one-shot at the {mode} ceiling did not take a voice that stopped looping`
		end
	end

	return true, nil
end
