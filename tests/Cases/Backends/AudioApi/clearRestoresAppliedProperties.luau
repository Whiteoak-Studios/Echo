--[[
    AudioApi.clear stops the voice and puts back every property a play
    wrote, and the emitter's curve, to a legacy Sound's default, with no
    asset or attributes, so the next element inherits none
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

local LEGACY_MIN: number = 10
local LEGACY_MAX: number = 10000

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")
	local Constants: any = env.require("Constants")
	AudioApi.setup()

	local fresh: any = env.Instance.new("Sound")
	local written: { [string]: any } = {
		SoundId = "rbxassetid://1",
		Volume = 0.25,
		PlaybackSpeed = 2,
		Looped = true,
		TimePosition = 1.5,
		PlaybackRegion = roblox.NumberRange.new(1, 2),
		LoopRegion = roblox.NumberRange.new(1, 2),
		RollOffMode = roblox.Enum.RollOffMode.Linear,
		RollOffMinDistance = 28,
		RollOffMaxDistance = 300,
	}

	-- A check writes its value to a probe, which must hold no value once it returns
	AudioApi.check("Volume", 0.9)

	local tree: any = AudioApi.template()
	local player: any = AudioApi.playable(tree)
	for property: string, value: any in written do
		AudioApi.apply(tree, property, value)
	end

	player:SetAttribute("Artist", "Mike")
	AudioApi.route(tree, nil, true)
	AudioApi.play(tree)
	AudioApi.clear(tree)

	for property: string, mapped: string in Constants.AUDIO_API_PROPERTIES do
		if player[mapped] ~= fresh[property] then
			return false, `clear left {property} at {player[mapped]}, not a legacy Sound's {fresh[property]}`
		end
	end

	local curve: { [number]: number } = tree.AudioEmitter:GetDistanceAttenuation()
	if curve[LEGACY_MIN] ~= 1 or curve[LEGACY_MAX] ~= 0 or curve[28] ~= nil then
		return false, "clear did not put the emitter back on a legacy Sound's curve"
	elseif player.IsPlaying or player.Asset ~= "" or next(player:GetAttributes()) ~= nil then
		return false, "clear left the voice playing, or kept its asset or attributes"
	end

	return true, nil
end
