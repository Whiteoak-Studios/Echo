--[[
    An element's Name is its own label in either Mode: getAll reports it, a
    bound one at each set, while every voice keeps the Name its pool gave it
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 1, growAt = 1, growBy = 1, ceiling = 1 }
local WIND: string = "Wind"
local BREEZE: string = "Breeze"
local GUST: string = "Gust"

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")
		local State: any = env.require("State")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })

		local name: any, setName: (value: any) -> () = State.new(WIND)
		local named: any = Element.ref(nil)
		local fixed: any = Element.ref(nil)
		local plain: any = Element.ref(nil)

		Root.mount(
			nil,
			Element.create(Keys.Fragment, {
				Element.create("Sound", { Name = name, SoundId = ID, Handle = named }),
				Element.create("Sound", { Name = GUST, SoundId = ID, Handle = fixed }),
				Element.create("Sound", { SoundId = ID, Handle = plain }),
			})
		)

		local function names(): (string?, string?)
			local mounted: { any } = Root.getAll()

			return mounted[1].name, mounted[2].name
		end

		local first: string?, second: string? = names()
		if first ~= WIND or second ~= GUST then
			return false, `getAll read the {mode} elements' Names as {first} and {second}`
		end

		-- The pool's one voice, under the Name the pool gave it
		local unnamed: any = plain.current:play()
		local instance: any = unnamed.instance
		local pooled: string = instance.Name
		plain.current:stop(unnamed)

		for _, handle: any in { named.current, fixed.current } do
			local voice: any = handle:play()
			if voice.instance ~= instance or instance.Name ~= pooled then
				return false, `a {mode} play gave its voice the element's Name {instance.Name}`
			end

			handle:stop(voice)
		end

		local live: any = named.current:play()
		setName(BREEZE)
		first = names()

		if first ~= BREEZE then
			return false, `a set of a bound {mode} Name reached getAll as {first}`
		elseif live.instance.Name ~= pooled or #env.warnings ~= 0 then
			return false, `a set of a bound {mode} Name reached the live voice or warned`
		end

		setName(nil)
		first = names()
		if first ~= nil or #env.warnings ~= 0 then
			return false, `a {mode} Name set to nil read {first} in getAll, or warned`
		end
	end

	return true, nil
end
