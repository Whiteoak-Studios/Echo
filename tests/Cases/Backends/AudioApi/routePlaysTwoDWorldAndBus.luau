--[[
    An Audio API world voice's Wire ends at its emitter in its bus's
    interaction group, a 2D voice's at its bus's fader or Echo's output,
    clear leaves it ending nowhere, and a route before setup errors
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

local GROUP: string = "Effects"
local POSITION: any = roblox.Vector3.new(4, 5, 6)
local TOLERANCE: number = 1e-6

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")
	AudioApi.setup()

	local output: any = env.game:GetService("SoundService").Echo.AudioDeviceOutput
	local fader: any = env.Instance.new("AudioFader")
	local bus: { [string]: any } = { fader = fader, interactionGroup = GROUP }

	local tree: any = AudioApi.template()
	tree.Parent = env.game.Workspace.Terrain
	local wire: any = tree.Wire
	local emitter: any = tree.AudioEmitter

	AudioApi.route(tree, bus, true)
	AudioApi.place(tree, POSITION)
	if wire.TargetInstance ~= emitter or emitter.AudioInteractionGroup ~= GROUP then
		return false, "a world voice on a bus does not end at its emitter in the bus's interaction group"
	elseif (tree.WorldPosition - POSITION).Magnitude > TOLERANCE then
		return false, "place did not move the voice's Attachment"
	end

	AudioApi.route(tree, nil, true)
	if wire.TargetInstance ~= emitter or emitter.AudioInteractionGroup ~= "" then
		return false, "a world voice with no bus kept the last interaction group"
	end

	AudioApi.route(tree, bus, false)
	if wire.TargetInstance ~= fader or emitter.AudioInteractionGroup ~= "" then
		return false, "a 2D voice on a bus does not end at the bus's fader"
	end

	AudioApi.route(tree, { interactionGroup = GROUP }, false)
	if wire.TargetInstance ~= output then
		return false, "a 2D voice on a bus with no fader does not end at Echo's output"
	end

	AudioApi.route(tree, bus, true)
	AudioApi.clear(tree)
	if
		wire.TargetInstance ~= nil
		or wire.SourceInstance ~= AudioApi.playable(tree)
		or emitter.AudioInteractionGroup ~= ""
	then
		return false, "clear did not leave the player's Wire ending nowhere in no interaction group"
	end

	local other: Environment.Environment = Environment.new()
	local Unset: any = other.require("Backends/AudioApi")
	local passed: boolean, message: any = pcall(Unset.route, Unset.template(), nil, true)
	if passed or not tostring(message):find("setup") then
		return false, `a route before setup did not error: {message}`
	end

	return true, nil
end
