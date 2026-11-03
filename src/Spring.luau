--[[
    The springs useSpring makes: a state for each number it is built with,
    and a start that moves them linearly to their targets on Heartbeat
--]]

--!strict
local Spring = {}
Spring.__index = Spring

local RunService = game:GetService("RunService")

local Promise: any = require(script.Parent.Parent.Promise)

local State = require(script.Parent.State)

local Types = require(script.Parent.Types)

type Style = Types.State<number>

type Fields = {
	_styles: { [string]: Style },
	_setters: { [string]: (value: number) -> () },
	_duration: number, -- The spring's own, which a config in the targets stands in for
	_delay: number,
	_running: any, -- The Promise of the latest start, canceled by the next
}

local function isSeconds(value: any): boolean
	return type(value) == "number" and value >= 0 and value < math.huge
end

--[[
    Reads a config's duration and delay, each none when it is left out
--]]

local function timing(config: any): (number, number)
	if config == nil then
		return 0, 0
	elseif type(config) ~= "table" then
		error(`Echo: a spring's config is a table, not {typeof(config)}`, 3)
	end

	local duration: any = config.duration or 0
	local delay: any = config.delay or 0
	
	if not isSeconds(duration) or not isSeconds(delay) then
		error(`Echo: a spring's duration and delay are seconds, 0 or more, not {duration} and {delay}`, 3)
	end

	return duration, delay
end

--[[
    Builds the spring from the builder's table: each number becomes a style,
    a state that binds like useState's, and nothing else does
--]]

function Spring.new(builder: () -> { [string]: any }): ({ [string]: Style }, Self)
	if type(builder) ~= "function" then
		error(`Echo: useSpring takes a function that builds its values, not {typeof(builder)}`, 2)
	end

	local values: any = builder()
	if type(values) ~= "table" then
		error(`Echo: useSpring's function returns a table, not {typeof(values)}`, 2)
	end

	local duration: number, delay: number = timing(values.config)
	local styles: { [string]: Style } = {}
	local setters: { [string]: (value: number) -> () } = {}

	for name: any, value: any in values do
		if type(name) == "string" and type(value) == "number" then
			styles[name], setters[name] = State.new(value)
		end
	end

	return styles,
		setmetatable({
			_styles = styles,
			_setters = setters,
			_duration = duration,
			_delay = delay,
			_running = nil :: any,
		}, Spring)
end

--[[
    Moves each named style linearly from where it is to its target over the
    duration, after the delay, and lands it exactly on the target. A config
    in the targets stands in for the spring's own, and a start cancels the
    one before it, Promise and all. Its Heartbeat connection ends when it
    lands, is canceled or a write throws, which rejects it

    @ targets | each style's end by name, and a config if this start has its own
--]]

function Spring.start(self: Self, targets: { [string]: any }): any
	if type(targets) ~= "table" then
		error(`Echo: start takes a table of targets, not {typeof(targets)}`, 2)
	end

	local duration: number, delay: number = self._duration, self._delay
	if targets.config ~= nil then
		duration, delay = timing(targets.config)
	end

	local from: { [string]: number } = {}
	for name: any, target: any in targets do
		if name == "config" then
			continue
		elseif not self._styles[name] then
			error(`Echo: the spring has no value named {name}`, 2)
		elseif type(target) ~= "number" then
			error(`Echo: the target for {name} is a number, not {typeof(target)}`, 2)
		end

		from[name] = self._styles[name].current
	end

	if self._running then
		self._running:cancel()
	end

	local setters: { [string]: (value: number) -> () } = self._setters
	local started: number = os.clock()

	-- Writes each value a fraction of the way along, and the target itself once the fraction reaches 1
	local function move(fraction: number)
		for name: string, start: number in from do
			local target: number = targets[name]
			setters[name](fraction >= 1 and target or start + (target - start) * fraction)
		end
	end

	if duration == 0 and delay == 0 then
		self._running = Promise.try(move, 1)

		return self._running
	end

	self._running = Promise.new(function (resolve: () -> (), reject: (message: any) -> (), onCancel: any)
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function ()
			local elapsed: number = os.clock() - started - delay
			if elapsed < 0 then
				return
			end

			local fraction: number = duration > 0 and elapsed / duration or 1
			local moved: boolean, message: any = pcall(move, fraction)
			if not moved or fraction >= 1 then
				connection:Disconnect()
			end

			if not moved then
				reject(message)
			elseif fraction >= 1 then
				resolve()
			end
		end)

		onCancel(function ()
			connection:Disconnect()
		end)
	end)

	return self._running
end

type Self = typeof(setmetatable({} :: Fields, Spring))

return Spring
