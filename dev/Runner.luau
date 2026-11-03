--[[
    Runs one job at a time by name, taken from the LocalScript's Run
    attribute or from the panel, and reports it through the Status and
    Result attributes, the output and the panel
--]]

--!strict
local Runner = {}
Runner.__index = Runner

local Job = require(script.Parent.Job)

type Context = Job.Context
type Run = Job.Run

type Fields = {
	_holder: LocalScript, -- Carries the Run, Status and Result attributes
	_jobs: { [string]: Run },
	_context: Context,
	_show: (text: string) -> (), -- Puts a job's report on the panel
	_running: string?, -- The job now running, nil while none is
	_ran: number, -- The jobs that ran in this play session
}

--[[
    Makes the runner over every job of the given groups, each a table of
    jobs by name
--]]

function Runner.new(
	holder: LocalScript,
	groups: { { [string]: Run } },
	context: Context,
	show: (text: string) -> ()
): Self
	local jobs: { [string]: Run } = {}
	for _, group: { [string]: Run } in groups do
		for name: string, run: Run in group do
			assert(jobs[name] == nil, `Two job groups both hold a job named {name}`)
			jobs[name] = run
		end
	end

	return setmetatable({
		_holder = holder,
		_jobs = jobs,
		_context = context,
		_show = show,
		_running = nil :: string?,
		_ran = 0,
	}, Runner)
end

--[[
    Takes every job name written to the Run attribute, clearing it, for the
    whole client session, and one already written before the call
--]]

function Runner.listen(self: Self)
	local holder: LocalScript = self._holder

	local function take()
		local name: any = holder:GetAttribute("Run")
		if type(name) ~= "string" then
			return
		end

		holder:SetAttribute("Run", nil)
		self:run(name)
	end

	-- Lives for the client session, like the LocalScript
	holder:GetAttributeChangedSignal("Run"):Connect(take)
	take()
end

--[[
    Starts a job on a thread of its own and returns at once. A job named
    while another runs, or one no group holds, fails at once
--]]

function Runner.run(self: Self, name: string)
	local running: string? = self._running
	if running then
		return self:_report(`FAIL {name}: BUSY, {running} is running`, {})
	end

	local run: Run? = self._jobs[name]
	if not run then
		return self:_report(`FAIL {name}: no job has that name`, {})
	end

	self._running = name
	self:_report(`RUNNING {name} since {string.format("%.1f", os.clock())}`, {})

	-- Ends with the job, which _execute bounds by the deadline of each of its waits
	task.spawn(function ()
		self:_execute(name, run)
	end)
end

--[[
    Runs a job, gives back everything it owns however it ended, and reports
    its verdict line, a give-back that raised turning it into a FAIL
--]]

function Runner._execute(self: Self, name: string, run: Run)
	local job: Job.Job = Job.new(name, self._ran, self._context)
	self._ran += 1

	local ran: boolean, verdict: any, summary: any = pcall(run, job)
	job:clean()

	local status: string
	if not ran then
		status = `FAIL {name}: {Job.reason(verdict)}`
	elseif #job:leaks() > 0 then
		status = `FAIL {name}: giving back what it made raised {#job:leaks()} times; {summary}`
	elseif summary == "" then
		status = `{verdict} {name}`
	else
		status = `{verdict} {name}: {summary}`
	end

	self._running = nil
	self:_report(status, job.lines)
end

function Runner._report(self: Self, status: string, lines: { string })
	local result: string = table.concat(lines, "\n")

	self._holder:SetAttribute("Status", status)
	self._holder:SetAttribute("Result", result)
	print(`EchoDev {status}`)
	self._show(`{status}\n{result}`)
end

export type Runner = Self
type Self = typeof(setmetatable({} :: Fields, Runner))

return Runner
