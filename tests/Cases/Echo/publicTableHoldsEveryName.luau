--[[
    The public table holds every documented name and nothing else, so no
    createBinding and no Bind, and its key tokens are the ones elements read
--]]

--!strict
local Environment = require("../../Environment")

-- Each documented name, and the type of the value it holds
local NAMES: { [string]: string } = {
	configure = "function",
	createElement = "function",
	Fragment = "table",
	root = "function",
	useState = "function",
	useSpring = "function",
	createRef = "function",
	useRef = "function",
	Event = "table",
	Action = "table",
	Util = "table",
	createSignal = "function",
	useSignal = "function",
	removeSignal = "function",
	preload = "function",
	getCache = "function",
	getAll = "function",
}

local REMOVED: { string } = { "createBinding", "Bind" }

-- Each token table's documented tokens
local TOKENS: { [string]: { string } } = {
	Event = { "Ended", "Playing", "Looped", "Loaded" },
	Action = { "Play", "Pause" },
	Util = { "Cap", "Bus" },
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Echo: any = env.require()
	local Keys: any = env.require("Keys")

	for name: string, kind: string in NAMES do
		if type(Echo[name]) ~= kind then
			return false, `Echo.{name} is a {type(Echo[name])}, not a {kind}`
		end
	end

	for _, name: string in REMOVED do
		if Echo[name] ~= nil then
			return false, `Echo still holds {name}, which 8.0.0 removes`
		end
	end

	for name: any in Echo do
		if not NAMES[name] then
			return false, `Echo holds {name}, which the public API does not document`
		end
	end

	if Echo.Fragment ~= Keys.Fragment then
		return false, "Echo.Fragment is not the token an element reads as a fragment's kind"
	end

	for group: string, tokens: { string } in TOKENS do
		local count: number = 0
		for _ in Echo[group] do
			count += 1
		end

		if count ~= #tokens then
			return false, `Echo.{group} holds {count} tokens, not {#tokens}`
		end

		for _, token: string in tokens do
			if Echo[group][token] == nil or Echo[group][token] ~= Keys[group][token] then
				return false, `Echo.{group}.{token} is not the token an element reads under that key`
			end
		end
	end

	return true, nil
end
