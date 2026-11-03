--[[
    A 2D legacy voice's Sound plays from SoundService's Echo folder and a
    world voice's under its Attachment at its position, each in its bus's
    SoundGroup or none, and a 2D route before setup errors
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

local POSITION: any = roblox.Vector3.new(4, 5, 6)
local TOLERANCE: number = 1e-6

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")
	Legacy.setup()

	local folder: any = env.game:GetService("SoundService"):FindFirstChild("Echo")
	local group: any = env.Instance.new("SoundGroup")
	local tree: any = Legacy.template()
	tree.Parent = env.game.Workspace.Terrain
	local sound: any = Legacy.playable(tree)

	Legacy.route(tree, nil, false)
	if sound.Parent ~= folder or sound.SoundGroup ~= nil then
		return false, "a 2D voice with no bus is not in SoundService's Echo folder in no SoundGroup"
	end

	Legacy.route(tree, { group = group }, false)
	if sound.Parent ~= folder or sound.SoundGroup ~= group then
		return false, "a 2D voice on a bus did not join the bus's SoundGroup"
	end

	Legacy.route(tree, { group = group }, true)
	Legacy.place(tree, POSITION)
	if sound.Parent ~= tree or sound.SoundGroup ~= group then
		return false, "a world voice on a bus is not under its Attachment in the bus's SoundGroup"
	elseif (tree.WorldPosition - POSITION).Magnitude > TOLERANCE then
		return false, "place did not move the voice's Attachment"
	end

	Legacy.route(tree, {}, true)
	if sound.SoundGroup ~= nil then
		return false, "a bus with no group kept the last SoundGroup"
	end

	Legacy.route(tree, { group = group }, false)
	Legacy.clear(tree)
	if sound.Parent ~= tree or sound.SoundGroup ~= nil then
		return false, "clear did not move the Sound back under its Attachment in no SoundGroup"
	end

	local other: Environment.Environment = Environment.new()
	local Unset: any = other.require("Backends/Legacy")
	local unrouted: any = Unset.template()
	local passed: boolean, message: any = pcall(Unset.route, unrouted, nil, false)
	if passed or not tostring(message):find("setup") or Unset.playable(unrouted).Parent ~= unrouted then
		return false, `a 2D route before setup did not error, or moved the Sound: {message}`
	end

	return true, nil
end
