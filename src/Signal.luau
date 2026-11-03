--[[
    The signal states, springs and named signals share: callbacks kept under
    empty-table tokens, each run under xpcall so one that throws stops none
--]]

--!strict
local Signal = {}
Signal.__index = Signal

type Callback = (...any) -> ...any

type Fields = {
	_listeners: { [{ nil }]: Callback },
	_held: { [{ nil }]: Callback }, -- Subscribed during a fire, joining once no fire runs
	_firing: number, -- Fires running now, a fire from inside a callback included
}

local function traceback(message: any): string
	return debug.traceback(tostring(message), 2)
end

function Signal.new(): Self
	return setmetatable({
		_listeners = {} :: { [{ nil }]: Callback },
		_held = {} :: { [{ nil }]: Callback },
		_firing = 0,
	}, Signal)
end

--[[
    Subscribes a callback and gives its disconnect, which is safe to call
    any number of times. A callback subscribed during a fire runs from the
    next fire
--]]

function Signal.subscribe(self: Self, callback: Callback): () -> ()
	if type(callback) ~= "function" then
		error(`Echo: a callback is a function, not {typeof(callback)}`, 2)
	end

	local token: { nil } = {}
	local bucket: { [{ nil }]: Callback } = self._firing > 0 and self._held or self._listeners
	
	bucket[token] = callback

	-- Cleanup
	return function ()
		self._listeners[token] = nil
		self._held[token] = nil
	end
end

--[[
    Runs every callback with the given values, in no set order. One that
    throws stops none of the others, and the first error is raised once the
    last callback has run
--]]

function Signal.fire(self: Self, ...: any)
	local failure: string? = nil

	-- Whiteoak TODO: a callback that yields keeps its fire running, so a callback subscribed meanwhile waits
	-- until that fire ends; a snapshot of the listeners per fire lifts the ceiling once a yielding callback needs it
	self._firing += 1
	for _, callback: Callback in self._listeners do
		local ran: boolean, message: any = xpcall(callback, traceback, ...)
		if not ran and not failure then
			failure = message
		end
	end
	
	self._firing -= 1

	-- A callback joins only once no fire walks the listeners, since a key added mid-walk breaks the walk
	if self._firing == 0 then
		for token: { nil }, callback: Callback in self._held do
			self._listeners[token] = callback
		end

		table.clear(self._held)
	end

	if failure then
		error(failure, 0)
	end
end

export type Signal = Self
type Self = typeof(setmetatable({} :: Fields, Signal))

return Signal
