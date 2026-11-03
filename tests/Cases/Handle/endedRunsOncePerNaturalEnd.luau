--[[
    Echo.Event.Ended runs once per natural end, with the voice already back
    in the pool and its instance nil, and never for a stop or a fade, in
    either Mode
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local FADE: number = 0.5
local FRAME: number = 1 / 60

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")
		local Cache: any = env.require("Cache")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local ended: { any } = {}
		local inUse: number? = nil
		local ref: any = Element.ref(nil)

		Root.mount(
			nil,
			Element.create("Sound", {
				SoundId = ID,
				Handle = ref,

				[Keys.Event.Ended] = function (voice: any)
					table.insert(ended, voice)
					inUse = Cache.count(mode).inUse

					if voice.instance ~= nil then
						error("Ended ran with the voice's instance still set")
					end
				end,
			})
		)

		local handle: any = ref.current
		local natural: any = handle:play()

		env.finish(natural.instance)

		if #ended ~= 1 or ended[1] ~= natural then
			return false, `a natural {mode} end ran Ended {#ended} times, not once with its voice`
		elseif inUse ~= 0 then
			return false, `a {mode} voice was not back in the pool when Ended ran`
		end

		handle:stop(handle:play())
		handle:stop(handle:play(), FADE)
		env.step(FADE + FRAME)

		if #ended ~= 1 then
			return false, `a {mode} stop or fade ran Ended`
		end

		local again: any = handle:play()
		env.finish(again.instance)

		if #ended ~= 2 or ended[2] ~= again then
			return false, `a second natural {mode} end did not run Ended once more`
		end
	end

	return true, nil
end
