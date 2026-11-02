--[[
    The fake RBXScriptSignal behind every fake event: Connect, Once and Wait,
    each handler on a thread of its own as in immediate signal mode, and
    connections with Disconnect and Connected
--]]

--!strict
local Clock = require("./Clock")

type Clock = Clock.Clock

type State = {
	clock: Clock,
	connections: { any }, -- In the order they connected
	handlers: { [any]: (...any) -> ...any },
	once: { [any]: boolean },
	waiting: { (...any) -> () }, -- The resume of each thread parked in Wait
}

-- The key each signal and connection keeps its state under, which no code outside this file can name
local STATE: { nil } = {}

local Methods = {}
local ConnectionMethods = {}

local SignalMetatable = {
	__index = Methods,
	__tostring = function (): string
		return "Signal"
	end,
}

local ConnectionMetatable = {
	__index = ConnectionMethods,
	__tostring = function (): string
		return "Connection"
	end,
}

local Signal = {}

function Signal.new(clock: Clock): any
	local state: State = {
		clock = clock,
		connections = {},
		handlers = {},
		once = {},
		waiting = {},
	}

	return setmetatable({ [STATE] = state }, SignalMetatable)
end

function Signal.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == SignalMetatable
end

function Signal.isConnection(value: any): boolean
	return type(value) == "table" and getmetatable(value) == ConnectionMetatable
end

local function stateOf(signal: any): State
	if not Signal.is(signal) then
		error(`{typeof(signal)} {signal} is not a fake signal`, 2)
	end

	return rawget(signal, STATE) :: State
end

local function connect(self: any, callback: any, once: boolean): any
	local state: State = stateOf(self)

	if type(callback) ~= "function" then
		error(`Attempt to connect failed: Passed value is not a function`, 3)
	end

	local connection: any = setmetatable({ Connected = true, [STATE] = state }, ConnectionMetatable)
	state.handlers[connection] = callback
	state.once[connection] = once
	table.insert(state.connections, connection)

	return connection
end

function Methods.Connect(self: any, callback: any): any
	return connect(self, callback, false)
end

function Methods.Once(self: any, callback: any): any
	return connect(self, callback, true)
end

function Methods.Wait(self: any): ...any
	local state: State = stateOf(self)
	local hold: () -> ...any, resume: (...any) -> () = state.clock.pending()
	table.insert(state.waiting, resume)

	return hold()
end

--[[
    Ends a connection; a second call does nothing, as the engine allows
--]]

function ConnectionMethods.Disconnect(self: any)
	if not self.Connected then
		return
	end

	local state: State = rawget(self, STATE) :: State
	self.Connected = false
	state.handlers[self] = nil
	state.once[self] = nil

	local index: number? = table.find(state.connections, self)
	if index then
		table.remove(state.connections, index)
	end
end

--[[
    Fires a signal to the handlers connected when it fires, so one connected
    during the fire runs from the next, then resumes every thread in Wait
--]]

function Signal.fire(signal: any, ...: any)
	local state: State = stateOf(signal)

	-- Whiteoak TODO: handlers run in immediate mode only; queue them on the clock's defers once a case needs deferred mode
	for _, connection: any in table.clone(state.connections) do
		local handler: ((...any) -> ...any)? = state.handlers[connection]
		if not handler then
			continue
		end

		if state.once[connection] then
			connection:Disconnect()
		end

		state.clock.task.spawn(handler, ...)
	end

	local waiting: { (...any) -> () } = state.waiting
	state.waiting = {}

	for _, resume: (...any) -> () in waiting do
		resume(...)
	end
end

--[[
    Ends every connection and drops every waiting thread, as a destroyed
    instance's events do
--]]

function Signal.clear(signal: any)
	local state: State = stateOf(signal)

	for _, connection: any in table.clone(state.connections) do
		connection:Disconnect()
	end

	state.waiting = {}
end

function Signal.count(signal: any): number
	return #stateOf(signal).connections
end

return Signal
