--[[
    AudioApi.setup, run after the legacy backend's and again, leaves one
    Echo folder under SoundService holding one AudioDeviceOutput, and makes
    no AudioListener
--]]

--!strict
local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")
	local AudioApi: any = env.require("Backends/AudioApi")
	local soundService: any = env.game:GetService("SoundService")

	Legacy.setup()
	AudioApi.setup()
	AudioApi.setup()

	local children: { any } = soundService:GetChildren()
	local folder: any = children[1]
	if #children ~= 1 or folder.Name ~= "Echo" or not folder:IsA("Folder") then
		return false, `SoundService holds {#children} children after both setups, not one Echo folder`
	end

	local inside: { any } = folder:GetChildren()
	if #inside ~= 1 or not inside[1]:IsA("AudioDeviceOutput") then
		return false, `the Echo folder holds {#inside} children, not one AudioDeviceOutput`
	end

	local tree: any = AudioApi.template()
	AudioApi.route(tree, nil, false)
	if tree.Wire.TargetInstance ~= inside[1] then
		return false, "a 2D voice with no bus does not play to the output setup made"
	end

	for _, descendant: any in env.game:GetDescendants() do
		if descendant.ClassName == "AudioListener" then
			return false, "setup made an AudioListener"
		end
	end

	return true, nil
end
