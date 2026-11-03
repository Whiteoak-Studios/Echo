--[[
    Legacy.checkEffect takes a property each legacy effect class can write
    with a value of its type, Priority included, and refuses what Echo sets
    itself, what the class lacks, a wrong type and a class it does not take
--]]

--!strict
local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")
	local Constants: any = env.require("Constants")

	for className: string in Constants.EFFECTS do
		local reason: string? = Legacy.checkEffect(className, "Priority", 2)
		if reason then
			return false, `checkEffect refused {className}.Priority: {reason}`
		end
	end

	local taken: { { any } } = {
		{ "EqualizerSoundEffect", "HighGain", -6 },
		{ "EchoSoundEffect", "Delay", 0.5 },
		{ "PitchShiftSoundEffect", "Octave", 1.25 },
		{ "DistortionSoundEffect", "Level", nil },
	}

	for _, row: { any } in taken do
		local reason: string? = Legacy.checkEffect(row[1], row[2], row[3])
		if reason then
			return false, `checkEffect refused {row[1]}.{row[2]} = {row[3]}: {reason}`
		end
	end

	-- Each row names the class, the property, the value and what the reason must name
	local refused: { { any } } = {
		{ "EqualizerSoundEffect", "Enabled", false, "Enabled" },
		{ "EqualizerSoundEffect", "Parent", nil, "Parent" },
		{ "EqualizerSoundEffect", "Name", "Muffle", "Name" },
		{ "EqualizerSoundEffect", "Bypass", true, "Bypass" },
		{ "EqualizerSoundEffect", "MidGainRange", 1, "MidGainRange" },
		{ "EqualizerSoundEffect", "HighGain", "loud", "HighGain" },
		{ "Sound", "Volume", 1, "Sound" },
		{ "AudioEqualizer", "HighGain", 0, "AudioEqualizer" },
	}

	for _, row: { any } in refused do
		local reason: string? = Legacy.checkEffect(row[1], row[2], row[3])
		if not reason or not reason:find(row[4]) then
			return false,
				`checkEffect took {row[1]}.{row[2]} = {row[3]}, or refused it without naming {row[4]}: {reason}`
		end
	end

	return true, nil
end
