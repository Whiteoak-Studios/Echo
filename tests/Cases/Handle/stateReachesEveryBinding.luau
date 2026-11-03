--[[
    A state's value reaches every property bound to it, a second binding
    included, at every play, and a spring's does the same, in either Mode
    (limit 18)
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 8, growAt = 4, growBy = 2, ceiling = 16 }
local QUIET: number = 0.25
local SPRUNG: number = 0.4
local RETUNED: number = 0.6

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")
		local State: any = env.require("State")
		local Spring: any = env.require("Spring")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local volume: any, setVolume: (value: any) -> () = State.new(QUIET)
		local styles: any = Spring.new(function ()
			return { volume = SPRUNG }
		end)

		local refs: { any } = {}
		local elements: { any } = {}

		for _, bound: any in { volume, volume, styles.volume, styles.volume } do
			local ref: any = Element.ref(nil)
			table.insert(refs, ref)
			table.insert(elements, Element.create("Sound", { SoundId = ID, Volume = bound, Handle = ref }))
		end

		Root.mount(nil, Element.create(Keys.Fragment, elements))

		local expected: { number } = { QUIET, QUIET, SPRUNG, SPRUNG }
		for index: number, ref: any in refs do
			local voice: any = ref.current:play()
			if voice.instance.Volume ~= expected[index] then
				return false, `{mode} binding {index} played at {voice.instance.Volume}, not {expected[index]}`
			end

			ref.current:stop()
		end

		setVolume(RETUNED)
		for index: number = 1, 2 do
			local voice: any = refs[index].current:play()
			if voice.instance.Volume ~= RETUNED then
				return false, `{mode} binding {index} played at {voice.instance.Volume} after a set to {RETUNED}`
			end
		end
	end

	return true, nil
end
