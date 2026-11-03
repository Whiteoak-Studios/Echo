--[[
    On 7.8.6, root expects a list of element lists, so a bare createElement
    of a Sound handed to it is iterated as one list too many
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()
	local ref: any = Echo.createRef()

	local element: any = Echo.createElement("Sound", { SoundId = ID, Handle = ref })
	local mounted: boolean, message: any = pcall(Echo.root, Echo, element)

	if not mounted then
		return false, `root errored on a bare sound element: {message}`
	elseif not ref.current.Parent then
		return false, "root iterated the bare sound element as a list and never mounted its sound"
	end

	return true, nil
end
