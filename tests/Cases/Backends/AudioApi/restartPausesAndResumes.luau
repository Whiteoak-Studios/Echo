--[[
    An Audio API play stops, rewinds and plays the player, which never
    rewinds itself, and runs playing once; a pause keeps its place and a
    resume plays on from there
--]]

--!strict
local Environment = require("../../../Environment")

local POSITION: number = 1.5
local LATER: number = 2.5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")

	local tree: any = AudioApi.template()
	local player: any = AudioApi.playable(tree)

	local playing: number = 0
	AudioApi.connect(tree, {
		ended = function () end,
		looped = function () end,
		loaded = function () end,
		playing = function ()
			playing += 1
		end,
	})

	AudioApi.apply(tree, "TimePosition", POSITION)
	AudioApi.play(tree)
	if not player.IsPlaying or player.TimePosition ~= 0 or playing ~= 1 then
		return false, "play did not rewind and play the player, then run playing once"
	end

	-- A play over one still playing restarts it
	AudioApi.apply(tree, "TimePosition", POSITION)
	AudioApi.play(tree)
	if not player.IsPlaying or player.TimePosition ~= 0 or playing ~= 2 then
		return false, "a play over a playing voice did not restart it"
	end

	AudioApi.apply(tree, "TimePosition", LATER)
	AudioApi.pause(tree)
	if player.IsPlaying or player.TimePosition ~= LATER then
		return false, "pause did not stop the player where it was"
	end

	AudioApi.resume(tree)
	if not player.IsPlaying or player.TimePosition ~= LATER or playing ~= 2 then
		return false, "resume did not play on from where the pause left it, or ran playing"
	end

	AudioApi.stop(tree)
	if player.IsPlaying then
		return false, "stop left the player playing"
	end

	return true, nil
end
