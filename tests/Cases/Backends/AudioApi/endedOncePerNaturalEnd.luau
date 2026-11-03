--[[
    An Audio API voice's ended runs once per natural end and never for
    Echo's own stop, pause or restart, an Ended the engine fires late or
    twice included, and never once its callbacks are disconnected (limit 6)
--]]

--!strict
local Environment = require("../../../Environment")
local Signal = require("../../../Fakes/Signal")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")

	local tree: any = AudioApi.template()
	local player: any = AudioApi.playable(tree)
	AudioApi.apply(tree, "SoundId", "rbxassetid://1")

	local ended: number = 0
	local disconnect: () -> () = AudioApi.connect(tree, {
		ended = function ()
			ended += 1
		end,
		looped = function () end,
		loaded = function () end,
		playing = function () end,
	})

	AudioApi.play(tree)
	env.finish(player)
	if ended ~= 1 then
		return false, `a natural end ran ended {ended} times, not once`
	end

	Signal.fire(player.Ended)
	if ended ~= 1 then
		return false, "a second Ended for one end ran ended again"
	end

	AudioApi.play(tree)
	AudioApi.stop(tree)
	Signal.fire(player.Ended)
	if ended ~= 1 then
		return false, "Echo's stop, or an Ended the engine fired after it, ran ended"
	end

	AudioApi.play(tree)
	AudioApi.pause(tree)
	Signal.fire(player.Ended)
	AudioApi.resume(tree)
	if ended ~= 1 then
		return false, "an Ended during Echo's pause, which stops the player, ran ended"
	end

	-- An Ended from the restart's own Stop that arrives after its Play, as a deferred event can
	AudioApi.play(tree)
	Signal.fire(player.Ended)
	if ended ~= 1 then
		return false, "an Ended arriving while the voice plays again ran ended"
	end

	env.finish(player)
	if ended ~= 2 then
		return false, "the end of a restarted play did not run ended"
	end

	disconnect()
	disconnect()
	AudioApi.play(tree)
	env.finish(player)
	if ended ~= 2 then
		return false, "ended ran after its callbacks were disconnected"
	end

	return true, nil
end
