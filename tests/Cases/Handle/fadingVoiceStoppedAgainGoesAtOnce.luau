--[[
    A voice stopped again while it fades goes back at once, with or without
    a second fade, and its fade's Heartbeat connection ends with it
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local FADE: number = 2
local LONGER: number = 5
local PART: number = 0.5

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Cache: any = env.require("Cache")
		local heartbeat: any = env.game:GetService("RunService").Heartbeat

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local ref: any = Element.ref(nil)
		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = ref }))

		local handle: any = ref.current
		local connections: number = env.connections(heartbeat)

		local first: any = handle:play()
		local second: any = handle:play()

		handle:stop(first, FADE)
		handle:stop(second, FADE)

		env.step(PART)

		handle:stop(first)
		handle:stop(second, LONGER)

		if first.instance ~= nil or second.instance ~= nil then
			return false, `a fading {mode} voice stopped again was not given back at once`
		elseif Cache.count(mode).inUse ~= 0 or env.connections(heartbeat) ~= connections then
			return false, `stopping fading {mode} voices again left a voice in use or a fade connected`
		end
	end

	return true, nil
end
