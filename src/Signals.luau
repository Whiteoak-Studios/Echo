--[[
    The named signals a game creates and fires: one Signal under each name,
    which a fire looks up directly and runs inside the call
--]]

--!strict
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)

local Types = require(script.Parent.Types)

type SignalCallback = Types.SignalCallback

-- Each name's signal, until remove clears the name
local Named: { [string]: Signal.Signal } = {}

local Signals = {}

local function checkName(name: any)
	if type(name) ~= "string" then
		error(`Echo: a signal's name is a string, not {typeof(name)}`, 3)
	end
end

--[[
    Subscribes a callback under a name and gives its disconnect. A callback
    that returns a function is unsubscribed in the fire that called it, and
    the function then runs at once, inside that fire
--]]

function Signals.create(name: string, callback: SignalCallback): () -> ()
	checkName(name)
	if type(callback) ~= "function" then
		error(`Echo: createSignal takes a function, not {typeof(callback)}`, 2)
	end

	local signal: Signal.Signal = Named[name] or Signal.new()
	Named[name] = signal

	local disconnect: () -> ()
	disconnect = signal:subscribe(function (...: any)
		local cleanup: (() -> ())? = callback(...)
		if cleanup then
			disconnect()
			cleanup()
		end
	end)

	return disconnect
end

--[[
    Runs every callback under a name with the given values, inside this
    call. Every callback runs when one throws, and the first error is then
    raised here. A name that holds no signal errors in Studio and warns live
--]]

function Signals.fire(name: string, ...: any)
	checkName(name)

	local signal: Signal.Signal? = Named[name]
	if not signal then
		local message: string = `Echo: no signal is named "{name}"; create it with createSignal before firing it`
		if RunService:IsStudio() then
			error(message, 2)
		end

		return warn(message)
	end

	signal:fire(...)
end

--[[
    Clears a name's entry, so a signal created again under it fires only
    its own callbacks
--]]

function Signals.remove(name: string)
	checkName(name)
	Named[name] = nil
end

type Self = typeof(Signals)

return Signals
