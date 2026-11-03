--[[
    A signal is named only by a string: fire and remove error at the call on
    any other name, the signal's own table included, naming what they got
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Shot"
local NUMBER: number = 7

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Signals: any = env.require("Signals")

	local calls: number = 0
	Signals.create(NAME, function ()
		calls += 1
	end)

	for _, name: any in { {}, NUMBER, false } do
		local fired: boolean, reason: any = pcall(Signals.fire, name)
		if fired then
			return false, `fire took a {typeof(name)} as a name`
		elseif not tostring(reason):find(typeof(name), 1, true) then
			return false, `fire's error did not name the {typeof(name)} it got: {reason}`
		end

		if pcall(Signals.remove, name) then
			return false, `remove took a {typeof(name)} as a name`
		end
	end

	local missing: boolean = pcall(Signals.fire, nil)
	if missing or calls ~= 0 then
		return false, "fire took a missing name, or a refused name ran a callback"
	end

	return true, nil
end
