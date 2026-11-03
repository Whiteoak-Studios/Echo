--[[
    Configure sets up each Mode its cache sizes and fills that Mode's pool,
    makes one folder under SoundService for both, keeps the default Mode,
    and errors on a second call, leaving the pools as they were
--]]

--!strict
local Environment = require("../../Environment")

local LEGACY: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local AUDIO_API: { [string]: number } = { initial = 6, growAt = 3, growBy = 2, ceiling = 10 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Cache: any = env.require("Cache")
	local soundService: any = env.game:GetService("SoundService")

	Root.configure({ mode = "AudioApi", cache = { Legacy = LEGACY, AudioApi = AUDIO_API } })

	local legacy: any = Cache.count("Legacy")
	local audioApi: any = Cache.count("AudioApi")

	if legacy.size ~= LEGACY.initial or audioApi.size ~= AUDIO_API.initial then
		return false, `the pools hold {legacy.size} and {audioApi.size} voices, not their initial sizes`
	elseif legacy.inUse ~= 0 or audioApi.inUse ~= 0 then
		return false, "a pool had voices in use straight after configure"
	end

	local folders: number = 0
	for _, child: any in soundService:GetChildren() do
		if child.Name == "Echo" then
			folders += 1
		end
	end

	if folders ~= 1 then
		return false, `configuring both Modes made {folders} folders under SoundService, not one`
	elseif Root.defaultMode() ~= "AudioApi" then
		return false, `the default Mode reads {Root.defaultMode()}, not the one configured`
	end

	local again: boolean, message: any = pcall(Root.configure, { mode = "Legacy", cache = { Legacy = LEGACY } })
	if again or string.find(tostring(message), "runs once", 1, true) == nil then
		return false, `a second configure did not error as running once: {message}`
	elseif Cache.count("Legacy").size ~= LEGACY.initial or Root.defaultMode() ~= "AudioApi" then
		return false, "a second configure changed a pool or the default Mode"
	end

	return true, nil
end
