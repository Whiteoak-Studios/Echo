--[[
    A legacy effect is added under the Sound once per class and key, enabled
    and set on every use, and disabled with its defaults back on clear; a
    bad value warns and leaves the rest set
--]]

--!strict
local Environment = require("../../../Environment")

local KEY: string = "Muffle"

local function effectsOf(sound: any): { any }
	local found: { any } = {}
	for _, child: any in sound:GetChildren() do
		if child:IsA("SoundEffect") then
			table.insert(found, child)
		end
	end

	return found
end

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")
	local defaults: any = env.Instance.new("EqualizerSoundEffect")

	local tree: any = Legacy.template()
	local sound: any = Legacy.playable(tree)

	Legacy.effect(tree, "EqualizerSoundEffect", KEY, { HighGain = -6 })
	Legacy.effect(tree, "EqualizerSoundEffect", KEY, { LowGain = -3, Priority = 2 })

	local added: { any } = effectsOf(sound)
	local equalizer: any = added[1]
	if #added ~= 1 or equalizer.Name ~= KEY or not equalizer:IsA("EqualizerSoundEffect") then
		return false, `two uses of one class and key left {#added} effects, not one named {KEY}`
	elseif not equalizer.Enabled or equalizer.HighGain ~= -6 or equalizer.LowGain ~= -3 or equalizer.Priority ~= 2 then
		return false, "the effect is not enabled with every property it was given"
	end

	Legacy.effect(tree, "DistortionSoundEffect", KEY, { Level = 0.75 })
	if #effectsOf(sound) ~= 2 then
		return false, "a second class under the same key did not get an effect of its own"
	end

	Legacy.clear(tree)
	for _, effect: any in effectsOf(sound) do
		if effect.Enabled then
			return false, `clear left {effect.ClassName} enabled`
		end
	end

	if equalizer.HighGain ~= defaults.HighGain or equalizer.LowGain ~= defaults.LowGain or equalizer.Priority ~= 0 then
		return false, "clear did not put the effect's properties back to its defaults"
	elseif #effectsOf(sound) ~= 2 then
		return false, "clear took an effect off its Sound"
	end

	Legacy.effect(tree, "EqualizerSoundEffect", KEY, { HighGain = "loud", MidGain = -1 })
	if #effectsOf(sound) ~= 2 or not equalizer.Enabled or equalizer.MidGain ~= -1 then
		return false, "a use after clear made a new effect, or a bad value stopped the rest being set"
	elseif #env.warnings ~= 1 or not env.warnings[1]:find("HighGain") then
		return false, `a bad effect value did not warn once, naming it: {table.concat(env.warnings, " | ")}`
	end

	return true, nil
end
