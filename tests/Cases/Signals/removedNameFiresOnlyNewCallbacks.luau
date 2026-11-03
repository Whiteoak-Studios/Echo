--[[
    remove clears a name's entry, so firing it then fails as for any name
    with no signal, and a signal created again fires only its own callbacks
--]]

--!strict
local Environment = require("../../Environment")

local FIRST: string = "Door/Open"
local SECOND: string = "Door/Close"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ studio = true })
	local Signals: any = env.require("Signals")

	local counts: { [string]: number } = {}
	local function counter(key: string): () -> ()
		return function ()
			counts[key] = (counts[key] or 0) + 1
		end
	end

	local disconnectOld: () -> () = Signals.create(FIRST, counter("first old"))
	Signals.create(SECOND, counter("second old"))
	Signals.remove(FIRST)
	Signals.remove(SECOND)

	if pcall(Signals.fire, FIRST) then
		return false, "a removed name still held a signal"
	end

	Signals.create(FIRST, counter("first new"))
	Signals.create(SECOND, counter("second new"))

	-- An old disconnect reaches only the removed signal
	disconnectOld()

	Signals.fire(FIRST)
	Signals.fire(SECOND)

	local ran: { string } = {}
	for key: string, count: number in counts do
		table.insert(ran, `{key} {count}`)
	end
	table.sort(ran)

	if #ran ~= 2 or counts["first new"] ~= 1 or counts["second new"] ~= 1 then
		return false, `after the names were made again, the fires ran: {table.concat(ran, ", ")}`
	end

	return true, nil
end
