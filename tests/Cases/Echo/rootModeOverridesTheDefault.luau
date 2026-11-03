--[[
    A root's Mode overrides the default: with Legacy the default, a root
    given AudioApi plays from the Audio API pool and one given none from the
    Legacy pool. A Mode config.cache does not size errors, naming it, and a
    root called with a dot errors and mounts nothing
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local LEGACY_SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local AUDIO_API_SIZE: { [string]: number } = { initial = 6, growAt = 2, growBy = 2, ceiling = 8 }
local UNSIZED: { string } = { "AudioApi", "Audio" }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Echo: any = env.require()

	Echo.configure({ mode = "Legacy", cache = { Legacy = LEGACY_SIZE, AudioApi = AUDIO_API_SIZE } })

	local audioRef: any = Echo.createRef()
	local defaultRef: any = Echo.useRef(nil)
	local audioRoot: any = Echo:root(nil, Echo.createElement("Sound", { SoundId = ID, Handle = audioRef }), "AudioApi")
	Echo:root(nil, Echo.createElement("Sound", { SoundId = ID, Handle = defaultRef }))

	local player: any = audioRef.current:play().instance
	if not player:IsA("AudioPlayer") or player.Asset ~= ID then
		return false, "the root given AudioApi did not play on an AudioPlayer with its SoundId"
	elseif Echo.getCache("AudioApi").inUse ~= 1 or Echo.getCache().inUse ~= 0 then
		return false, "the root given AudioApi did not take its voice from the Audio API pool alone"
	end

	local sound: any = defaultRef.current:play().instance
	if not sound:IsA("Sound") or Echo.getCache().inUse ~= 1 or Echo.getCache("Legacy").inUse ~= 1 then
		return false, "the root given no Mode did not play from the default Legacy pool"
	end

	audioRoot:destroy()
	if Echo.getCache("AudioApi").inUse ~= 0 or audioRef.current ~= nil then
		return false, "destroying the Audio API root did not give its voice back or clear its ref"
	end

	local single: Environment.Environment = Environment.new()
	local SingleEcho: any = single.require()
	SingleEcho.configure({ mode = "Legacy", cache = { Legacy = LEGACY_SIZE } })

	local element: any = SingleEcho.createElement("Sound", { SoundId = ID })
	for _, mode: string in UNSIZED do
		local mounted: boolean, message: any = pcall(SingleEcho.root, SingleEcho, nil, element, mode)
		if mounted or string.find(tostring(message), mode, 1, true) == nil then
			return false, `a root in {mode}, which config.cache does not size, did not error naming it: {message}`
		end
	end

	local dotted: boolean = pcall(SingleEcho.root, nil, element)
	if dotted or #SingleEcho.getAll() ~= 0 then
		return false, "root called with a dot, so with no Echo before its target, mounted the element"
	end

	return true, nil
end
