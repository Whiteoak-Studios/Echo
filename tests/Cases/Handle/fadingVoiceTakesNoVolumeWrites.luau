--[[
    A fading voice takes no Volume write from its binding while every other
    live voice does, and still takes the element's other bound properties
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local VOLUME: number = 0.8
local RETUNED: number = 0.3
local NORMAL: number = 1 -- A Sound's own PlaybackSpeed
local SPEED: number = 1.5
local FADE: number = 1
local QUARTER: number = FADE / 4
local TOLERANCE: number = 1e-6

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local State: any = env.require("State")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local volume: any, setVolume: (value: any) -> () = State.new(VOLUME)
		local speed: any, setSpeed: (value: any) -> () = State.new(NORMAL)
		local ref: any = Element.ref(nil)

		Root.mount(nil, Element.create("Sound", { SoundId = ID, Volume = volume, PlaybackSpeed = speed, Handle = ref }))
		local handle: any = ref.current

		local fading: any = handle:play()
		local kept: any = handle:play()

		handle:stop(fading, FADE)
		env.step(QUARTER)

		local before: number = fading.instance.Volume

		setVolume(RETUNED)
		setSpeed(SPEED)

		if fading.instance.Volume ~= before then
			return false, `a set of a bound Volume reached a fading {mode} voice`
		elseif kept.instance.Volume ~= RETUNED then
			return false, `a set of a bound Volume missed a {mode} voice that is not fading`
		elseif fading.instance.PlaybackSpeed ~= SPEED or kept.instance.PlaybackSpeed ~= SPEED then
			return false, `a set of a bound PlaybackSpeed missed a {mode} voice`
		end

		env.step(QUARTER)

		local expected: number = VOLUME * (1 - QUARTER * 2 / FADE)
		if math.abs(fading.instance.Volume - expected) > TOLERANCE then
			return false, `a {mode} fade stood at {fading.instance.Volume} after the set, not {expected}`
		end
	end

	return true, nil
end
