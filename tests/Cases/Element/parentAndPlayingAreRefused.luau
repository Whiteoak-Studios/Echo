--[[
    A pooled voice's parent and playback are Echo's own, so a sound refuses
    each refused property, as a value or a state, pointing to Action.Play
--]]

--!strict
local Environment = require("../../Environment")

local POINTER: string = "Echo.Action.Play"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Constants: any = env.require("Constants")
	local Keys: any = env.require("Keys")

	local values: { [string]: any } = {
		boolean = true,
		state = { [Keys.State] = true, current = true },
		instance = env.Instance.new("Folder"),
	}

	for name: string in Constants.REFUSED_PROPERTIES do
		for what: string, value: any in values do
			local made: boolean, message: any = pcall(Element.create, "Sound", { [name] = value })
			if made then
				return false, `a sound took a {what} under {name}`
			end

			local text: string = tostring(message)
			if not text:find(name, 1, true) or not text:find(POINTER, 1, true) then
				return false, `a {what} under {name} was refused without naming it or pointing to {POINTER}: {text}`
			end
		end
	end

	return true, nil
end
