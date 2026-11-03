--[[
    Limit 22 on 7.8.6: a fire of a registered name runs its callback and
    builds no Promise, which a counting Promise stand-in proves
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "Gun/AKM/Fire"
local FIRES: number = 3

return function (): (boolean, string | nil)
	-- Runs each executor at once and counts it, so 7.8.6 works and each Promise it builds shows
	local made: number = 0
	local settled: any = {}
	function settled.catch(self: any): any
		return self
	end

	local counting: any = {
		new = function (executor: any): any
			made += 1
			executor(function () end, function () end)
			return settled
		end,
	}

	local env: Environment.Environment = Environment.new({ source = "legacy", dependencies = { Promise = counting } })
	local Echo: any = env.require()

	local calls: number = 0
	Echo.createSignal(NAME, function ()
		calls += 1
	end)

	local before: number = made
	for _ = 1, FIRES do
		Echo.useSignal(NAME)
	end

	if made ~= before or calls ~= FIRES then
		return false,
			`{FIRES} fires of a registered name built {made - before} Promises and ran the callback {calls} times`
	end

	return true, nil
end
