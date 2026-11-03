--[[
    Each SoundId is recorded once, in the order its first sound was made, a
    state's at its value then, and Element.ids gives a fresh list each call
--]]

--!strict
local Environment = require("../../Environment")

local FIRST: string = "rbxassetid://1"
local SECOND: string = "rbxassetid://2"
local THIRD: string = "rbxassetid://3"
local LATER: string = "rbxassetid://4"
local EFFECT: string = "EqualizerSoundEffect"
local NUMBER: number = 5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	if #Element.ids() ~= 0 then
		return false, "a fresh environment already held recorded ids"
	end

	local state: any = { [Keys.State] = true, current = SECOND }

	Element.create("Sound", { SoundId = FIRST })
	Element.create("Sound", { SoundId = state })
	state.current = LATER
	Element.create("Sound", { SoundId = FIRST })
	Element.create("Sound")
	Element.create("Sound", { SoundId = NUMBER })
	Element.create(EFFECT, { SoundId = LATER })
	Element.create(function (): any
		return Element.create("Sound", { SoundId = THIRD })
	end)

	local ids: { string } = Element.ids()
	local expected: { string } = { FIRST, SECOND, THIRD }
	if #ids ~= #expected then
		return false, `{#ids} ids were recorded, not {#expected}: {table.concat(ids, ", ")}`
	end

	for index: number, id: string in expected do
		if ids[index] ~= id then
			return false, `the id recorded {index} was {ids[index]}, not {id}`
		end
	end

	table.clear(ids)
	if Element.ids()[1] ~= FIRST or Element.ids() == Element.ids() then
		return false, "Element.ids gave the recorded list itself, not a fresh one"
	end

	local other: Environment.Environment = Environment.new()
	if #other.require("Element").ids() ~= 0 then
		return false, "a second environment held the first one's ids"
	end

	return true, nil
end
