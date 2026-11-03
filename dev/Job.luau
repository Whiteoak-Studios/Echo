--[[
    One run of a job: the lines it reports, everything it made or mounted,
    given back however the run ends, and its waits, each ending in a failure
    that names what it waited on once its own deadline passes
--]]

--!strict
local Job = {}
Job.__index = Job

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Echo = require(ReplicatedStorage.Packages.Echo)

local Scene = require(script.Parent.Scene)

local PERCENTILE: number = 0.95 -- The share of plays at or under the reported percentile

export type Playing = Sound | AudioPlayer -- What a voice's instance is while it plays
export type Verdict = "PASS" | "FAIL" | "DONE"

export type Context = {
	scene: Scene.Scene,
	configureError: string?, -- What Echo.configure raised at boot, nil when it ran
	caption: (text: string) -> (), -- Shows a caption on screen
}

type Fields = {
	name: string,
	ran: number, -- The jobs that ran before this one in the play session
	scene: Scene.Scene,
	configureError: string?,
	lines: { string },
	_caption: (text: string) -> (),
	_owned: { any }, -- Instances, connections, roots and cleanup functions, given back last first
	_leaks: { string }, -- What giving one of them back raised
}

-- Thrown by fail, so a job's first refused check ends it with its reason
type Failure = { reason: string }

-- Gives back one owned thing the way its kind is given back
local function release(thing: any)
	local kind: string = typeof(thing)
	if kind == "Instance" then
		thing:Destroy()
	elseif kind == "RBXScriptConnection" then
		thing:Disconnect()
	elseif kind == "function" then
		thing()
	else
		thing:destroy()
	end
end

function Job.new(name: string, ran: number, context: Context): Self
	return setmetatable({
		name = name,
		ran = ran,
		scene = context.scene,
		configureError = context.configureError,
		lines = {} :: { string },
		_caption = context.caption,
		_owned = {} :: { any },
		_leaks = {} :: { string },
	}, Job)
end

--[[
    Adds a line to the job's result and prints it at once, so a long job
    shows its progress in the output
--]]

function Job.line(self: Self, text: string)
	table.insert(self.lines, text)
	print(`EchoDev {self.name}: {text}`)
end

--[[
    Prints a caption for the sound about to play and shows it on screen
--]]

function Job.caption(self: Self, text: string)
	self:line(`caption: {text}`)
	self._caption(text)
end

--[[
    Ends the job with a reason, which the runner reports as its FAIL line
--]]

function Job.fail(self: Self, reason: string): never
	self:line(`failed: {reason}`)

	local failure: Failure = { reason = reason }
	error(failure)
end

--[[
    Fails the job unless the check holds, and records it as a line when it
    does
--]]

function Job.expect(self: Self, holds: boolean, text: string)
	if not holds then
		self:fail(text)
	end

	self:line(`ok: {text}`)
end

--[[
    Gives back a value that must be there, failing the job naming it when
    it is nil
--]]

function Job.need<T>(self: Self, value: T?, what: string): T
	if value == nil then
		self:fail(`no {what}`)
	end

	return value :: T
end

--[[
    Plays an element through its handle and gives the voice and the
    instance playing it, failing the job when the pool gives neither
--]]

function Job.play(self: Self, handle: Echo.Handle, overrides: Echo.Overrides?, what: string): (Echo.Voice, Playing)
	local voice: Echo.Voice = self:need(handle:play(overrides), `voice for {what}`)

	return voice, self:need(voice.instance, `instance playing {what}`)
end

--[[
    Waits frame by frame until ready answers true, or fails the job naming
    what it waited on once the seconds have passed
--]]

function Job.wait(self: Self, ready: () -> boolean, seconds: number, what: string)
	local deadline: number = os.clock() + seconds
	while not ready() and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end

	if not ready() then
		self:fail(`waited {seconds} s for {what}`)
	end
end

--[[
    Waits for a Promise to settle within the seconds and gives its value,
    failing the job when it is late or rejected
--]]

function Job.await(self: Self, promise: any, seconds: number, what: string): any
	self:wait(function (): boolean
		return promise:getStatus() ~= "Started"
	end, seconds, what)

	local resolved: boolean, value: any = promise:await()
	if not resolved then
		self:fail(`{what} was rejected: {value}`)
	end

	return value
end

--[[
    Takes something the job made, mounted or connected, to give back when
    the job is cleaned, and hands it straight back

    @ thing | an Instance, a connection, a root, or a function that gives something back
--]]

function Job.own<T>(self: Self, thing: T): T
	table.insert(self._owned, thing)

	return thing
end

--[[
    Gives back everything owned so far, the last taken first. One that
    raises is recorded and the rest still go back
--]]

function Job.clean(self: Self)
	while #self._owned > 0 do
		local thing: any = table.remove(self._owned)
		local released: boolean, message: any = pcall(release, thing)

		if not released then
			table.insert(self._leaks, tostring(message))
			self:line(`giving back failed: {message}`)
		end
	end
end

function Job.leaks(self: Self): { string }
	return self._leaks
end

--[[
    The reason a job ended: a check's own, or whatever else it raised
--]]

function Job.reason(thrown: any): string
	if type(thrown) == "table" and type(thrown.reason) == "string" then
		return thrown.reason
	end

	return tostring(thrown)
end

--[[
    Whether a voice's instance has its asset ready to play: a Sound's
    IsLoaded, an AudioPlayer's IsReady
--]]

function Job.loaded(instance: Playing): boolean
	if instance:IsA("Sound") then
		return (instance :: Sound).IsLoaded
	end

	return (instance :: AudioPlayer).IsReady
end

function Job.fixed(value: number): string
	return string.format("%.2f", value)
end

--[[
    The median, the 95th percentile and the worst of a list of figures, each
    by nearest rank
--]]

function Job.summary(values: { number }): (number, number, number)
	local sorted: { number } = table.clone(values)
	table.sort(sorted)

	local count: number = #sorted

	return sorted[math.ceil(count / 2)], sorted[math.ceil(count * PERCENTILE)], sorted[count]
end

export type Run = (job: Job) -> (Verdict, string)
export type Job = Self
type Self = typeof(setmetatable({} :: Fields, Job))

return Job
