--[[
    AudioApi.checkEffect takes a legacy effect's property only when its
    Audio API class has one of the same name, and Priority, which orders the
    chain, and refuses the rest, naming the property
--]]

--!strict
local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")
	local Constants: any = env.require("Constants")

	for className: string in Constants.EFFECTS do
		local reason: string? = AudioApi.checkEffect(className, "Priority", 3)
		if reason then
			return false, `checkEffect refused {className}.Priority: {reason}`
		end
	end

	local taken: { { any } } = {
		{ "EqualizerSoundEffect", "HighGain", -6 },
		{ "DistortionSoundEffect", "Level", 0.5 },
		{ "ReverbSoundEffect", "DecayTime", 2 },
		{ "EchoSoundEffect", "Feedback", 0.25 },
		{ "TremoloSoundEffect", "Frequency", nil },
	}

	for _, row: { any } in taken do
		local reason: string? = AudioApi.checkEffect(row[1], row[2], row[3])
		if reason then
			return false, `checkEffect refused {row[1]}.{row[2]} = {row[3]}: {reason}`
		end
	end

	-- Each row names the class, the property, the value and what the reason must name
	local refused: { { any } } = {
		{ "EchoSoundEffect", "Delay", 0.5, "Delay" }, -- AudioEcho's is DelayTime
		{ "PitchShiftSoundEffect", "Octave", 1.25, "Octave" }, -- AudioPitchShifter's is Pitch
		{ "CompressorSoundEffect", "GainMakeup", 2, "GainMakeup" }, -- AudioCompressor's is MakeupGain
		{ "EqualizerSoundEffect", "MidRange", nil, "MidRange" }, -- Only the Audio API class has it
		{ "EqualizerSoundEffect", "Enabled", true, "Enabled" },
		{ "EqualizerSoundEffect", "Bypass", false, "Bypass" },
		{ "EqualizerSoundEffect", "HighGain", "loud", "HighGain" },
		{ "EqualizerSoundEffect", "Priority", "first", "Priority" },
		{ "AudioReverb", "WetLevel", 0, "AudioReverb" },
	}

	for _, row: { any } in refused do
		local reason: string? = AudioApi.checkEffect(row[1], row[2], row[3])
		if not reason or not reason:find(row[4]) then
			return false,
				`checkEffect took {row[1]}.{row[2]} = {row[3]}, or refused it without naming {row[4]}: {reason}`
		end
	end

	return true, nil
end
