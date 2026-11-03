--[[
    Every ref of an element gets its handle at mount, never an instance, and
    goes back to nil when the root is destroyed, while a ref a later root
    took over keeps that root's handle
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

	local first: any = Element.ref(nil)
	local second: any = Element.ref(nil)
	local shared: any = Element.ref(nil)

	local root: any = Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = first, Other = second }))
	local handle: any = first.current

	if handle == nil or second.current ~= handle then
		return false, "the element's two refs did not both get its handle at mount"
	end

	-- A fake instance throws on a member it lacks, so this reads a handle's methods and nothing else
	local read: boolean, isHandle: any = pcall(function (): boolean
		return type(handle.play) == "function"
			and type(handle.stop) == "function"
			and type(handle.get) == "function"
			and type(handle.getAll) == "function"
	end)

	if not read or not isHandle then
		return false, "a ref got something other than the element's handle"
	end

	local early: any = Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = shared }))
	Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = shared }))
	local later: any = shared.current

	root:destroy()
	early:destroy()

	if first.current ~= nil or second.current ~= nil then
		return false, "a destroyed root's refs kept its handle"
	elseif shared.current ~= later or later == nil then
		return false, "destroying an earlier root cleared a ref a later root had taken over"
	end

	return true, nil
end
