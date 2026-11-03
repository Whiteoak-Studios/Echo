--[[
    Playing runs with the voice each time one starts, Looped with the voice
    and its loop count, and Loaded with the voice, in either Mode. A callback
    that returns a function has it run at once, and that event's handler is
    dropped for every later voice
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local playing: { any } = {}
		local looped: { { any } } = {}
		local loaded: { any } = {}
		local cleanups: number = 0
		local ref: any = Element.ref(nil)

		Root.mount(
			nil,
			Element.create("Sound", {
				SoundId = ID,
				Looped = true,
				Handle = ref,

				[Keys.Event.Playing] = function (voice: any)
					table.insert(playing, voice)
				end,

				[Keys.Event.Looped] = function (voice: any, count: number)
					table.insert(looped, { voice, count })
				end,

				[Keys.Event.Loaded] = function (voice: any): () -> ()
					table.insert(loaded, voice)

					return function ()
						cleanups += 1
					end
				end,
			})
		)

		local handle: any = ref.current
		local first: any = handle:play()
		if #playing ~= 1 or playing[1] ~= first then
			return false, `a {mode} play did not run Playing once with its voice`
		end

		env.loop(first.instance)
		env.loop(first.instance)

		if #looped ~= 2 or looped[1][1] ~= first or looped[1][2] ~= 1 or looped[2][2] ~= 2 then
			return false, `two {mode} loops did not run Looped with the voice and counts 1 and 2`
		end

		env.load(first.instance)

		if #loaded ~= 1 or loaded[1] ~= first or cleanups ~= 1 then
			return false, `a {mode} load did not run Loaded with the voice and its cleanup once`
		end

		local second: any = handle:play()
		env.load(second.instance)

		if #loaded ~= 1 or cleanups ~= 1 then
			return false, `a {mode} Loaded handler that returned a cleanup ran for a later voice`
		elseif #playing ~= 2 or playing[2] ~= second then
			return false, `a second {mode} play did not run Playing with its voice`
		end
	end

	return true, nil
end
