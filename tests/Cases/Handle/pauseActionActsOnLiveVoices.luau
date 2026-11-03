--[[
    An Echo.Action.Pause state pauses the voices live when it turns true and
    resumes them when it turns false, acting only on a change, so a voice
    started while it holds true plays, in either Mode
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

		local paused: any, setPaused: (value: any) -> () = State.new(false)
		local ref: any = Element.ref(nil)

		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = ref, [Keys.Action.Pause] = paused }))
		local handle: any = ref.current

		local early: any = handle:play()
		setPaused(true)

		if early.instance.IsPlaying then
			return false, `a {mode} Pause action turning true left a live voice playing`
		end

		local late: any = handle:play()
		setPaused(true)

		if not late.instance.IsPlaying then
			return false, `a {mode} voice started while Pause held true did not play`
		end

		setPaused(false)
		if not early.instance.IsPlaying or not late.instance.IsPlaying then
			return false, `a {mode} Pause action turning false did not resume the voice it paused`
		elseif #handle:getAll() ~= 2 then
			return false, `a {mode} Pause action gave a voice back`
		end
	end

	return true, nil
end
