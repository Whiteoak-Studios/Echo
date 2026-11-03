--[[
    play gives the voice it started, and stop with that voice and a fade
    moves only that voice's Volume linearly to 0 over the fade, on one
    Heartbeat connection, then gives it back, in either Mode
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
-- Two plays leave the free voices above the margin, so no growth step holds a Heartbeat connection of its own
local SIZE: { [string]: number } = { initial = 4, growAt = 4, growBy = 2, ceiling = 8 }
local VOLUME: number = 0.8
local FADE: number = 1
local HALF: number = FADE / 2
local FRAME: number = 1 / 60
local TOLERANCE: number = 1e-6

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local heartbeat: any = env.game:GetService("RunService").Heartbeat

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local ref: any = Element.ref(nil)
		Root.mount(nil, Element.create("Sound", { SoundId = ID, Volume = VOLUME, Handle = ref }))

		local handle: any = ref.current
		local fading: any = handle:play()
		local kept: any = handle:play()

		if not fading or not fading.instance or handle:get() ~= kept then
			return false, `a {mode} play did not give the voice it started`
		end

		local connections: number = env.connections(heartbeat)
		handle:stop(fading, FADE)

		if env.connections(heartbeat) ~= connections + 1 then
			return false, `a {mode} fade did not hold one Heartbeat connection`
		end

		env.step(HALF)

		local halfway: number = VOLUME * (1 - HALF / FADE)
		if math.abs(fading.instance.Volume - halfway) > TOLERANCE then
			return false, `a {mode} fade stood at {fading.instance.Volume} halfway, not {halfway}`
		elseif kept.instance.Volume ~= VOLUME then
			return false, `fading one {mode} voice moved another's Volume to {kept.instance.Volume}`
		elseif #handle:getAll() ~= 2 then
			return false, `a fading {mode} voice left the live list before its fade ended`
		end

		env.step(HALF + FRAME)

		if fading.instance ~= nil or #handle:getAll() ~= 1 or handle:getAll()[1] ~= kept then
			return false, `a {mode} voice was not given back at the end of its fade`
		elseif env.connections(heartbeat) ~= connections then
			return false, `a {mode} fade's Heartbeat connection outlived it`
		elseif kept.instance == nil or not kept.instance.IsPlaying then
			return false, `fading one {mode} voice stopped another`
		end
	end

	return true, nil
end
