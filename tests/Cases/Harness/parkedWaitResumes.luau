--[[
    A thread parked on the fake clock resumes once a case steps past what it
    waits for: task.wait, Heartbeat:Wait, an event's Wait and the package's
    own Promise, while a cancelled thread never resumes
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local FRAME: number = 1 / 60
local WAIT: number = 1
local RESULT: string = "settled"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local package: any = env.require()
	local task: any = env.task
	local runService: any = env.game:GetService("RunService")
	local folder: any = env.Instance.new("Folder")

	local heartbeat: number? = nil
	task.spawn(function ()
		heartbeat = runService.Heartbeat:Wait()
	end)

	local waited: number? = nil
	task.spawn(function ()
		waited = task.wait(WAIT)
	end)

	local added: any = nil
	task.spawn(function ()
		added = folder.ChildAdded:Wait()
	end)

	local awaited: { any }? = nil
	task.spawn(function ()
		local promise: any = package.Promise.delay(WAIT):andThen(function (): string
			return RESULT
		end)

		awaited = { promise:await() }
	end)

	local cancelledRan: boolean = false
	task.cancel(task.spawn(function ()
		task.wait(WAIT)
		cancelledRan = true
	end))

	if heartbeat or waited or added or awaited then
		return false, "a parked thread resumed before anything it waits for happened"
	end

	env.step(FRAME)
	if heartbeat ~= FRAME or waited then
		return false, `Heartbeat:Wait returned {heartbeat}, and task.wait({WAIT}) resumed a frame in`
	end

	local child: any = env.Instance.new("Folder")
	child.Parent = folder
	if added ~= child then
		return false, "ChildAdded:Wait did not resume with the child the moment it arrived"
	end

	env.step(WAIT)
	if waited == nil or waited < WAIT then
		return false, `task.wait({WAIT}) returned {waited}`
	end

	if not awaited or awaited[1] ~= true or awaited[2] ~= RESULT then
		return false, "a thread awaiting the package's Promise did not resume with its value"
	end

	if cancelledRan or #env.errors ~= 0 then
		return false, `a cancelled thread resumed, or a thread threw: {env.errors[1]}`
	end

	return true, nil
end
