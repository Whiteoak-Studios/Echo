--[[
    An error in create's own setup raises at the call: a name that is no
    string, or a callback that is no function, and nothing is registered
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Reload"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ studio = true })
	local Signals: any = env.require("Signals")

	local function callback() end

	if pcall(Signals.create, nil, callback) then
		return false, "create took a nil name"
	end

	if pcall(Signals.create, NAME, nil) then
		return false, "create took a nil callback"
	end

	for _, value: any in { NAME, {}, false } do
		local created: boolean, reason: any = pcall(Signals.create, NAME, value)
		if created then
			return false, `create took a {typeof(value)} as its callback`
		elseif not tostring(reason):find(typeof(value), 1, true) then
			return false, `create's error did not name the {typeof(value)} it got: {reason}`
		end
	end

	-- In Studio a name that holds no signal errors, so a refused create left none behind
	if pcall(Signals.fire, NAME) then
		return false, "a refused create registered the name"
	end

	if #env.warnings ~= 0 then
		return false, `a refused create warned where it should only raise: {env.warnings[1]}`
	end

	return true, nil
end
