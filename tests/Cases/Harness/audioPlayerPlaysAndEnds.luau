--[[
    The fake Audio API: an AudioPlayer that never rewinds on Play and a case
    finishes, loops and readies, an emitter keeping its distance curve, a
    Wire, a fader, an output and the nine effects
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local ID: string = "rbxassetid://1"
local OTHER_ID: string = "rbxassetid://2"
local POSITION: number = 1.5
local MAX_POINTS: number = 400

local EFFECTS: { string } = {
	"AudioEqualizer",
	"AudioDistortion",
	"AudioReverb",
	"AudioChorus",
	"AudioCompressor",
	"AudioEcho",
	"AudioFlanger",
	"AudioPitchShifter",
	"AudioTremolo",
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local new: (className: string) -> any = env.Instance.new
	local player: any = new("AudioPlayer")
	player.Asset = ID

	local ended: number = 0
	player.Ended:Connect(function ()
		ended += 1
	end)

	local looped: number = 0
	player.Looped:Connect(function ()
		looped += 1
	end)

	local readied: number = 0
	player:GetPropertyChangedSignal("IsReady"):Connect(function ()
		readied += 1
	end)

	player.TimePosition = POSITION
	player:Play()
	if not player.IsPlaying or player.TimePosition ~= POSITION then
		return false, "AudioPlayer:Play did not play from where it was"
	end

	player:Stop()
	if player.IsPlaying or player.TimePosition ~= POSITION or ended ~= 0 then
		return false, "AudioPlayer:Stop did not keep its TimePosition, or fired Ended"
	end

	if pcall(function ()
		player.IsPlaying = true
	end) then
		return false, "IsPlaying was written"
	end

	player:Play()
	env.finish(player)
	if ended ~= 1 or player.IsPlaying then
		return false, "finishing a player did not end it with one Ended"
	end

	player.Looping = true
	player:Play()
	env.loop(player)
	if looped ~= 1 or pcall(env.finish, player) then
		return false, "env.loop did not fire Looped, or env.finish ended a looping player"
	end

	env.load(player)
	if not player.IsReady or readied ~= 1 or pcall(env.load, player) then
		return false, "env.load did not ready the player once"
	end

	player.Asset = OTHER_ID
	if player.IsReady then
		return false, "a new Asset kept the old asset's IsReady"
	end

	local emitter: any = new("AudioEmitter")
	local curve: { [number]: number } = { [0] = 1, [10] = 0.5, [20] = 0 }
	emitter:SetDistanceAttenuation(curve)
	curve[10] = 0.25
	local read: { [number]: number } = emitter:GetDistanceAttenuation()
	if read[10] ~= 0.5 or read[20] ~= 0 then
		return false, "GetDistanceAttenuation did not give a copy of the curve it was set"
	end

	local tooMany: { [number]: number } = {}
	for distance: number = 0, MAX_POINTS do
		tooMany[distance] = 1
	end

	if
		pcall(emitter.SetDistanceAttenuation, emitter, tooMany)
		or pcall(emitter.SetDistanceAttenuation, emitter, { [5] = 2 })
	then
		return false, "SetDistanceAttenuation took more than 400 points or a volume above 1"
	end

	emitter.AudioInteractionGroup = "Effects"

	local wire: any = new("Wire")
	if wire.Connected then
		return false, "a Wire with no ends reads as connected"
	end

	wire.SourceInstance = player
	wire.TargetInstance = emitter
	if not wire.Connected then
		return false, "a Wire with both ends reads as not connected"
	end

	local fader: any = new("AudioFader")
	if fader.Volume ~= 1 or fader.Bypass or new("AudioDeviceOutput").ClassName ~= "AudioDeviceOutput" then
		return false, "AudioFader or AudioDeviceOutput does not start as the engine's"
	end

	for _, className: string in EFFECTS do
		local effect: any = new(className)
		if effect.Bypass ~= false then
			return false, `a new {className} is bypassed`
		end

		effect.Bypass = true
	end

	if new("AudioEqualizer").MidRange.Min ~= 400 then
		return false, "an Audio API effect's property does not start at the engine's default"
	end

	return true, nil
end
