--[[
    Every kind of element takes a missing props as an empty table: a sound,
    an effect, a fragment, and a component, which is called with one
--]]

--!strict
local Environment = require("../../Environment")

local EFFECT: string = "ReverbSoundEffect"
local PROPS: number = 5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local made: boolean, sound: any = pcall(Element.create, "Sound")
	if not made then
		return false, `a Sound with no props errored: {sound}`
	end

	for _, field: string in { "properties", "events", "actions", "refs", "attributes", "effects" } do
		if type(sound[field]) ~= "table" or next(sound[field]) ~= nil then
			return false, `a Sound with no props has a {field} that is not an empty table`
		end
	end

	if sound.kind ~= "Sound" or sound.cap ~= nil or sound.bus ~= nil then
		return false, "a Sound with no props is no plain Sound element"
	end

	local effect: any = Element.create(EFFECT)
	if effect.kind ~= "Effect" or effect.className ~= EFFECT or next(effect.properties) ~= nil then
		return false, "an effect with no props is no plain effect element"
	end

	local fragment: any = Element.create(Keys.Fragment)
	if fragment.kind ~= "Fragment" or #fragment.children ~= 0 then
		return false, "a fragment with no props is no empty fragment"
	end

	local given: any = nil
	Element.create(function (props: any): any
		given = props

		return Element.create("Sound")
	end)

	if type(given) ~= "table" or next(given) ~= nil then
		return false, `a component made with no props was called with {given}, not an empty table`
	end

	local refused: boolean, message: any = pcall(Element.create, "Sound", PROPS)
	if refused or not tostring(message):find(`{PROPS}`, 1, true) then
		return false, `props that are no table were taken, or the refusal did not name them: {message}`
	end

	return true, nil
end
