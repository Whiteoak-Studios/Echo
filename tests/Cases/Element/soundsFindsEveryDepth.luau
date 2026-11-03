--[[
    Element.sounds gives every sound element of a tree in order, from a
    bare sound, a component's element and fragments nested at any depth,
    and none of a sound's effects
--]]

--!strict
local Environment = require("../../Environment")

local EFFECT: string = "EchoSoundEffect"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local bare: any = Element.create("Sound", {}, { Echo = Element.create(EFFECT) })
	local found: { any } = Element.sounds(bare)
	if #found ~= 1 or found[1] ~= bare then
		return false, `a bare sound gave {#found} sounds, not itself`
	end

	local first: any = Element.create("Sound")
	local second: any = Element.create("Sound")
	local third: any = Element.create("Sound")

	local function Inner(): any
		return second
	end

	local function Outer(): any
		return Element.create(Inner)
	end

	local deep: any = Element.create(Keys.Fragment, { Element.create(Keys.Fragment, { third }) })
	local tree: any = Element.create(Keys.Fragment, { first, Element.create(Keys.Fragment, { Outer, deep }) })

	found = Element.sounds(tree)
	if #found ~= 3 or found[1] ~= first or found[2] ~= second or found[3] ~= third then
		return false, `a nested tree gave {#found} sounds, not its three in order`
	end

	if #Element.sounds(Element.create(Keys.Fragment)) ~= 0 then
		return false, "an empty fragment gave a sound"
	end

	return true, nil
end
