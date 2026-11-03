--[[
    Limit 9 on 7.8.6: a signal created again after removeSignal fires only
    its own callbacks, never another removed signal's
--]]

--!strict
local Environment = require("../../Environment")

local FIRST: string = "Door/Open"
local SECOND: string = "Door/Close"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local counts: { [string]: number } = {}
	local function counter(key: string): () -> ()
		return function ()
			counts[key] = (counts[key] or 0) + 1
		end
	end

	Echo.createSignal(FIRST, counter("first old"))
	Echo.createSignal(SECOND, counter("second old"))
	Echo.removeSignal(FIRST)
	Echo.removeSignal(SECOND)

	Echo.createSignal(FIRST, counter("first new"))
	Echo.createSignal(SECOND, counter("second new"))

	Echo.useSignal(FIRST)
	Echo.useSignal(SECOND)
	env.step(0)

	local ran: { string } = {}
	for key: string, count: number in counts do
		table.insert(ran, `{key} {count}`)
	end
	table.sort(ran)

	if #ran ~= 2 or counts["first new"] ~= 1 or counts["second new"] ~= 1 then
		return false, `firing {FIRST} and then {SECOND} once each ran: {table.concat(ran, ", ")}`
	end

	return true, nil
end
