--[[
    An Audio API voice's looped gets the loops it counted since its last
    play, since the player's Looped carries no count, and a Looped after
    Echo's stop reaches nothing
--]]

--!strict
local Environment = require("../../../Environment")
local Signal = require("../../../Fakes/Signal")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")

	local tree: any = AudioApi.template()
	local player: any = AudioApi.playable(tree)
	AudioApi.apply(tree, "Looped", true)

	local counts: { number } = {}
	AudioApi.connect(tree, {
		ended = function () end,
		loaded = function () end,
		playing = function () end,
		looped = function (count: number)
			table.insert(counts, count)
		end,
	})

	AudioApi.play(tree)
	env.loop(player)
	env.loop(player)
	AudioApi.play(tree)
	env.loop(player)
	AudioApi.stop(tree)
	Signal.fire(player.Looped)

	if #counts ~= 3 or counts[1] ~= 1 or counts[2] ~= 2 or counts[3] ~= 1 then
		return false, `looped got {table.concat(counts, ", ")}, not 1, 2, then 1 after a new play`
	end

	return true, nil
end
