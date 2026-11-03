--[[
    A legacy play rewinds the Sound before it plays and runs playing once,
    a pause keeps its place for the resume, and a stop ends it
--]]

--!strict
local Environment = require("../../../Environment")

local POSITION: number = 1.5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")

	local tree: any = Legacy.template()
	local sound: any = Legacy.playable(tree)

	local playing: number = 0
	Legacy.connect(tree, {
		ended = function () end,
		looped = function () end,
		loaded = function () end,
		playing = function ()
			playing += 1
		end,
	})

	Legacy.apply(tree, "TimePosition", POSITION)
	Legacy.play(tree)
	if not sound.Playing or sound.TimePosition ~= 0 or playing ~= 1 then
		return false, "play did not rewind and play the Sound, then run playing once"
	end

	Legacy.apply(tree, "TimePosition", POSITION)
	Legacy.pause(tree)
	if sound.Playing or sound.TimePosition ~= POSITION then
		return false, "pause did not stop the Sound where it was"
	end

	Legacy.resume(tree)
	if not sound.Playing or sound.TimePosition ~= POSITION or playing ~= 1 then
		return false, "resume did not play on from where the pause left it, or ran playing"
	end

	Legacy.stop(tree)
	if sound.Playing then
		return false, "stop left the Sound playing"
	end

	return true, nil
end
