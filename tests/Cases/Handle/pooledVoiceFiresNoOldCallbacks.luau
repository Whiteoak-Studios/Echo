--[[
    A voice back in the pool fires none of its element's callbacks, whatever
    its instance does, and once another element takes that instance only the
    new element's callbacks run, in either Mode
--]]

--!strict
local Environment = require("../../Environment")
local Signal = require("../../Fakes/Signal")

local ID: string = "rbxassetid://1"
local OTHER: string = "rbxassetid://2"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 1, growAt = 1, growBy = 1, ceiling = 1 }

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local runs: { [string]: number } = {}
		local function element(name: string, id: string, ref: any): any
			local function count(event: string): () -> ()
				return function ()
					local key: string = `{name}.{event}`
					runs[key] = (runs[key] or 0) + 1
				end
			end

			return Element.create("Sound", {
				SoundId = id,
				Handle = ref,
				[Keys.Event.Ended] = count("Ended"),
				[Keys.Event.Looped] = count("Looped"),
				[Keys.Event.Loaded] = count("Loaded"),
				[Keys.Event.Playing] = count("Playing"),
			})
		end

		local old: any = Element.ref(nil)
		local new: any = Element.ref(nil)

		Root.mount(nil, element("Old", ID, old))
		Root.mount(nil, element("New", OTHER, new))

		local voice: any = old.current:play()
		local instance: any = voice.instance

		old.current:stop(voice)

		Signal.fire(instance.Ended)
		env.load(instance)
		env.step(0)

		local before: number = runs["Old.Playing"] or 0
		if runs["Old.Ended"] or runs["Old.Loaded"] or runs["Old.Looped"] or before ~= 1 then
			return false, `a {mode} voice back in the pool fired its element's callbacks`
		end

		local taken: any = new.current:play()
		if taken.instance ~= instance then
			return false, `the next {mode} play did not take the pool's one voice`
		end

		env.load(instance)
		env.finish(instance)

		if runs["Old.Playing"] ~= before or runs["Old.Ended"] or runs["Old.Loaded"] then
			return false, `the {mode} voice's old element ran a callback once another took the voice`
		elseif runs["New.Playing"] ~= 1 or runs["New.Loaded"] ~= 1 or runs["New.Ended"] ~= 1 then
			return false, `the {mode} voice's new element did not run its own callbacks once each`
		end
	end

	return true, nil
end
