--[[
    getCache with no Mode reads the default Mode's pool, the Audio API one
    when the game makes it the default, and with a Mode reads that Mode's.
    A Mode config.cache does not size errors, naming it
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

	Echo.configure({ mode = "AudioApi", cache = { Legacy = LEGACY_SIZE, AudioApi = AUDIO_API_SIZE } })

	if Echo.getCache().size ~= AUDIO_API_SIZE.initial or Echo.getCache("Legacy").size ~= LEGACY_SIZE.initial then
		local size: number = AUDIO_API_SIZE.initial
		return false, `getCache read {Echo.getCache().size} with no Mode, where the default Audio API pool holds {size}`
	end

	local ref: any = Echo.createRef()
	Echo:root(nil, Echo.createElement("Sound", { SoundId = ID, Handle = ref }))
	ref.current:play()

	local default: any = Echo.getCache()
	if default.inUse ~= 1 or Echo.getCache("AudioApi").inUse ~= 1 or Echo.getCache("Legacy").inUse ~= 0 then
		return false, `a play in the default Mode read {default.inUse} in use with no Mode, where it reads 1`
	end

	local single: Environment.Environment = Environment.new()
	local SingleEcho: any = single.require()
	SingleEcho.configure({ mode = "Legacy", cache = { Legacy = LEGACY_SIZE } })

	for _, mode: string in UNSIZED do
		local read: boolean, message: any = pcall(SingleEcho.getCache, mode)
		if read or string.find(tostring(message), mode, 1, true) == nil then
			return false, `getCache for {mode}, which config.cache does not size, did not error naming it: {message}`
		end
	end

	return true, nil
end
