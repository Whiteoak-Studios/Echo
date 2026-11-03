--[[
    The Audio API template is an unparented, archivable Attachment holding a
    player, an emitter on a legacy Sound's curve and a Wire out of the
    player to nothing, and a clone's Wire starts at the clone's own player
--]]

--!strict
local Environment = require("../../../Environment")

local LEGACY_MIN: number = 10
local LEGACY_MAX: number = 10000

-- Full at a legacy Sound's min, silent at its max, with the point count every curve has
local function onLegacyCurve(emitter: any, points: number): boolean
	local curve: { [number]: number } = emitter:GetDistanceAttenuation()
	local count: number = 0
	for _ in curve do
		count += 1
	end

	return count == points and curve[LEGACY_MIN] == 1 and curve[LEGACY_MAX] == 0
end

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")
	local Constants: any = env.require("Constants")

	local template: any = AudioApi.template()
	if not template:IsA("Attachment") or template.Parent ~= nil or not template.Archivable then
		return false, "the template is not an unparented, archivable Attachment"
	elseif #template:GetChildren() ~= 3 then
		return false, `the template holds {#template:GetChildren()} children, not a player, an emitter and a Wire`
	end

	local player: any = template:FindFirstChild("AudioPlayer")
	local emitter: any = template:FindFirstChild("AudioEmitter")
	local wire: any = template:FindFirstChild("Wire")
	if not player or not emitter or not wire or wire.SourceInstance ~= player or wire.TargetInstance ~= nil then
		return false, "the template's Wire does not run out of its player to nothing"
	elseif not onLegacyCurve(emitter, Constants.CURVE_POINTS) then
		return false, "the template's emitter is not on a legacy Sound's curve from 10 to 10000 studs"
	end

	local copy: any = template:Clone()
	local copyPlayer: any = AudioApi.playable(copy)
	if copyPlayer == player or copyPlayer.Parent ~= copy or copy.Wire.SourceInstance ~= copyPlayer then
		return false, "a clone's Wire does not start at the clone's own player"
	elseif not onLegacyCurve(copy.AudioEmitter, Constants.CURVE_POINTS) then
		return false, "a clone's emitter lost the template's curve"
	end

	local passed: boolean, message: any = pcall(AudioApi.playable, env.Instance.new("Attachment"))
	if passed or not tostring(message):find("AudioPlayer") then
		return false, `a bare Attachment was taken as a voice: {message}`
	end

	return true, nil
end
