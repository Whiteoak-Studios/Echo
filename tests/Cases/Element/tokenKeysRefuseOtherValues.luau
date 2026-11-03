--[[
    An Event key takes only a function and an Action key only a state, and
    each refusal names the key it refused for
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local state: any = { [Keys.State] = true, current = true }

	-- A table holding current but no marker is no state
	local refused: { [any]: { [string]: any } } = {
		[Keys.Event] = { string = ID, state = state, ref = Element.ref(nil) },
		[Keys.Action] = { boolean = true, ["function"] = function () end, lookalike = { current = true } },
	}

	for group: any, values: { [string]: any } in refused do
		for _, key: any in group do
			for what: string, value: any in values do
				local made: boolean, message: any = pcall(Element.create, "Sound", { [key] = value })
				if made then
					return false, `{key.name} took a {what}`
				elseif not tostring(message):find(key.name, 1, true) then
					return false, `{key.name} refused a {what} without naming the key: {message}`
				end
			end
		end
	end

	return true, nil
end
