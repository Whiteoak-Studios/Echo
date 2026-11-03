--[[
    A legacy voice's ended runs once per natural end and never for Echo's
    own stop or pause, an Ended the engine fires late or twice included,
    and never once its callbacks are disconnected (limit 6)
--]]

--!strict
local Environment = require("../../../Environment")
local Signal = require("../../../Fakes/Signal")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")
	Legacy.setup()

	local tree: any = Legacy.template()
	local sound: any = Legacy.playable(tree)
	Legacy.apply(tree, "SoundId", "rbxassetid://1")
	Legacy.route(tree, nil, false)

	local ended: number = 0
	local disconnect: () -> () = Legacy.connect(tree, {
		ended = function ()
			ended += 1
		end,
		looped = function () end,
		loaded = function () end,
		playing = function () end,
	})

	Legacy.play(tree)
	env.finish(sound)
	if ended ~= 1 then
		return false, `a natural end ran ended {ended} times, not once`
	end

	Signal.fire(sound.Ended, sound.SoundId)
	if ended ~= 1 then
		return false, "a second Ended for one end ran ended again"
	end

	Legacy.play(tree)
	Legacy.stop(tree)
	Signal.fire(sound.Ended, sound.SoundId)
	if ended ~= 1 then
		return false, "Echo's stop, or an Ended the engine fired after it, ran ended"
	end

	Legacy.play(tree)
	Legacy.pause(tree)
	Signal.fire(sound.Ended, sound.SoundId)
	Legacy.resume(tree)
	if ended ~= 1 then
		return false, "an Ended during Echo's pause ran ended"
	end

	-- An Ended from before a play that arrives after it, as a deferred event can
	Signal.fire(sound.Ended, sound.SoundId)
	if ended ~= 1 then
		return false, "an Ended arriving while the voice plays again ran ended"
	end

	env.finish(sound)
	if ended ~= 2 then
		return false, "the end of a resumed play did not run ended"
	end

	disconnect()
	disconnect()
	Legacy.play(tree)
	env.finish(sound)
	if ended ~= 2 then
		return false, "ended ran after its callbacks were disconnected"
	end

	return true, nil
end
