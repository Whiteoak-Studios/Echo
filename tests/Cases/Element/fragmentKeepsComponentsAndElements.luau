--[[
    A fragment's list keeps each element as it is and holds what each
    component returns, the component called with an empty props table
--]]

--!strict
local Environment = require("../../Environment")

local FIRST: string = "rbxassetid://1"
local SECOND: string = "rbxassetid://2"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local sound: any = Element.create("Sound", { SoundId = FIRST })
	local nested: any = Element.create(Keys.Fragment, { sound })
	local given: any = nil

	local function Gun(props: any): any
		given = props

		return Element.create("Sound", { SoundId = SECOND })
	end

	local fragment: any = Element.create(Keys.Fragment, { sound, Gun, nested })
	local children: { any } = fragment.children

	if fragment.kind ~= "Fragment" or #children ~= 3 then
		return false, `a fragment of three entries holds {#children} children`
	end

	if children[1] ~= sound or children[3] ~= nested then
		return false, "a fragment did not keep its elements as they are, in order"
	end

	if children[2].kind ~= "Sound" or children[2].properties.SoundId ~= SECOND then
		return false, "a fragment did not hold the element its component returned"
	end

	if type(given) ~= "table" or next(given) ~= nil then
		return false, `a fragment's component was called with {given}, not an empty table`
	end

	return true, nil
end
