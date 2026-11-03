--[[
    A fragment's guard refuses every entry that is neither a component nor
    an element, naming the entry's index and what it was
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local sound: any = Element.create("Sound")
	local state: any = { [Keys.State] = true, current = true }

	-- Each refused entry sits after a valid one, so the index named is its own
	local refused: { [string]: any } = {
		number = 5,
		string = "Sound",
		boolean = true,
		table = {},
		state = state,
		ref = Element.ref(nil),
		token = Keys.Event.Ended,
	}

	for what: string, entry: any in refused do
		local made: boolean, message: any = pcall(Element.create, Keys.Fragment, { sound, entry })
		if made then
			return false, `a fragment took a {what} as an entry`
		elseif not tostring(message):find("entry 2", 1, true) then
			return false, `a fragment refused a {what} without naming its index: {message}`
		end
	end

	local _, named: any = pcall(Element.create, Keys.Fragment, { sound, Keys.Event.Ended })
	if not tostring(named):find(Keys.Event.Ended.name, 1, true) then
		return false, `a fragment refused a token without naming it: {named}`
	end

	return true, nil
end
