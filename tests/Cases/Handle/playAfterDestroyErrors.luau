--[[
    A handle whose root was destroyed errors on play, saying its root was
    destroyed, and has no live voice left for get, getAll or stop
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")

	Root.configure({ mode = "Legacy", cache = { Legacy = SIZE } })

	local ref: any = Element.ref(nil)
	local root: any = Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = ref }))
	local handle: any = ref.current

	handle:play()
	root:destroy()

	local played: boolean, message: any = pcall(handle.play, handle)
	if played or string.find(tostring(message), "destroyed", 1, true) == nil then
		return false, `play on a destroyed root's handle did not error saying so: {message}`
	elseif handle:get() ~= nil or #handle:getAll() ~= 0 then
		return false, "a destroyed root's handle still had a live voice"
	elseif not pcall(handle.stop, handle) then
		return false, "stop on a destroyed root's handle raised"
	end

	return true, nil
end
