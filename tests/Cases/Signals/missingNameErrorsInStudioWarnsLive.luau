--[[
    A misspelled name, one that holds no signal, errors at the fire in
    Studio and only warns live, each message naming it
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Gun/AKM/Fire"
local MISSPELLED: string = "Gun/AMK/Fire"

return function (): (boolean, string | nil)
	local calls: number = 0
	local function count()
		calls += 1
	end

	local studio: Environment.Environment = Environment.new({ studio = true })
	local studioSignals: any = studio.require("Signals")
	studioSignals.create(NAME, count)

	local fired: boolean, reason: any = pcall(studioSignals.fire, MISSPELLED)
	if fired or not tostring(reason):find(MISSPELLED, 1, true) then
		return false, `in Studio a misspelled name gave {fired}, {reason}`
	end

	local live: Environment.Environment = Environment.new({ studio = false })
	local liveSignals: any = live.require("Signals")
	liveSignals.create(NAME, count)

	local liveFired: boolean, liveReason: any = pcall(liveSignals.fire, MISSPELLED)
	if not liveFired then
		return false, `live, a misspelled name threw: {liveReason}`
	end

	if #live.warnings ~= 1 or not live.warnings[1]:find(MISSPELLED, 1, true) then
		return false, `live, a misspelled name gave {#live.warnings} warnings, the first {live.warnings[1]}`
	end

	if calls ~= 0 then
		return false, "a misspelled name ran another name's callback"
	end

	return true, nil
end
