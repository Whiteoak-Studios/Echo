--[[
    A legacy voice's looped gets the loops counted since its last play, and
    a DidLoop after Echo's stop reaches nothing
--]]

--!strict
local Environment = require("../../../Environment")
local Signal = require("../../../Fakes/Signal")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")

	local tree: any = Legacy.template()
	local sound: any = Legacy.playable(tree)
	Legacy.apply(tree, "Looped", true)

	local counts: { number } = {}
	Legacy.connect(tree, {
		ended = function () end,
		loaded = function () end,
		playing = function () end,
		looped = function (count: number)
			table.insert(counts, count)
		end,
	})

	Legacy.play(tree)
	env.loop(sound)
	env.loop(sound)
	Legacy.play(tree)
	env.loop(sound)
	Legacy.stop(tree)
	Signal.fire(sound.DidLoop, sound.SoundId, 2)

	if #counts ~= 3 or counts[1] ~= 1 or counts[2] ~= 2 or counts[3] ~= 1 then
		return false, `looped got {table.concat(counts, ", ")}, not 1, 2, then 1 after a new play`
	end

	return true, nil
end
