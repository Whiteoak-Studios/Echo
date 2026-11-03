--[[
    Attributes takes a table, which the sound keeps as a copy of its own,
    and refuses any other value, a state and a ref included
--]]

--!strict
local Environment = require("../../Environment")

local STUDIO: string = "Whiteoak"
local OTHER: string = "Other"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local given: { [string]: any } = { Studio = STUDIO }
	local sound: any = Element.create("Sound", { Attributes = given })

	if sound.attributes == given or sound.attributes.Studio ~= STUDIO then
		return false, "a sound did not keep its attributes as a copy of the table it was given"
	end

	given.Studio = OTHER
	if sound.attributes.Studio ~= STUDIO then
		return false, "a sound's attributes changed with the table it was given"
	end

	if sound.properties.Attributes ~= nil or #sound.refs ~= 0 then
		return false, "the Attributes table reached the sound's properties or refs"
	end

	local refused: { [string]: any } = {
		string = STUDIO,
		state = { [Keys.State] = true, current = given },
		ref = Element.ref(given),
	}

	for what: string, value: any in refused do
		local made: boolean, message: any = pcall(Element.create, "Sound", { Attributes = value })
		if made then
			return false, `Attributes took a {what}`
		elseif not tostring(message):find("Attributes", 1, true) then
			return false, `Attributes refused a {what} without naming itself: {message}`
		end
	end

	return true, nil
end
