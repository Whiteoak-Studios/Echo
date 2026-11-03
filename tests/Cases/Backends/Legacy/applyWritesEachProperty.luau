--[[
    Legacy.apply writes each element property both Modes take straight to
    the Sound, and warns and returns false, never erroring, on a value of
    another type and on a property a Sound lacks
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")
	local Constants: any = env.require("Constants")

	-- A value for each property both Modes take
	local samples: { [string]: any } = {
		SoundId = "rbxassetid://1",
		Volume = 0.25,
		PlaybackSpeed = 1.5,
		TimePosition = 2,
		Looped = true,
		PlaybackRegion = roblox.NumberRange.new(1, 2),
		LoopRegion = roblox.NumberRange.new(0.5, 1.5),
		RollOffMode = roblox.Enum.RollOffMode.Linear,
		RollOffMinDistance = 28,
		RollOffMaxDistance = 300,
	}

	local tree: any = Legacy.template()
	local sound: any = Legacy.playable(tree)

	for _, names: { [string]: any } in { Constants.AUDIO_API_PROPERTIES, Constants.CURVE_PROPERTIES } do
		for property: string in names do
			local value: any = samples[property]
			if value == nil then
				return false, `the case has no sample for {property}`
			elseif Legacy.apply(tree, property, value) ~= true or sound[property] ~= value then
				return false, `apply did not write {property} = {value} to the Sound`
			end
		end
	end

	local volume: number = sound.Volume
	if Legacy.apply(tree, "Volume", "loud") ~= false or sound.Volume ~= volume then
		return false, "apply wrote a string to Volume, or did not return false"
	elseif Legacy.apply(tree, "Loudness", 1) ~= false or Legacy.apply(tree, "Volume", nil) ~= false then
		return false, "apply did not return false for a property a Sound lacks, or for nil"
	elseif #env.warnings ~= 3 or not env.warnings[1]:find("Volume") or not env.warnings[2]:find("Loudness") then
		return false, `apply did not warn once per refused write, naming it: {table.concat(env.warnings, " | ")}`
	end

	return true, nil
end
