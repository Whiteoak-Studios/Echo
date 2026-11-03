--[[
    A function under a property's name is refused when the sound is made,
    naming the property and pointing to Echo's Event keys
--]]

--!strict
local Environment = require("../../Environment")

-- A property's name, and an event's name written as if it were a property
local NAMES: { string } = { "Volume", "Ended" }
local POINTER: string = "Echo.Event"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")

	for _, name: string in NAMES do
		local made: boolean, message: any = pcall(Element.create, "Sound", { [name] = function () end })
		if made then
			return false, `a function under {name} was taken`
		end

		local text: string = tostring(message)
		if not text:find(name, 1, true) or not text:find(POINTER, 1, true) then
			return false, `a function under {name} was refused without naming it or pointing to {POINTER}: {text}`
		end
	end

	return true, nil
end
