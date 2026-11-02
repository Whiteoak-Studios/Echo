--[[
    Environment.run, which the runner runs every case with, fails a case
    that is no function, throws, gives anything but true, waits forever on
    the fake clock, or leaves an error in an environment it built
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local LIMIT: number = 0.25 -- Real seconds, short so the parked case below fails fast
local WAIT: number = 1
local LEFT: string = "left behind"

--[[
    Builds an environment whose fake task thread throws, as a package
    callback would, and gives it with its error in env.errors
--]]

local function throwingEnvironment(): Environment.Environment
	local built: Environment.Environment = Environment.new({ source = FIXTURE })
	built.task.spawn(function ()
		error(LEFT)
	end)

	return built
end

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })

	local parked: boolean, parkedReason: string? = Environment.run(function (): (boolean, string | nil)
		env.task.wait(WAIT)
		return true, nil
	end, LIMIT)

	if parked or not tostring(parkedReason):find("had not finished", 1, true) then
		return false, `a case parked on the fake clock gave {parked}, {parkedReason}`
	end

	local threw: boolean, threwReason: string? = Environment.run(function (): (boolean, string | nil)
		error("broken case")
	end)

	if threw or not tostring(threwReason):find("broken case", 1, true) then
		return false, `a throwing case gave {threw}, {threwReason}`
	end

	local refused: boolean, refusedReason: string? = Environment.run(function (): (boolean, string | nil)
		return false, "refused"
	end)

	if refused or refusedReason ~= "refused" then
		return false, `a case returning false gave {refused}, {refusedReason}`
	end

	local silent: boolean, silentReason: string? = Environment.run(function (): boolean
		return false
	end)

	if silent or not tostring(silentReason):find("no reason", 1, true) then
		return false, `a case returning false with no reason gave {silent}, {silentReason}`
	end

	local function answersYes(): string
		return "yes"
	end

	if Environment.run(answersYes) then
		return false, "a case whose first return was a string, not true, passed"
	end

	if Environment.run({}) then
		return false, "a case file returning a table passed"
	end

	local function passes(): (boolean, string | nil)
		return true, nil
	end

	if not Environment.run(passes) then
		return false, "a passing case failed"
	end

	-- An error left in env.errors fails the case, whether it returned true or false, and the reason names it
	local function leavesAndPasses(): (boolean, string | nil)
		throwingEnvironment()

		return true, nil
	end

	local function leavesAndRefuses(): (boolean, string | nil)
		throwingEnvironment()

		return false, "refused"
	end

	for _, leaves: () -> (boolean, string | nil) in { leavesAndPasses, leavesAndRefuses } do
		local left: boolean, leftReason: string? = Environment.run(leaves)
		if left or not tostring(leftReason):find(LEFT, 1, true) then
			return false, `a case leaving an error in env.errors gave {left}, {leftReason}`
		end
	end

	local function clearsWhatItExpects(): (boolean, string | nil)
		local built: Environment.Environment = throwingEnvironment()
		if not built.errors[1] or not built.errors[1]:find(LEFT, 1, true) then
			return false, "the thrown error never reached env.errors"
		end

		table.clear(built.errors)

		return true, nil
	end

	local cleared: boolean, clearedReason: string? = Environment.run(clearsWhatItExpects)
	if not cleared then
		return false, `a case that read and cleared its expected error failed: {clearedReason}`
	end

	-- A run reads only the environments built during it, so an error in this case's own waits for this case
	local function throwsIntoOuter(): (boolean, string | nil)
		env.task.spawn(function ()
			error(LEFT)
		end)

		return true, nil
	end

	if not Environment.run(throwsIntoOuter) or not env.errors[1] then
		return false, "a run failed over an environment built outside it, or the error never landed"
	end

	table.clear(env.errors)

	return true, nil
end
