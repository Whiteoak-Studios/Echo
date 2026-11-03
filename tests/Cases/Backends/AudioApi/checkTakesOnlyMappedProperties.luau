--[[
    AudioApi.check takes each property it maps and the three the curve is
    built from with a value of a legacy Sound's type, and refuses, naming
    it, any other property and a value of another type
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")
	local Constants: any = env.require("Constants")

	local samples: { [string]: any } = {
		SoundId = "rbxassetid://1",
		Volume = 0.25,
		PlaybackSpeed = 1.5,
		TimePosition = 2,
		Looped = true,
		PlaybackRegion = roblox.NumberRange.new(1, 2),
		LoopRegion = roblox.NumberRange.new(0.5, 1.5),
		RollOffMode = roblox.Enum.RollOffMode.InverseTapered,
		RollOffMinDistance = 0,
		RollOffMaxDistance = 300,
	}

	for _, names: { [string]: any } in { Constants.AUDIO_API_PROPERTIES, Constants.CURVE_PROPERTIES } do
		for property: string in names do
			if samples[property] == nil then
				return false, `the case has no sample for {property}`
			end

			local reason: string? = AudioApi.check(property, samples[property]) or AudioApi.check(property, nil)
			if reason then
				return false, `check refused {property} = {samples[property]}: {reason}`
			end
		end
	end

	local refused: { { any } } = {
		{ "Name", "Shot" }, -- A legacy Sound has it, an AudioPlayer has nothing it maps to
		{ "RollOffGain", 1 },
		{ "PlayOnRemove", true },
		{ "SoundGroup", nil },
		{ "Parent", nil },
		{ "Loudness", 1 },
		{ "Volume", "loud" },
		{ "Looped", 1 },
		{ "RollOffMode", "Linear" },
		{ "RollOffMode", roblox.Enum.Material.Plastic },
		{ "RollOffMinDistance", -1 },
		{ "RollOffMaxDistance", math.huge },
		{ "RollOffMaxDistance", "far" },
	}

	for _, pair: { any } in refused do
		local reason: string? = AudioApi.check(pair[1], pair[2])
		if not reason or not reason:find(pair[1]) then
			return false, `check took {pair[1]} = {pair[2]}, or refused it without naming it: {reason}`
		end
	end

	return true, nil
end
