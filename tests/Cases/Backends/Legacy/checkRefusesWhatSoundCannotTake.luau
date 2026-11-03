--[[
    Legacy.check takes any property a Sound can write with a value of its
    type, and refuses, naming it, what Echo sets itself, what a Sound lacks
    or cannot write, and a value of another type
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")

	local taken: { { any } } = {
		{ "SoundId", "rbxassetid://1" },
		{ "Volume", 0.25 },
		{ "Looped", true },
		{ "PlaybackRegion", roblox.NumberRange.new(1, 2) },
		{ "RollOffMode", roblox.Enum.RollOffMode.Linear },
		{ "RollOffMaxDistance", 300 },
		{ "PlayOnRemove", false },
		{ "Volume", nil }, -- A state whose default is empty
	}

	for _, pair: { any } in taken do
		local reason: string? = Legacy.check(pair[1], pair[2])
		if reason then
			return false, `check refused {pair[1]} = {pair[2]}: {reason}`
		end
	end

	local refused: { { any } } = {
		{ "Parent", env.game.Workspace }, -- Echo's own
		{ "Playing", true },
		{ "SoundGroup", env.Instance.new("SoundGroup") }, -- The bus's
		{ "Loudness", 1 }, -- No such property
		{ "IsPlaying", true }, -- Read only
		{ "TimeLength", nil },
		{ "Play", nil }, -- A method
		{ "Volume", "loud" },
		{ "Looped", 1 },
		{ "RollOffMode", roblox.Enum.Material.Plastic },
	}

	for _, pair: { any } in refused do
		local reason: string? = Legacy.check(pair[1], pair[2])
		if not reason or not reason:find(pair[1]) then
			return false, `check took {pair[1]} = {pair[2]}, or refused it without naming it: {reason}`
		end
	end

	return true, nil
end
