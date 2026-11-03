--[[
    On 7.8.6, createElement wraps a component's result once more, so a
    component returning another component's element never mounts its sound
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()
	local ref: any = Echo.createRef()

	local function Inner(): any
		return Echo.createElement("Sound", { SoundId = ID, Handle = ref })
	end

	local function Outer(): any
		return Echo.createElement(Inner)
	end

	local tree: any = Echo.createElement(Outer)
	local mounted: boolean, message: any = pcall(Echo.root, Echo, { tree })

	local sound: any = ref.current
	if not sound then
		return false, "the inner component made no Sound"
	elseif not mounted then
		return false, `root errored on a component returning another component's element: {message}`
	elseif not sound.Parent then
		return false, "a component returning another component's element never mounted its sound"
	end

	return true, nil
end
