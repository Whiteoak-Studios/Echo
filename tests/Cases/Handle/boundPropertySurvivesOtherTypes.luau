--[[
    A set of another type, nil included, warns and skips that write while the
    binding stays, so a later set still reaches the voice, and each set is
    one write with no attribute beside it, in either Mode (limit 4)
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
		local State: any = env.require("State")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local volume: any, setVolume: (value: any) -> () = State.new(QUIET)
		local ref: any = Element.ref(nil)

		Root.mount(nil, Element.create("Sound", { SoundId = ID, Volume = volume, Handle = ref }))

		local voice: any = ref.current:play()
		local instance: any = voice.instance
		local writes: number = 0

		instance:GetPropertyChangedSignal("Volume"):Connect(function ()
			writes += 1
		end)

		setVolume(nil)
		setVolume(WRONG)

		if instance.Volume ~= QUIET then
			return false, `a {mode} set of another type wrote the Volume as {instance.Volume}`
		elseif #env.warnings ~= 2 then
			return false, `two {mode} sets of another type gave {#env.warnings} warnings, not one each`
		end

		setVolume(LOUD)

		if instance.Volume ~= LOUD then
			return false, `a {mode} set of another type ended the binding, so {LOUD} never arrived`
		elseif writes ~= 1 then
			return false, `one {mode} set wrote the Volume {writes} times`
		elseif instance:GetAttribute("Volume") ~= nil then
			return false, `a {mode} set wrote the Volume again as an attribute`
		end
	end

	return true, nil
end
