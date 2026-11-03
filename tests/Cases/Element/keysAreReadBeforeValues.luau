--[[
    A sound reads each prop by its key before its value, so a function or a
    table under one of Echo's keys is never taken for an event, ref or binding
--]]

--!strict
local Environment = require("../../Environment")

local CAP: string = "Gun/AKM/FirstPerson"
local BUS: string = "Effects"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local state: any = { [Keys.State] = true, current = true }
	local props: { [any]: any } = {
		[Keys.Util.Cap] = CAP,
		[Keys.Util.Bus] = BUS,
	}

	-- Every Event and Action token, read from Keys so a token added there is covered
	local events: { [any]: any } = {}
	for _, key: any in Keys.Event do
		local callback = function () end
		events[key] = callback
		props[key] = callback
	end

	for _, key: any in Keys.Action do
		props[key] = state
	end

	local sound: any = Element.create("Sound", props)
	for key: any, callback: any in events do
		if sound.events[key] ~= callback then
			return false, `the function under {key.name} is not the sound's event`
		end
	end

	for _, key: any in Keys.Action do
		if sound.actions[key] ~= state then
			return false, `the state under {key.name} is not the sound's action`
		end
	end

	if sound.cap ~= CAP or sound.bus ~= BUS then
		return false, "the names under the Util keys are not the sound's cap and bus"
	end

	if next(sound.properties) ~= nil or #sound.refs ~= 0 or next(sound.attributes) ~= nil then
		return false, "a value under one of Echo's keys reached the sound's properties, refs or attributes"
	end

	-- A function, a ref or a state under a Util key is refused, never read by its value
	local values: { [string]: any } = {
		["function"] = function () end,
		ref = Element.ref(nil),
		state = state,
	}

	for _, key: any in Keys.Util do
		for what: string, value: any in values do
			local made: boolean, message: any = pcall(Element.create, "Sound", { [key] = value })
			if made then
				return false, `{key.name} took a {what}`
			elseif not tostring(message):find(key.name, 1, true) then
				return false, `{key.name} refused a {what} without naming the key: {message}`
			end
		end
	end

	return true, nil
end
