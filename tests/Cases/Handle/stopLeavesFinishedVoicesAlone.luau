--[[
    stop with a voice that ended, was taken by its cap, was stopped, or is
    another handle's does nothing and raises nothing, the finished ones'
    instance being nil; stop with no voice stops every live one; and a fade
    that is not seconds of 0 or more errors
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local FADE: number = 1
local LIMIT: number = 1

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")
		local Cache: any = env.require("Cache")
		local heartbeat: any = env.game:GetService("RunService").Heartbeat

		Root.configure({ mode = mode, cache = { [mode] = SIZE }, caps = { Solo = LIMIT } })

		local ref: any = Element.ref(nil)
		local capped: any = Element.ref(nil)

		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = ref }))
		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = capped, [Keys.Util.Cap] = "Solo" }))

		local handle: any = ref.current
		local ended: any = handle:play()

		env.finish(ended.instance)

		local taken: any = capped.current:play()
		local taker: any = capped.current:play()

		local stopped: any = handle:play()
		handle:stop(stopped)

		local connections: number = env.connections(heartbeat)
		local playing: any = handle:play()

		for _, voice: any in { ended, taken, stopped } do
			if voice.instance ~= nil then
				return false, `a finished {mode} voice kept its instance`
			end

			local quiet: boolean, message: any = pcall(function ()
				handle:stop(voice)
				handle:stop(voice, FADE)
				capped.current:stop(voice, FADE)
			end)

			if not quiet then
				return false, `stop on a finished {mode} voice raised: {message}`
			end
		end

		handle:stop(taker, FADE)
		handle:stop({}, FADE)

		if taker.instance == nil or playing.instance == nil or env.connections(heartbeat) ~= connections then
			return false, `stop with another handle's voice, or no voice of Echo's, acted on a {mode} voice`
		end

		for _, fade: any in { -1, "1", math.huge, 0 / 0 } do
			if pcall(handle.stop, handle, nil, fade) then
				return false, `a {mode} stop took {fade} as its fade`
			end
		end

		local another: any = handle:play()
		handle:stop()

		if playing.instance ~= nil or another.instance ~= nil or #handle:getAll() ~= 0 then
			return false, `stop with no voice left a {mode} voice live`
		elseif Cache.count(mode).inUse ~= 1 then
			return false, `stop with no voice stopped another handle's {mode} voice`
		end
	end

	return true, nil
end
