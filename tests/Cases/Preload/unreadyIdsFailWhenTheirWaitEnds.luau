--[[
    An id whose holder never turns ready counts as failed when its wait
    ends, while the ids that load succeed, and the pass resolves with the
    failed ids in the order it took them, leaving no connection behind
--]]

--!strict
local Environment = require("../../Environment")

local FIRST: string = "rbxassetid://1"
local SECOND: string = "rbxassetid://2"
local THIRD: string = "rbxassetid://3"
local FOURTH: string = "rbxassetid://4"
local SLACK: number = 0.1 -- Seconds short of the wait, when every unready id still waits

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Constants: any = env.require("Constants")
	local Element: any = env.require("Element")
	local Preload: any = env.require("Preload")
	local length: number = Constants.PRELOAD_WAIT

	Element.create("Sound", { SoundId = FIRST })
	Element.create("Sound", { SoundId = SECOND })
	Element.create("Sound", { SoundId = THIRD })

	local failed: { string }? = nil
	local promise: any = Preload.run({ FOURTH }, nil):andThen(function (ids: { string })
		failed = ids
	end)

	local folder: any = env.game:GetService("SoundService"):FindFirstChild(Constants.FOLDER_NAME)
	local firstHolder: any = folder and folder:FindFirstChild(FIRST)
	local thirdHolder: any = folder and folder:FindFirstChild(THIRD)
	if not firstHolder or not thirdHolder then
		return false, `the pass made no holder for {FIRST} or {THIRD} in SoundService's Echo folder`
	end

	-- The pass takes FOURTH, FIRST, SECOND, THIRD, and FIRST and THIRD load part way through the wait
	env.step(length / 2)
	env.load(firstHolder)
	env.load(thirdHolder)

	env.step(length / 2 - SLACK)
	if promise:getStatus() ~= "Started" then
		return false, `the pass was {promise:getStatus()} before its unready ids' wait ended`
	end

	env.step(SLACK)
	if
		promise:getStatus() ~= "Resolved"
		or not failed
		or #failed ~= 2
		or failed[1] ~= FOURTH
		or failed[2] ~= SECOND
	then
		local got: string = failed and table.concat(failed, ", ") or "nothing"
		return false, `the pass was {promise:getStatus()} with {got}, where it resolves with {FOURTH}, {SECOND}`
	end

	for _, holder: any in folder:GetChildren() do
		if env.connections(holder:GetPropertyChangedSignal("IsReady")) ~= 0 then
			return false, `the pass left a connection on {holder.Name}'s IsReady once it resolved`
		end
	end

	return true, nil
end
