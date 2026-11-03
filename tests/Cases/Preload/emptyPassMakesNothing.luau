--[[
    A run with no id to load, or only empty ones, resolves an empty list at
    once and makes no holder, nor the Echo folder one would sit in
--]]

--!strict
local Environment = require("../../Environment")

local EMPTY: string = ""

type Run = {
	label: string,
	first: { string }?,
	ids: { string }?,
}

local RUNS: { Run } = {
	{ label = "no lists" },
	{ label = "two empty lists", first = {}, ids = {} },
	{ label = "only empty ids", first = { EMPTY }, ids = { EMPTY } },
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Constants: any = env.require("Constants")
	local Element: any = env.require("Element")
	local Preload: any = env.require("Preload")

	Element.create("Sound")
	Element.create("Sound", { SoundId = EMPTY })

	for _, run: Run in RUNS do
		local promise: any = Preload.run(run.first, run.ids)
		if promise:getStatus() ~= "Resolved" then
			return false, `a run with {run.label} was {promise:getStatus()}, where it resolves at once`
		end

		local settled: boolean, failed: any = promise:await()
		if not settled or type(failed) ~= "table" or next(failed) ~= nil then
			return false, `a run with {run.label} resolved {failed}, not an empty list`
		end
	end

	if env.game:GetService("SoundService"):FindFirstChild(Constants.FOLDER_NAME) then
		return false, "runs with no id to load made SoundService's Echo folder"
	end

	return true, nil
end
