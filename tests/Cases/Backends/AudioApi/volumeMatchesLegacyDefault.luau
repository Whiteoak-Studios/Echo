--[[
    An element with no Volume sounds the same in both Modes: a fresh Audio
    API voice and a cleared one read a legacy Sound's default Volume, as a
    fresh and a cleared legacy voice do
--]]

--!strict
local Environment = require("../../../Environment")

local LOUDER: number = 0.9

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")
	local AudioApi: any = env.require("Backends/AudioApi")
	local default: number = env.Instance.new("Sound").Volume

	local legacyTree: any = Legacy.template():Clone()
	local legacySound: any = Legacy.playable(legacyTree)
	local tree: any = AudioApi.template():Clone()
	local player: any = AudioApi.playable(tree)

	if legacySound.Volume ~= default then
		return false, `a fresh legacy voice reads Volume {legacySound.Volume}, not a legacy Sound's {default}`
	elseif player.Volume ~= default then
		return false, `a fresh Audio API voice reads Volume {player.Volume}, not a legacy Sound's {default}`
	end

	Legacy.apply(legacyTree, "Volume", LOUDER)
	AudioApi.apply(tree, "Volume", LOUDER)
	Legacy.clear(legacyTree)
	AudioApi.clear(tree)

	if legacySound.Volume ~= default or player.Volume ~= default then
		return false,
			`cleared voices read Volume {legacySound.Volume} and {player.Volume}, not a legacy Sound's {default}`
	end

	return true, nil
end
