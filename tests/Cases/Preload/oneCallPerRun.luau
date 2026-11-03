--[[
    Each run makes exactly one PreloadAsync call holding every id it takes,
    however many there are, and a sound made after a run joins the next one
--]]

--!strict
local Environment = require("../../Environment")

local COUNT: number = 200
local PRIORITY: string = "rbxassetid://priority"
local OVERRIDE: string = "rbxassetid://override"
local NEWER: string = "rbxassetid://newer"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Preload: any = env.require("Preload")

	for index: number = 1, COUNT do
		Element.create("Sound", { SoundId = `rbxassetid://{index}` })
	end

	Preload.run({ PRIORITY }, { OVERRIDE })
	if #env.preload.calls ~= 1 or #env.preload.calls[1] ~= COUNT + 2 then
		return false, `{COUNT + 2} ids went into {#env.preload.calls} PreloadAsync calls, not one`
	end

	Element.create("Sound", { SoundId = NEWER })
	Preload.run()

	local second: { string }? = env.preload.calls[2]
	if #env.preload.calls ~= 2 or not second then
		return false, `a second run left {#env.preload.calls} PreloadAsync calls, not 2`
	elseif #second ~= COUNT + 1 or second[COUNT + 1] ~= NEWER then
		return false, `the second run's call held {#second} ids, ending {second[#second]}, not {NEWER}`
	end

	return true, nil
end
