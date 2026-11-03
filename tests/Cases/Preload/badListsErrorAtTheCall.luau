--[[
    A first or ids that is no table, or holds an entry that is no string,
    errors at the call naming the argument and the entry, before any Promise
    or holder is made
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local NUMBER: number = 5

type Refusal = {
	label: string,
	first: any,
	ids: any,
	names: string, -- Text the error must hold
}

local REFUSALS: { Refusal } = {
	{ label = "a first that is a string", first = ID, names = "first" },
	{ label = "ids that are a number", ids = NUMBER, names = "ids" },
	{ label = "ids that are true", first = { ID }, ids = true, names = "ids" },
	{ label = "a number in first", first = { ID, NUMBER }, names = "first[2]" },
	{ label = "a table in ids", first = { ID }, ids = { {} }, names = "ids[1]" },
	{ label = "a boolean in ids", ids = { ID, ID, false }, names = "ids[3]" },
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Constants: any = env.require("Constants")
	local Element: any = env.require("Element")
	local Preload: any = env.require("Preload")

	Element.create("Sound", { SoundId = ID })

	for _, refusal: Refusal in REFUSALS do
		local ran: boolean, reason: any = pcall(Preload.run, refusal.first, refusal.ids)
		if ran then
			return false, `a run took {refusal.label}, and gave back {reason}`
		elseif not tostring(reason):find(refusal.names, 1, true) then
			return false, `the error on {refusal.label} did not name {refusal.names}: {reason}`
		end
	end

	if env.game:GetService("SoundService"):FindFirstChild(Constants.FOLDER_NAME) then
		return false, "refused runs made SoundService's Echo folder for a holder"
	end

	return true, nil
end
