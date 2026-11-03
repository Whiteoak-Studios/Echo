--[[
    A Volume bound to a spring follows it on the live voice, and a fade cut
    short by the opposite start ends at the second start's target and stays
    there, in either Mode
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local LOUD: number = 1
local LOW: number = 0.2
local LONG: number = 2
local SHORT: number = 0.5
local FRAME: number = 1 / 60

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Spring: any = env.require("Spring")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local styles: any, api: any = Spring.new(function ()
			return { volume = 0 }
		end)

		local ref: any = Element.ref(nil)
		Root.mount(nil, Element.create("Sound", { SoundId = ID, Volume = styles.volume, Looped = true, Handle = ref }))

		local voice: any = ref.current:play()

		api:start({ volume = LOUD, config = { duration = LONG } })
		env.step(SHORT)

		local risen: number = voice.instance.Volume
		if risen <= 0 or risen >= LOUD then
			return false, `a {mode} spring's fade up stood at {risen} on the live voice partway through`
		end

		api:start({ volume = LOW, config = { duration = SHORT } })
		env.step(SHORT + FRAME)

		if voice.instance.Volume ~= LOW then
			return false, `a {mode} fade cut short by the opposite start ended at {voice.instance.Volume}, not {LOW}`
		end

		env.step(LONG)
		if voice.instance.Volume ~= LOW then
			return false, `the first {mode} fade kept writing, moving the voice to {voice.instance.Volume}`
		end
	end

	return true, nil
end
