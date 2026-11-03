--[[
    A root destroyed while its voices play, one of them fading, gives every
    one back at once, ends the fade's connection, runs no Ended, and its old
    instances fire nothing after, in either Mode
--]]

--!strict
local Environment = require("../../Environment")
local Signal = require("../../Fakes/Signal")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local FADE: number = 1
local PART: number = 0.25

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")
		local Cache: any = env.require("Cache")
		local heartbeat: any = env.game:GetService("RunService").Heartbeat

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local events: number = 0
		local function count()
			events += 1
		end

		local ref: any = Element.ref(nil)
		local root: any = Root.mount(
			nil,
			Element.create("Sound", {
				SoundId = ID,
				Handle = ref,
				[Keys.Event.Ended] = count,
				[Keys.Event.Looped] = count,
				[Keys.Event.Loaded] = count,
			})
		)

		local connections: number = env.connections(heartbeat)
		local handle: any = ref.current
		local playing: any = handle:play()
		local fading: any = handle:play()
		local instances: { any } = { playing.instance, fading.instance }

		handle:stop(fading, FADE)
		env.step(PART)
		root:destroy()

		if playing.instance ~= nil or fading.instance ~= nil or Cache.count(mode).inUse ~= 0 then
			return false, `destroying a {mode} root mid-play left a voice out of the pool`
		elseif env.connections(heartbeat) ~= connections then
			return false, `destroying a {mode} root mid-fade left the fade connected`
		end

		for _, instance: any in instances do
			Signal.fire(instance.Ended)
			env.load(instance)
		end

		env.step(FADE)
		if events ~= 0 then
			return false, `a destroyed {mode} root's voices ran {events} callbacks`
		end
	end

	return true, nil
end
