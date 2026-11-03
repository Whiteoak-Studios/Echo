--[[
    The pass holds each id on an AudioPlayer of its own in SoundService's
    Echo folder, made in pass order before any turns ready, and resolves an
    empty list once every holder is ready, leaving no connection behind
--]]

--!strict
local Environment = require("../../Environment")

local PRIORITY: string = "rbxassetid://1"
local RECORDED: string = "rbxassetid://2"
local SHARED: string = "rbxassetid://3"
local LATER: string = "rbxassetid://4"
local OVERRIDE: string = "rbxassetid://5"
local EMPTY: string = ""

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Constants: any = env.require("Constants")
	local Element: any = env.require("Element")
	local Preload: any = env.require("Preload")

	Element.create("Sound", { SoundId = RECORDED })
	Element.create("Sound", { SoundId = PRIORITY })
	Element.create("Sound", { SoundId = SHARED })
	Element.create("Sound", { SoundId = EMPTY })
	Element.create("Sound", { SoundId = LATER })

	-- No configure runs first, since a game may preload before it
	local first: { string } = { PRIORITY, SHARED, PRIORITY, EMPTY }
	local promise: any = Preload.run(first, { OVERRIDE, LATER, RECORDED, OVERRIDE, EMPTY })

	local folder: any = env.game:GetService("SoundService"):FindFirstChild(Constants.FOLDER_NAME)
	if not folder then
		return false, "the pass made no Echo folder under SoundService for its holders"
	end

	local holders: { any } = folder:GetChildren()
	local names: { string } = {}
	for _, holder: any in holders do
		table.insert(names, holder.Name)
	end

	local expected: { string } = { PRIORITY, SHARED, RECORDED, LATER, OVERRIDE }
	if #holders ~= #expected then
		return false, `the pass made {#holders} holders, not {#expected}: {table.concat(names, ", ")}`
	end

	for index: number, id: string in expected do
		local holder: any = holders[index]
		if not holder:IsA("AudioPlayer") or holder.Name ~= id or holder.Asset ~= id then
			return false, `holder {index} is {holder.ClassName} {holder.Name} set to {holder.Asset}, not one for {id}`
		end
	end

	if promise:getStatus() ~= "Started" then
		return false, `the pass was {promise:getStatus()} while no holder was ready`
	end

	for _, holder: any in holders do
		env.load(holder)
	end

	if promise:getStatus() ~= "Resolved" then
		return false, `the pass was {promise:getStatus()} once every holder was ready, where it resolves`
	end

	local _, failed: any = promise:await()
	if type(failed) ~= "table" or next(failed) ~= nil then
		return false, `the pass resolved {failed}, not an empty list`
	end

	for _, holder: any in holders do
		if env.connections(holder:GetPropertyChangedSignal("IsReady")) ~= 0 then
			return false, `the pass left a connection on {holder.Name}'s IsReady once it resolved`
		end
	end

	return true, nil
end
