--[[
    The pass takes the ids given first, then the recorded ones, then the ids
    given last, each once at its first place, and leaves out an empty id
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
	local Element: any = env.require("Element")
	local Preload: any = env.require("Preload")

	Element.create("Sound", { SoundId = RECORDED })
	Element.create("Sound", { SoundId = PRIORITY })
	Element.create("Sound", { SoundId = SHARED })
	Element.create("Sound", { SoundId = EMPTY })
	Element.create("Sound", { SoundId = LATER })

	Preload.run({ PRIORITY, SHARED, PRIORITY, EMPTY }, { OVERRIDE, LATER, RECORDED, OVERRIDE, EMPTY })

	if #env.preload.calls ~= 1 then
		return false, `the run made {#env.preload.calls} PreloadAsync calls, not 1`
	end

	local call: { string } = env.preload.calls[1]
	local expected: { string } = { PRIORITY, SHARED, RECORDED, LATER, OVERRIDE }
	if #call ~= #expected then
		return false, `the pass took {#call} ids, not {#expected}: {table.concat(call, ", ")}`
	end

	for index: number, id: string in expected do
		if call[index] ~= id then
			return false, `the pass took {call[index]} at {index}, not {id}: {table.concat(call, ", ")}`
		end
	end

	return true, nil
end
