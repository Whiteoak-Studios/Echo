--[[
    Clone copies a tree's properties, attributes and archivable children
    and points references inside the tree at the copies; Destroy fires
    Destroying, empties the tree, ends its events and locks its Parent
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local ID: string = "rbxassetid://1"
local TAKE: number = 3

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local new: (className: string) -> any = env.Instance.new
	local terrain: any = env.game.Workspace.Terrain

	local attachment: any = new("Attachment")
	attachment:SetAttribute("Take", TAKE)
	local player: any = new("AudioPlayer")
	player.Asset = ID
	player.Parent = attachment
	local emitter: any = new("AudioEmitter")
	emitter.Parent = attachment
	local wire: any = new("Wire")
	wire.SourceInstance = player
	wire.TargetInstance = emitter
	wire.Parent = attachment

	local outside: any = new("AudioFader")
	local stray: any = new("Wire")
	stray.Name = "Stray"
	stray.SourceInstance = player
	stray.TargetInstance = outside
	stray.Parent = attachment

	local hidden: any = new("Folder")
	hidden.Archivable = false
	hidden.Parent = attachment

	local copy: any = attachment:Clone()
	if copy.Parent ~= nil or copy:GetAttribute("Take") ~= TAKE or copy.AudioPlayer.Asset ~= ID then
		return false, "a clone did not copy its properties and attributes, or kept a parent"
	end

	if
		copy.AudioPlayer == player
		or copy.Wire.SourceInstance ~= copy.AudioPlayer
		or copy.Wire.TargetInstance ~= copy.AudioEmitter
	then
		return false, "a clone's Wire still points at the original's player and emitter"
	end

	if copy.Stray.SourceInstance ~= copy.AudioPlayer or copy.Stray.TargetInstance ~= outside then
		return false, "a clone moved a reference that points outside the cloned tree"
	end

	if copy:FindFirstChild("Folder") then
		return false, "a clone copied an unarchivable child"
	end

	hidden.Parent = nil
	if hidden:Clone() ~= nil then
		return false, "an unarchivable instance cloned"
	end

	local destroying: { string } = {}
	attachment.Destroying:Connect(function ()
		table.insert(destroying, "attachment")
	end)

	player.Destroying:Connect(function ()
		table.insert(destroying, "player")
	end)

	local ancestry: any = player.AncestryChanged:Connect(function () end)
	attachment.Parent = terrain
	attachment:Destroy()

	if #destroying ~= 2 then
		return false, `Destroying fired for {#destroying} of the instance and its descendant`
	end

	if attachment.Parent ~= nil or player.Parent ~= nil or #terrain:GetChildren() ~= 0 then
		return false, "a destroyed tree stayed parented"
	end

	if ancestry.Connected then
		return false, "a destroyed instance's event stayed connected"
	end

	if pcall(function ()
		attachment.Parent = terrain
	end) then
		return false, "a destroyed instance's Parent was not locked"
	end

	if not pcall(attachment.Destroy, attachment) or attachment.Name ~= "Attachment" then
		return false, "a second Destroy threw, or a destroyed instance's properties stopped reading"
	end

	return true, nil
end
