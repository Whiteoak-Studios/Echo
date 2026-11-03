--[[
    A root mounted before configure, and the cache read with no Mode before
    it, each error saying configure must run first, and the refused root
    leaves nothing mounted; once configure runs, the same element mounts
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local BEFORE: string = "configure must run before the first root"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Echo: any = env.require()

	local ref: any = Echo.createRef()
	local element: any = Echo.createElement("Sound", { SoundId = ID, Handle = ref })

	local mounted: boolean, message: any = pcall(Echo.root, Echo, nil, element)
	if mounted or string.find(tostring(message), BEFORE, 1, true) == nil then
		return false, `a root before configure did not error saying configure runs first: {message}`
	elseif ref.current ~= nil or #Echo.getAll() ~= 0 then
		return false, "a root refused before configure still handed out a handle or reads as mounted"
	end

	local read: boolean, readMessage: any = pcall(Echo.getCache)
	if read or string.find(tostring(readMessage), BEFORE, 1, true) == nil then
		return false, `the cache read with no Mode before configure did not say configure runs first: {readMessage}`
	end

	Echo.configure({ mode = "Legacy", cache = { Legacy = SIZE } })
	Echo:root(nil, element)

	if ref.current == nil or #Echo.getAll() ~= 1 then
		return false, "the element refused before configure did not mount once configure ran"
	end

	return true, nil
end
