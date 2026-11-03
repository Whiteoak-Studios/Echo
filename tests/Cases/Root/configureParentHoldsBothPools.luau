--[[
    Configure's parent reaches the cache: a folder given as config.parent
    holds every voice of both pools and Terrain none, and with no parent
    Terrain holds them all
--]]

--!strict
local Environment = require("../../Environment")

local LEGACY: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local AUDIO_API: { [string]: number } = { initial = 6, growAt = 3, growBy = 2, ceiling = 10 }

return function (): (boolean, string | nil)
	local voices: number = LEGACY.initial + AUDIO_API.initial

	-- 1) A folder under Workspace holds both pools' voices
	local env: Environment.Environment = Environment.new()
	local terrain: any = env.game.Workspace.Terrain

	local folder: any = env.Instance.new("Folder")
	folder.Parent = env.game.Workspace

	env.require("Root").configure({
		mode = "Legacy",
		cache = { Legacy = LEGACY, AudioApi = AUDIO_API },
		parent = folder,
	})

	if #folder:GetChildren() ~= voices then
		return false, `config.parent holds {#folder:GetChildren()} voices, not both pools' {voices}`
	elseif #terrain:GetChildren() ~= 0 then
		return false, `Terrain holds {#terrain:GetChildren()} voices of pools given a parent`
	end

	-- 2) With no parent, Terrain holds them
	local bare: Environment.Environment = Environment.new()
	local bareTerrain: any = bare.game.Workspace.Terrain

	bare.require("Root").configure({ mode = "Legacy", cache = { Legacy = LEGACY, AudioApi = AUDIO_API } })

	if #bareTerrain:GetChildren() ~= voices then
		return false, `with no parent Terrain holds {#bareTerrain:GetChildren()} voices, not both pools' {voices}`
	end

	return true, nil
end
