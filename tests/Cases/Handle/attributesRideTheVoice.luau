--[[
    An element's Attributes are set on each voice's instance while it plays
    the element and cleared once the voice goes back, in either Mode
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 1, growAt = 1, growBy = 1, ceiling = 1 }
local ARTIST: string = "Mike"
local TAKE: number = 3

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local ref: any = Element.ref(nil)
		local plain: any = Element.ref(nil)

		Root.mount(
			nil,
			Element.create("Sound", { SoundId = ID, Handle = ref, Attributes = { Artist = ARTIST, Take = TAKE } })
		)

		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = plain }))

		local voice: any = ref.current:play()
		local instance: any = voice.instance

		if instance:GetAttribute("Artist") ~= ARTIST or instance:GetAttribute("Take") ~= TAKE then
			return false, `a {mode} voice did not carry its element's attributes while it played`
		end

		ref.current:stop(voice)

		local reused: any = plain.current:play()
		if reused.instance ~= instance or next(instance:GetAttributes()) ~= nil then
			return false, `a {mode} voice kept its old element's attributes once it went back`
		end
	end

	return true, nil
end
