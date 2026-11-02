--[[
    The fake world holds Workspace and its Terrain, an attachment's world
    position follows the part it sits in, a part's Position and CFrame move
    together, and a model's PivotTo carries its parts
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")

local FIXTURE: string = "Package"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local package: any = env.require()
	local new: (className: string) -> any = env.Instance.new
	local Vector3: any = roblox.Vector3
	local CFrame: any = roblox.CFrame
	local workspace: any = env.game.Workspace
	local terrain: any = workspace.Terrain

	if package.workspace ~= workspace or env.game:GetService("Workspace") ~= workspace then
		return false, "the package's workspace is not the game's Workspace"
	end

	if terrain.ClassName ~= "Terrain" or not terrain:IsA("BasePart") or terrain.Parent ~= workspace then
		return false, "Workspace.Terrain is not a Terrain inside it"
	end

	if pcall(new, "Terrain") then
		return false, "Instance.new made a Terrain"
	end

	local onTerrain: any = new("Attachment")
	onTerrain.Parent = terrain
	onTerrain.WorldPosition = Vector3.new(1, 2, 3)
	if onTerrain.WorldPosition ~= Vector3.new(1, 2, 3) or onTerrain.Position ~= Vector3.new(1, 2, 3) then
		return false, "an attachment on Terrain did not take the world position it was given"
	end

	local part: any = new("Part")
	part.Position = Vector3.new(10, 0, 0)
	part.Parent = workspace
	if part.CFrame.Position ~= Vector3.new(10, 0, 0) or part.Size ~= Vector3.new(4, 1.2, 2) then
		return false, "a part's Position did not move its CFrame, or its Size is not the engine's default"
	end

	local onPart: any = new("Attachment")
	onPart.Position = Vector3.new(0, 5, 0)
	onPart.Parent = part
	part.CFrame = CFrame.new(20, 0, 0)
	if onPart.WorldPosition ~= Vector3.new(20, 5, 0) then
		return false, `an attachment on a moved part sits at {onPart.WorldPosition}`
	end

	local model: any = new("Model")
	local inside: any = new("Part")
	inside.Position = Vector3.new(1, 0, 0)
	inside.Parent = model
	model:PivotTo(CFrame.new(0, 10, 0))
	if model:GetPivot() ~= CFrame.new(0, 10, 0) or inside.Position ~= Vector3.new(1, 10, 0) then
		return false, "PivotTo did not move the model's pivot and carry its part"
	end

	part:PivotTo(CFrame.new(0, 0, 7))
	if part:GetPivot() ~= CFrame.new(0, 0, 7) or part.Position ~= Vector3.new(0, 0, 7) then
		return false, "a part's PivotTo did not move it"
	end

	if pcall(model.PivotTo, model, Vector3.new()) then
		return false, "PivotTo took a Vector3"
	end

	if new("Folder").ClassName ~= "Folder" then
		return false, "Instance.new made no Folder"
	end

	return true, nil
end
