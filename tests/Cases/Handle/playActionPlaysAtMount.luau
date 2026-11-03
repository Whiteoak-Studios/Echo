--[[
    An Echo.Action.Play state holding true at mount plays a voice then, and
    the action acts only when its value changes: a second true starts no
    second voice, false stops every live one, and false then true starts
    one, in either Mode (limit 5)
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")
		local State: any = env.require("State")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local playing: any, setPlaying: (value: any) -> () = State.new(true)
		local idle: any = State.new(false)
		local ref: any = Element.ref(nil)
		local still: any = Element.ref(nil)

		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = ref, [Keys.Action.Play] = playing }))
		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = still, [Keys.Action.Play] = idle }))

		local handle: any = ref.current
		local mounted: any = handle:get()

		if #handle:getAll() ~= 1 or not mounted.instance.IsPlaying then
			return false, `a {mode} Play action holding true at mount did not play one voice`
		elseif #still.current:getAll() ~= 0 then
			return false, `a {mode} Play action holding false at mount played`
		end

		setPlaying(true)

		if #handle:getAll() ~= 1 then
			return false, `a {mode} Play action set to the true it held started another voice`
		end

		setPlaying(false)
		setPlaying(false)

		if #handle:getAll() ~= 0 or mounted.instance ~= nil then
			return false, `a {mode} Play action set to false left a voice live`
		end

		setPlaying(true)

		if #handle:getAll() ~= 1 or handle:get() == mounted then
			return false, `a {mode} Play action set false then true did not start one new voice`
		end
	end

	return true, nil
end
