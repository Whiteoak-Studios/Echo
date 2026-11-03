--[[
    An Audio API voice's loaded runs when its player turns ready, through a
    defer when it already is, and never when the callbacks are disconnected
    before the defer runs (limit 7)
--]]

--!strict
local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")

	local tree: any = AudioApi.template()
	local player: any = AudioApi.playable(tree)
	AudioApi.apply(tree, "SoundId", "rbxassetid://1")

	local loaded: number = 0
	local events: { [string]: any } = {
		ended = function () end,
		looped = function () end,
		playing = function () end,
		loaded = function ()
			loaded += 1
		end,
	}

	local disconnect: () -> () = AudioApi.connect(tree, events)
	env.step(0)
	if loaded ~= 0 then
		return false, "loaded ran for a player that was not ready"
	end

	env.load(player)
	if loaded ~= 1 then
		return false, `a player turning ready ran loaded {loaded} times, not once`
	end

	disconnect()
	disconnect = AudioApi.connect(tree, events)
	if loaded ~= 1 then
		return false, "loaded ran inside connect for a ready player, not through a defer"
	end

	env.step(0)
	if loaded ~= 2 then
		return false, "loaded never ran for a player that was already ready"
	end

	-- A new asset drops IsReady, which turning false again must not read as a load
	AudioApi.apply(tree, "SoundId", "rbxassetid://2")
	if loaded ~= 2 then
		return false, "IsReady turning false ran loaded"
	end

	disconnect()
	env.load(player)
	AudioApi.connect(tree, events)()
	env.step(0)
	if loaded ~= 2 then
		return false, "loaded ran after its callbacks were disconnected"
	end

	return true, nil
end
