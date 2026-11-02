--[[
    A fake Sound plays, pauses, resumes and stops as the engine's does, and
    a case finishes, loops and loads it: Ended fires once per finish and
    never on Stop, DidLoop counts from the last Play, Loaded fires once
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local ID: string = "rbxassetid://1"
local OTHER_ID: string = "rbxassetid://2"
local POSITION: number = 1.5
local LENGTH: number = 3

local EFFECTS: { string } = {
	"EqualizerSoundEffect",
	"DistortionSoundEffect",
	"ReverbSoundEffect",
	"ChorusSoundEffect",
	"CompressorSoundEffect",
	"EchoSoundEffect",
	"FlangeSoundEffect",
	"PitchShiftSoundEffect",
	"TremoloSoundEffect",
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local new: (className: string) -> any = env.Instance.new
	local sound: any = new("Sound")
	sound.SoundId = ID
	sound.Parent = env.game:GetService("SoundService")

	local ended: { string } = {}
	sound.Ended:Connect(function (id: string)
		table.insert(ended, id)
	end)

	local loops: { number } = {}
	sound.DidLoop:Connect(function (_: string, count: number)
		table.insert(loops, count)
	end)

	local loaded: string? = nil
	sound.Loaded:Connect(function (id: string)
		loaded = id
	end)

	if sound.Playing or sound.IsPlaying or not sound.IsPaused then
		return false, "a new Sound is playing"
	end

	sound.TimePosition = POSITION
	sound:Play()
	if not sound.Playing or not sound.IsPlaying or sound.IsPaused or sound.TimePosition ~= POSITION then
		return false, "Play did not play from the TimePosition the script set"
	end

	sound:Pause()
	if sound.Playing or sound.TimePosition ~= POSITION then
		return false, "Pause did not stop the sound where it was"
	end

	sound:Resume()
	sound:Stop()
	if sound.Playing or sound.TimePosition ~= 0 or #ended ~= 0 then
		return false, "Stop did not rewind the sound, or fired Ended"
	end

	sound:Play()
	env.finish(sound)
	if #ended ~= 1 or ended[1] ~= ID or sound.Playing then
		return false, "finishing a sound did not end it with one Ended carrying its SoundId"
	end

	if pcall(env.finish, sound) then
		return false, "env.finish ended a sound that was not playing"
	end

	sound.Looped = true
	sound:Play()
	if pcall(env.finish, sound) then
		return false, "env.finish ended a looping sound"
	end

	env.loop(sound)
	env.loop(sound)
	sound:Play()
	env.loop(sound)
	if loops[1] ~= 1 or loops[2] ~= 2 or loops[3] ~= 1 or #ended ~= 1 then
		return false, `DidLoop counted {table.concat(loops, ", ")}, not 1, 2, then 1 after a new Play`
	end

	sound.Looped = false
	if pcall(env.loop, sound) then
		return false, "env.loop looped a sound that does not loop"
	end

	env.load(sound)
	if loaded ~= ID or not sound.IsLoaded or pcall(env.load, sound) then
		return false, "env.load did not load the sound once"
	end

	sound.SoundId = OTHER_ID
	if sound.IsLoaded then
		return false, "a new SoundId kept the old asset's IsLoaded"
	end

	env.set(sound, "TimeLength", LENGTH)
	if sound.TimeLength ~= LENGTH or pcall(env.set, sound, "Length", LENGTH) then
		return false, "env.set did not write a read-only property, or wrote one Sound lacks"
	end

	local group: any = new("SoundGroup")
	sound.SoundGroup = group
	if sound.SoundGroup ~= group or pcall(env.finish, group) then
		return false, "a Sound did not join its SoundGroup, or env.finish took a SoundGroup"
	end

	for _, className: string in EFFECTS do
		local effect: any = new(className)
		effect.Parent = sound
		if not effect:IsA("SoundEffect") or effect.Enabled ~= true or effect.Priority ~= 0 then
			return false, `a new {className} is not an enabled SoundEffect of priority 0`
		end
	end

	if sound.EqualizerSoundEffect.LowGain ~= -20 then
		return false, "an effect's property does not start at the engine's default"
	end

	return true, nil
end
