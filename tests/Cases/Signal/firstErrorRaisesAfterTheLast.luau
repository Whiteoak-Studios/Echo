--[[
    A callback that throws stops none of the others: every callback runs,
    and the fire then raises the first error it met
--]]

--!strict
local Environment = require("../../Environment")

local FIRST: string = "first callback broke"
local SECOND: string = "second callback broke"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Signal: any = env.require("Signal")
	local signal: any = Signal.new()

	local thrown: { string } = {}
	local ran: number = 0

	for _, message: string in { FIRST, SECOND } do
		signal:subscribe(function ()
			table.insert(thrown, message)
			error(message)
		end)
	end

	signal:subscribe(function ()
		ran += 1
	end)

	local fired: boolean, raised: any = pcall(signal.fire, signal)
	if fired then
		return false, "a fire with two throwing callbacks raised nothing"
	end

	if ran ~= 1 or #thrown ~= 2 then
		return false, `{#thrown} throwing callbacks and {ran} quiet ones ran, not 2 and 1`
	end

	local text: string = tostring(raised)
	if not text:find(thrown[1], 1, true) or text:find(thrown[2], 1, true) then
		return false, `the fire raised "{text}", not only the first error it met, "{thrown[1]}"`
	end

	return true, nil
end
