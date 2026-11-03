--[[
    A run resolves with the ids whose fetch did not succeed, in the order the
    pass took them, and an empty list when every id loaded, settled whether
    the caller awaits its Promise or chains on it
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")

local FIRST: string = "rbxassetid://1"
local SECOND: string = "rbxassetid://2"
local THIRD: string = "rbxassetid://3"
local FOURTH: string = "rbxassetid://4"
local PASSED: number = 4 -- FOURTH and the three recorded ids

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Preload: any = env.require("Preload")
	local Enum: any = roblox.Enum

	Element.create("Sound", { SoundId = FIRST })
	Element.create("Sound", { SoundId = SECOND })
	Element.create("Sound", { SoundId = THIRD })

	local loaded: { string }? = nil
	local chained: any = Preload.run():andThen(function (failed: { string })
		loaded = failed
	end)

	if chained:getStatus() ~= "Resolved" or not loaded or #loaded ~= 0 then
		return false, `a run where every id loaded was {chained:getStatus()}, with {loaded and #loaded} failed`
	end

	-- The pass takes FOURTH, FIRST, SECOND, THIRD, so its failures come back FOURTH before SECOND
	env.preload.statuses[SECOND] = Enum.AssetFetchStatus.TimedOut
	env.preload.statuses[FOURTH] = Enum.AssetFetchStatus.Failure

	local promise: any = Preload.run({ FOURTH }, nil)
	if promise:getStatus() ~= "Resolved" then
		return false, `a run with failed ids was {promise:getStatus()}, where it resolves`
	end

	local settled: boolean, failed: any = promise:await()
	if not settled or type(failed) ~= "table" or #failed ~= 2 or failed[1] ~= FOURTH or failed[2] ~= SECOND then
		local got: string = type(failed) == "table" and table.concat(failed, ", ") or `{failed}`
		return false, `the run resolved {got}, not {FOURTH}, {SECOND}`
	end

	if #env.preload.calls ~= 2 or #env.preload.calls[2] ~= PASSED then
		return false, "the run with failed ids did not pass every id, the loaded ones included"
	end

	return true, nil
end
