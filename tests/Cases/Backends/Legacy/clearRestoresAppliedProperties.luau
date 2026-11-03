--[[
    Legacy.clear stops the voice and puts back every property a play wrote
    to a new Sound's value, with no asset, attributes or SoundGroup, so the
    next element inherits nothing, and a check never leaks into it
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")
	Legacy.setup()

	local fresh: any = env.Instance.new("Sound")
	local written: { [string]: any } = {
		SoundId = "rbxassetid://1",
		Volume = 0.25,
		PlaybackSpeed = 2,
		Looped = true,
		TimePosition = 1.5,
		LoopRegion = roblox.NumberRange.new(1, 2),
		RollOffMode = roblox.Enum.RollOffMode.Linear,
		RollOffMaxDistance = 300,
		PlayOnRemove = true,
	}

	-- A check writes its value to a probe, which must hold no value once it returns
	Legacy.check("Volume", 0.9)
	Legacy.check("SoundId", "rbxassetid://2")

	local tree: any = Legacy.template()
	local sound: any = Legacy.playable(tree)
	for property: string, value: any in written do
		Legacy.apply(tree, property, value)
	end

	sound:SetAttribute("Artist", "Mike")
	Legacy.route(tree, { group = env.Instance.new("SoundGroup") }, false)
	Legacy.play(tree)
	Legacy.clear(tree)

	for property: string in written do
		if sound[property] ~= fresh[property] then
			return false, `clear left {property} at {sound[property]}, not a new Sound's {fresh[property]}`
		end
	end

	if sound.Playing or sound.SoundId ~= "" or next(sound:GetAttributes()) ~= nil then
		return false, "clear left the voice playing, or kept its asset or attributes"
	elseif sound.Parent ~= tree or sound.SoundGroup ~= nil then
		return false, "clear left the Sound routed"
	end

	return true, nil
end
