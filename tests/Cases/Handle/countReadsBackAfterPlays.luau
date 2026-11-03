--[[
    The cache's in-use count and pool size read back right after each play,
    each give-back and each growth step the plays bring on
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

type Count = { inUse: number, size: number }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")
	local Cache: any = env.require("Cache")

	Root.configure({ mode = "Legacy", cache = { Legacy = SIZE } })

	local ref: any = Element.ref(nil)
	Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = ref }))

	local handle: any = ref.current

	local function expect(inUse: number, size: number, when: string): (boolean, string | nil)
		local count: Count = Cache.count("Legacy")
		if count.inUse ~= inUse or count.size ~= size then
			return false, `{when} the cache read {count.inUse} in use of {count.size}, not {inUse} of {size}`
		end

		return true, nil
	end

	-- The pool grows by growBy once its free voices fall to initial - growAt
	local sizes: { number } = { 4, 6, 6, 8, 8, 8 }
	local voices: { any } = {}

	for play: number, size: number in sizes do
		table.insert(voices, handle:play())

		local passed: boolean, reason: string? = expect(play, size, `after play {play}`)
		if not passed then
			return false, reason
		end
	end

	handle:stop(voices[1])
	handle:stop(voices[2])

	local passed: boolean, reason: string? = expect(#sizes - 2, SIZE.ceiling, "after two give-backs")
	if not passed then
		return false, reason
	end

	handle:stop()

	return expect(0, SIZE.ceiling, "after every voice went back")
end
