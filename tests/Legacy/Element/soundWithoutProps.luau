--[[
    On 7.8.6, createElement with no props errors iterating nil; the fixed
    call takes the missing props as an empty table and makes the sound
--]]

--!strict
local Environment = require("../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local made: boolean, result: any = pcall(Echo.createElement, "Sound")
	if not made then
		return false, `createElement("Sound") with no props errored: {result}`
	end

	local sound: any = result[1]
	if not sound or not sound:IsA("Sound") then
		return false, "createElement with no props made no Sound"
	end

	return true, nil
end
