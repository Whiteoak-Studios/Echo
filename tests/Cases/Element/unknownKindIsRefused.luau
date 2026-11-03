--[[
    A kind that is no Sound, legacy effect class, component or Echo.Fragment
    is refused, naming the kind
--]]

--!strict
local Environment = require("../../Environment")

local NUMBER: number = 5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	-- An instance class, an Audio API effect written in place of its legacy class, and values that are no kind
	local kinds: { { kind: any, name: string } } = {
		{ kind = "Part", name = "Part" },
		{ kind = "AudioReverb", name = "AudioReverb" },
		{ kind = NUMBER, name = `{NUMBER}` },
		{ kind = Keys.Event.Ended, name = Keys.Event.Ended.name },
		{ kind = {}, name = "table" },
		{ kind = nil, name = "nil" },
	}

	for _, refused: { kind: any, name: string } in kinds do
		local made: boolean, message: any = pcall(Element.create, refused.kind)
		if made then
			return false, `Echo made an element of kind {refused.name}`
		elseif not tostring(message):find(`kind {refused.name}`, 1, true) then
			return false, `Echo refused the kind {refused.name} without naming it: {message}`
		end
	end

	return true, nil
end
