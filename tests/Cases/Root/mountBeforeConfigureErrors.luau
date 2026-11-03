--[[
    A root mounted, or the default Mode read, before configure errors and
    says configure must run first
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local FIRST: string = "configure must run before the first root"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")

	local element: any = Element.create("Sound", { SoundId = ID })
	local mounted: boolean, message: any = pcall(Root.mount, nil, element)
	if mounted or string.find(tostring(message), FIRST, 1, true) == nil then
		return false, `a mount before configure did not say configure runs first: {message}`
	end

	local read: boolean, readMessage: any = pcall(Root.defaultMode)
	if read or string.find(tostring(readMessage), FIRST, 1, true) == nil then
		return false, `the default Mode read before configure did not say configure runs first: {readMessage}`
	end

	return true, nil
end
