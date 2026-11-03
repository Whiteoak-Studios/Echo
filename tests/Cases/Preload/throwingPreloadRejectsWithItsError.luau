--[[
    A PreloadAsync that throws rejects the run's Promise with its own error,
    and nothing throws at the call
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local FAILURE: string = "ContentProvider is having a bad day"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Preload: any = env.require("Preload")

	Element.create("Sound", { SoundId = ID })
	env.preload.error = FAILURE

	local ran: boolean, promise: any = pcall(Preload.run)
	if not ran then
		return false, `a throwing PreloadAsync threw out of the call: {promise}`
	end

	local rejection: any = nil
	promise:catch(function (message: any)
		rejection = message
	end)

	if promise:getStatus() ~= "Rejected" then
		return false, `a throwing PreloadAsync left the run {promise:getStatus()}, where it rejects`
	elseif type(rejection) ~= "string" or not rejection:find(FAILURE, 1, true) then
		return false, `the run rejected with {rejection}, not the error PreloadAsync threw`
	end

	return true, nil
end
