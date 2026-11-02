--[[
    Two environments share nothing: each loads its own modules, Cellar and
    game, keeps its own warnings and runs on its own clock
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local CATEGORY: string = "Harness/Fresh"
local STEP: number = 1

return function (): (boolean, string | nil)
	local first: Environment.Environment = Environment.new({ source = FIXTURE })
	local second: Environment.Environment = Environment.new({ source = FIXTURE })

	first.require("Direct"):count()
	if first.require("Direct"):count() ~= 2 or second.require("Direct"):count() ~= 1 then
		return false, "a module's state reached a second environment"
	end

	if first.require() == second.require() or first.game == second.game then
		return false, "two environments share a module or a game"
	end

	local firstCellar: any = first.require().Cellar
	local secondCellar: any = second.require().Cellar
	if not firstCellar:create(CATEGORY) or not secondCellar:create(CATEGORY) then
		return false, "Cellar in a second environment already held the first one's category"
	end

	-- A second create of a name warns, and only into the environment that made it
	firstCellar:create(CATEGORY)
	if #first.warnings ~= 1 or #second.warnings ~= 0 then
		return false, `the warnings were {#first.warnings} and {#second.warnings}, not 1 and 0`
	end

	first.step(STEP)
	if first.now() ~= STEP or second.now() ~= 0 then
		return false, "stepping one environment moved another's clock"
	end

	return true, nil
end
