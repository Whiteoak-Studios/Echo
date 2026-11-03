--[[
    Only a sound takes children, and only effect elements under string keys;
    any other child, and children on any other kind, are refused by name
--]]

--!strict
local Environment = require("../../Environment")

local EFFECT: string = "ReverbSoundEffect"
local DECAY: number = 2
local INDEX: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local reverb: any = Element.create(EFFECT, { DecayTime = DECAY })
	local sound: any = Element.create("Sound", {}, { Reverb = reverb })
	if sound.effects.Reverb ~= reverb then
		return false, "a sound did not keep its effect child under its key"
	end

	-- Each refused set of children, to the name its refusal gives
	local children: { { given: { [any]: any }, name: string } } = {
		{ given = { Reverb = Element.create("Sound") }, name = "Reverb" },
		{ given = { Reverb = Element.create(Keys.Fragment) }, name = "Reverb" },
		{ given = { Reverb = { DecayTime = DECAY } }, name = "Reverb" },
		{ given = { Reverb = EFFECT }, name = "Reverb" },
		{ given = { [INDEX] = reverb }, name = `{INDEX}` },
	}

	for _, refused: { given: { [any]: any }, name: string } in children do
		local made: boolean, message: any = pcall(Element.create, "Sound", {}, refused.given)
		if made then
			return false, `a sound took the child {refused.name}`
		elseif not tostring(message):find(refused.name, 1, true) then
			return false, `a sound refused the child {refused.name} without naming it: {message}`
		end
	end

	-- Each other kind, to the name its refusal gives it
	local kinds: { { kind: any, name: string } } = {
		{ kind = EFFECT, name = EFFECT },
		{ kind = Keys.Fragment, name = Keys.Fragment.name },
		{
			kind = function (): any
				return sound
			end,
			name = "function",
		},
	}

	for _, other: { kind: any, name: string } in kinds do
		local made: boolean, message: any = pcall(Element.create, other.kind, {}, { Reverb = reverb })
		if made then
			return false, `a {other.name} took children`
		elseif not tostring(message):find(other.name, 1, true) then
			return false, `a {other.name} refused children without naming its kind: {message}`
		end
	end

	return true, nil
end
