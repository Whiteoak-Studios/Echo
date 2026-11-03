--[[
    A spring moves between negative values as between any others: from -12
    up to 0 or -6, and down from 0 to -6, with no clamp, jump or error
--]]

--!strict
local Environment = require("../../Environment")

local DURATION: number = 1
local HALF: number = 0.5

type Move = {
	from: number,
	to: number,
}

local MOVES: { Move } = {
	{ from = -12, to = 0 },
	{ from = -12, to = -6 },
	{ from = 0, to = -6 },
}

return function (): (boolean, string | nil)
	for _, move: Move in MOVES do
		local env: Environment.Environment = Environment.new()
		local Spring: any = env.require("Spring")
		local State: any = env.require("State")

		local styles: any, api: any = Spring.new(function ()
			return { volume = move.from, config = { duration = DURATION, delay = 0 } }
		end)

		local promise: any = api:start({ volume = move.to })

		env.step(DURATION * HALF)
		local halfway: number = State.get(styles.volume)
		if halfway ~= move.from + (move.to - move.from) * HALF then
			return false, `halfway from {move.from} to {move.to} the spring stood at {halfway}`
		end

		env.step(DURATION * HALF)
		if State.get(styles.volume) ~= move.to or promise:getStatus() ~= "Resolved" then
			return false,
				`from {move.from} to {move.to} the spring ended at {State.get(styles.volume)}, its Promise {promise:getStatus()}`
		end

		if #env.warnings ~= 0 then
			return false, `from {move.from} to {move.to} the spring warned: {env.warnings[1]}`
		end
	end

	return true, nil
end
