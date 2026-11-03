--[[
    AudioApi.apply writes each mapped property to the player under its
    mapped name, and warns and returns false, never erroring, on a value of
    another type and on a property Audio API mode does not take
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
	}

	local tree: any = AudioApi.template()
	local player: any = AudioApi.playable(tree)

	for property: string, mapped: string in Constants.AUDIO_API_PROPERTIES do
		local value: any = samples[property]
		if value == nil then
			return false, `the case has no sample for {property}`
		elseif AudioApi.apply(tree, property, value) ~= true or player[mapped] ~= value then
			return false, `apply did not write {property} = {value} to the player's {mapped}`
		end
	end

	local volume: number = player.Volume
	if AudioApi.apply(tree, "Volume", "loud") ~= false or player.Volume ~= volume then
		return false, "apply wrote a string to Volume, or did not return false"
	elseif AudioApi.apply(tree, "Name", "Shot") ~= false or player.Name ~= "AudioPlayer" then
		return false, "apply wrote a property Audio API mode does not take"
	elseif AudioApi.apply(tree, "RollOffMode", "Linear") ~= false then
		return false, "apply took a RollOffMode that is no Enum.RollOffMode item"
	elseif #env.warnings ~= 3 or not env.warnings[1]:find("Volume") or not env.warnings[2]:find("Name") then
		return false, `apply did not warn once per refused write, naming it: {table.concat(env.warnings, " | ")}`
	end

	return true, nil
end
