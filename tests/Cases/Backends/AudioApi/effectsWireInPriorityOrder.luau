--[[
    An Audio API effect is added once per class and key and wired between
    the player and its output, highest Priority first and then by key,
    whatever order effect and route run in, and clear bypasses it in place
--]]

--!strict
local Environment = require("../../../Environment")

local MAX_STAGES: number = 16

-- The stages the player's sound passes through, following each Wire from the player to where the chain ends
local function chainOf(tree: any, player: any): { any }
	local stages: { any } = {}
	local current: any = player

	for _ = 1, MAX_STAGES do
		local target: any = nil
		for _, child: any in tree:GetChildren() do
			if child:IsA("Wire") and child.SourceInstance == current then
				target = child.TargetInstance
			end
		end

		if not target then
			break
		end

		table.insert(stages, target)
		current = target
	end

	return stages
end

local function names(stages: { any }): string
	local parts: { string } = {}
	for _, stage: any in stages do
		table.insert(parts, `{stage.ClassName} {stage.Name}`)
	end

	return table.concat(parts, ", ")
end

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")
	AudioApi.setup()

	local output: any = env.game:GetService("SoundService").Echo.AudioDeviceOutput
	local tree: any = AudioApi.template()
	local player: any = AudioApi.playable(tree)
	local emitter: any = tree.AudioEmitter

	-- An effect before any route, then the route, then more effects
	AudioApi.effect(tree, "ReverbSoundEffect", "Room", { WetLevel = -3 })
	AudioApi.route(tree, nil, true)
	AudioApi.effect(tree, "EqualizerSoundEffect", "Muffle", { HighGain = -6, Priority = 5 })
	AudioApi.effect(tree, "DistortionSoundEffect", "Crunch", { Level = 0.5 })
	AudioApi.effect(tree, "EqualizerSoundEffect", "Muffle", { LowGain = -2 })

	local stages: { any } = chainOf(tree, player)
	local expected: string =
		"AudioEqualizer Muffle, AudioDistortion Crunch, AudioReverb Room, AudioEmitter AudioEmitter"
	if names(stages) ~= expected then
		return false, `the chain runs {names(stages)}, not {expected}`
	elseif stages[1].Bypass or stages[1].HighGain ~= -6 or stages[1].LowGain ~= -2 or stages[3].WetLevel ~= -3 then
		return false, "an effect is bypassed or missing a property it was given"
	end

	-- A higher Priority moves an effect up the chain, and a 2D route moves only the end
	AudioApi.effect(tree, "ReverbSoundEffect", "Room", { Priority = 9 })
	AudioApi.route(tree, nil, false)
	stages = chainOf(tree, player)
	expected = "AudioReverb Room, AudioEqualizer Muffle, AudioDistortion Crunch, AudioDeviceOutput AudioDeviceOutput"
	if names(stages) ~= expected or stages[4] ~= output then
		return false, `the chain runs {names(stages)}, not {expected}`
	end

	-- Clear puts every Priority back to 0, so the chain falls back to key order
	AudioApi.clear(tree)
	stages = chainOf(tree, player)
	expected = "AudioDistortion Crunch, AudioEqualizer Muffle, AudioReverb Room"
	if names(stages) ~= expected then
		return false, `after clear the chain runs {names(stages)}, not {expected} to no output`
	end

	for _, stage: any in stages do
		if not stage.Bypass then
			return false, `clear left {stage.ClassName} {stage.Name} on`
		end
	end

	local equalizer: any = stages[2]
	local fresh: any = env.Instance.new("AudioEqualizer")
	if equalizer.HighGain ~= fresh.HighGain or equalizer.LowGain ~= fresh.LowGain or emitter.Parent ~= tree then
		return false, "clear did not put an effect's properties back to its defaults"
	end

	AudioApi.effect(tree, "EqualizerSoundEffect", "Muffle", { Priority = "first" })
	if #chainOf(tree, player) ~= 3 or equalizer.Bypass or #env.warnings ~= 1 then
		return false, "a use after clear made a new effect, left it bypassed, or a bad Priority did not warn"
	end

	return true, nil
end
