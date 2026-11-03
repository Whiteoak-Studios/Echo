--[[
    The states useState and useSpring make: a table holding its value in
    current and the state marker, which tells its subscribers of every set
--]]

--!strict
local Keys = require(script.Parent.Keys)
local Signal = require(script.Parent.Signal)

-- The key each state keeps its signal under, which no code outside this file can name
local SIGNAL: { nil } = {}

local Types = require(script.Parent.Types)

type State<T> = Types.State<T>

type Fields<T> = {
	current: T,
	[{ nil }]: any, -- The marker, and the signal under SIGNAL
}

local State = {}

--[[
    Makes a state holding the default and gives its setter. Every set
    updates current and then tells each subscriber, a repeat of the value
    it already holds included
--]]

function State.new<T>(default: T): (State<T>, (value: T) -> ())
	local signal: Signal.Signal = Signal.new()
	local state: Fields<T> = { current = default }

	state[Keys.State] = true
	state[SIGNAL] = signal

	local function set(value: T)
		state.current = value
		signal:fire(value)
	end

	return state, set
end

function State.is(value: any): boolean
	return type(value) == "table" and rawget(value, Keys.State) == true
end

function State.get<T>(state: State<T>): T
	return state.current
end

--[[
    Gives each set's value to the callback, and gives its disconnect, which
    is safe to call any number of times
--]]

function State.subscribe<T>(state: State<T>, callback: (value: T) -> ()): () -> ()
	local signal: Signal.Signal = (state :: any)[SIGNAL]

	return signal:subscribe(callback)
end

type Self = typeof(State)

return State
