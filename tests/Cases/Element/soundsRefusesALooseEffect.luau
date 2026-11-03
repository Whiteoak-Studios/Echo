--[[
    Element.sounds refuses an effect element outside a sound, at the top of
    a tree or inside a fragment, naming its class, and refuses a value that
    is no element at all
--]]

--!strict
local Environment = require("../../Environment")

local EFFECT: string = "DistortionSoundEffect"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local effect: any = Element.create(EFFECT)
	local trees: { [string]: any } = {
		top = effect,
		fragment = Element.create(Keys.Fragment, { Element.create("Sound"), effect }),
	}

	for where: string, tree: any in trees do
		local read: boolean, message: any = pcall(Element.sounds, tree)
		if read then
			return false, `an effect at the {where} of a tree was taken`
		elseif not tostring(message):find(EFFECT, 1, true) then
			return false, `an effect at the {where} of a tree was refused without naming its class: {message}`
		end
	end

	-- A list holding an element is no element either
	local read: boolean, message: any = pcall(Element.sounds, { Element.create("Sound") })
	if read or not tostring(message):find("takes an element", 1, true) then
		return false, `a list was taken as an element, or refused without saying so: {message}`
	end

	return true, nil
end
