--[[
    Legacy.setup makes one Folder named Echo under SoundService however
    often it runs, and takes a folder of that name already there
--]]

--!strict
local Environment = require("../../../Environment")

local FOLDER_NAME: string = "Echo"

local function folders(soundService: any): { any }
	local found: { any } = {}
	for _, child: any in soundService:GetChildren() do
		if child.Name == FOLDER_NAME then
			table.insert(found, child)
		end
	end

	return found
end

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")
	local soundService: any = env.game:GetService("SoundService")

	Legacy.setup()
	Legacy.setup()

	local made: { any } = folders(soundService)
	if #made ~= 1 or not made[1]:IsA("Folder") then
		return false, `setup run twice left {#made} instances named {FOLDER_NAME}, not one Folder`
	end

	local other: Environment.Environment = Environment.new()
	local OtherLegacy: any = other.require("Backends/Legacy")
	local otherService: any = other.game:GetService("SoundService")
	local existing: any = other.Instance.new("Folder")
	existing.Name = FOLDER_NAME
	existing.Parent = otherService

	OtherLegacy.setup()

	local tree: any = OtherLegacy.template()
	OtherLegacy.route(tree, nil, false)
	if #folders(otherService) ~= 1 or OtherLegacy.playable(tree).Parent ~= existing then
		return false, "setup made a second folder beside the one already there"
	end

	return true, nil
end
