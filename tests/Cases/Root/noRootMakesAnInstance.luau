--[[
    No root makes a folder or any other instance, whatever its target or
    Mode, and neither does a play from one: the count of instances in the
    game and of the package's children stays as configure left it (limit 3)
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local NAME: string = "Ambience"
local SIZE: { [string]: number } = { initial = 8, growAt = 8, growBy = 2, ceiling = 16 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")
	local package: any = env.game:GetService("ReplicatedStorage").Packages.Echo

	Root.configure({ mode = "Legacy", cache = { Legacy = SIZE, AudioApi = SIZE } })

	local part: any = env.Instance.new("Part")
	part.Parent = env.game.Workspace
	local folder: any = env.Instance.new("Folder")
	folder.Parent = env.game.Workspace

	local instances: number = #env.game:GetDescendants()
	local children: number = #package:GetChildren()

	local targets: { any } = { NAME, part, folder }
	local refs: { any } = {}

	local function mount(target: any, mode: string?)
		local ref: any = Element.ref(nil)
		table.insert(refs, ref)
		Root.mount(target, Element.create("Sound", { SoundId = ID, Handle = ref }), mode)
	end

	mount(nil)
	mount(nil, "AudioApi")
	for _, target: any in targets do
		mount(target)
		mount(target, "AudioApi")
	end

	for _, ref: any in refs do
		ref.current:play()
	end

	local made: number = #env.game:GetDescendants() - instances
	local inPackage: number = #package:GetChildren() - children
	if made ~= 0 or inPackage ~= 0 then
		return false,
			`mounting and playing every kind of root made {made} instances, {inPackage} of them in the package`
	end

	return true, nil
end
