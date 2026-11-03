--[[
    One element description plays in both Modes: a root with no Mode plays
    it in the default one, and a root's own Mode overrides the default
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local VOLUME: number = 0.25
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")
	local Cache: any = env.require("Cache")

	Root.configure({ mode = "Legacy", cache = { Legacy = SIZE, AudioApi = SIZE } })

	local ref: any = Element.ref(nil)
	local element: any = Element.create("Sound", { SoundId = ID, Volume = VOLUME, Handle = ref })

	Root.mount(nil, element)
	local legacy: any = ref.current
	Root.mount(nil, element, "AudioApi")
	local audioApi: any = ref.current

	local sound: any = legacy:play().instance
	local player: any = audioApi:play().instance

	if not sound:IsA("Sound") or sound.SoundId ~= ID or sound.Volume ~= VOLUME then
		return false, "the default Mode's root did not play the element on a legacy Sound with its properties"
	elseif not player:IsA("AudioPlayer") or player.Asset ~= ID or player.Volume ~= VOLUME then
		return false, "the Audio API root did not play the element on an AudioPlayer with its properties"
	elseif Cache.count("Legacy").inUse ~= 1 or Cache.count("AudioApi").inUse ~= 1 then
		return false, "each root's voice did not come from its own Mode's pool"
	end

	legacy:stop()
	audioApi:stop()

	if Cache.count("Legacy").inUse ~= 0 or Cache.count("AudioApi").inUse ~= 0 then
		return false, "stop did not give each Mode's voice back to its pool"
	end

	return true, nil
end
