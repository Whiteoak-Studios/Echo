--[[
    A prop key that is neither a string nor one of Echo's keys is refused,
    on a sound and on an effect, naming the key
--]]

--!strict
local Environment = require("../../Environment")

local EFFECT: string = "ChorusSoundEffect"
local INDEX: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	-- Each key, to the name its refusal gives it
	local sound: { [any]: string } = {
		[Keys.Fragment] = Keys.Fragment.name,
		[INDEX] = `{INDEX}`,
		[true] = "true",
	}

	local effect: { [any]: string } = {
		[Keys.Event.Ended] = Keys.Event.Ended.name,
		[Keys.Util.Cap] = Keys.Util.Cap.name,
		[INDEX] = `{INDEX}`,
	}

	local kinds: { [string]: { [any]: string } } = {
		Sound = sound,
		[EFFECT] = effect,
	}

	for kind: string, keys: { [any]: string } in kinds do
		for key: any, name: string in keys do
			local made: boolean, message: any = pcall(Element.create, kind, { [key] = true })
			if made then
				return false, `a {kind} took the prop key {name}`
			elseif not tostring(message):find(`key {name}`, 1, true) then
				return false, `a {kind} refused the prop key {name} without naming it: {message}`
			end
		end
	end

	return true, nil
end
