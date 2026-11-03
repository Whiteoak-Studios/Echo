--[[
    A legacy voice's loaded runs when its Sound loads, through a defer when
    the Sound has already loaded, and never when the callbacks are
    disconnected before the defer runs (limit 7)
--]]

--!strict
local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")

	local tree: any = Legacy.template()
	local sound: any = Legacy.playable(tree)
	Legacy.apply(tree, "SoundId", "rbxassetid://1")

	local loaded: number = 0
	local events: { [string]: any } = {
		ended = function () end,
		looped = function () end,
		playing = function () end,
		loaded = function ()
			loaded += 1
		end,
	}

	local disconnect: () -> () = Legacy.connect(tree, events)
	env.step(0)
	if loaded ~= 0 then
		return false, "loaded ran for a Sound that had not loaded"
	end

	env.load(sound)
	if loaded ~= 1 then
		return false, `a Sound loading ran loaded {loaded} times, not once`
	end

	disconnect()
	disconnect = Legacy.connect(tree, events)
	if loaded ~= 1 then
		return false, "loaded ran inside connect for a Sound already loaded, not through a defer"
	end

	env.step(0)
	if loaded ~= 2 then
		return false, "loaded never ran for a Sound that had already loaded"
	end

	disconnect()
	Legacy.connect(tree, events)()
	env.step(0)
	if loaded ~= 2 then
		return false, "a deferred loaded ran after its callbacks were disconnected"
	end

	return true, nil
end
