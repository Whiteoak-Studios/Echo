--[[
    A bound property takes every one of many same-type sets on its live voice
    and keeps its binding, so the next play starts at the last set, in either
    Mode
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local SETS: number = 200
local NORMAL: number = 1 -- A Sound's own PlaybackSpeed, which each set climbs from
local STEP: number = 0.005

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local State: any = env.require("State")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local speed: any, setSpeed: (value: any) -> () = State.new(NORMAL)
		local ref: any = Element.ref(nil)

		Root.mount(nil, Element.create("Sound", { SoundId = ID, PlaybackSpeed = speed, Handle = ref }))

		local handle: any = ref.current
		local voice: any = handle:play()

		for set: number = 1, SETS do
			local value: number = NORMAL + set * STEP
			setSpeed(value)

			if voice.instance.PlaybackSpeed ~= value then
				return false, `{mode} set {set} of {value} reached the voice as {voice.instance.PlaybackSpeed}`
			end
		end

		handle:stop(voice)

		local replay: any = handle:play()
		local last: number = NORMAL + SETS * STEP

		if replay.instance.PlaybackSpeed ~= last or #env.warnings ~= 0 then
			return false,
				`after {SETS} {mode} sets the next play started at {replay.instance.PlaybackSpeed}, not {last}`
		end
	end

	return true, nil
end
