--[[
    A fake instance has the engine's tree and members: names, parents, IsA
    along the class tree, finding and waiting for children, attributes,
    changed signals and AncestryChanged
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local TIMEOUT: number = 1
local LOUD: number = 1
local TAKE: number = 2

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local package: any = env.require()
	local workspace: any = env.game.Workspace
	local folder: any = env.Instance.new("Folder")

	if
		folder.Name ~= "Folder"
		or folder.ClassName ~= "Folder"
		or folder.Parent ~= nil
		or tostring(folder) ~= "Folder"
	then
		return false, "a new instance is not named after its class with no parent"
	end

	if package.typeof(folder) ~= "Instance" or package.type(folder) ~= "userdata" then
		return false, `the package sees a fake instance as {package.typeof(folder)}, {package.type(folder)}`
	end

	folder.Name = "Holder"
	folder.Parent = workspace
	local part: any = env.Instance.new("Part")
	part.Parent = folder

	if folder.Part ~= part or folder:FindFirstChild("Part") ~= part or workspace:FindFirstChild("Part") then
		return false, "a child is not found by name, or found where it is not a child"
	end

	if workspace:FindFirstChild("Part", true) ~= part or #workspace:GetDescendants() ~= 3 then
		return false, "a recursive find or GetDescendants missed a descendant"
	end

	if
		part:GetFullName() ~= "Workspace.Holder.Part"
		or not part:IsDescendantOf(workspace)
		or folder:IsDescendantOf(part)
	then
		return false, `GetFullName gave {part:GetFullName()}, or IsDescendantOf was wrong`
	end

	local model: any = env.Instance.new("Model")
	local sound: any = env.Instance.new("Sound")
	if not part:IsA("BasePart") or not part:IsA("PVInstance") or not part:IsA("Instance") then
		return false, "a Part is not a BasePart, a PVInstance and an Instance"
	end

	if not model:IsA("PVInstance") or model:IsA("BasePart") or sound:IsA("BasePart") or not sound:IsA("Instance") then
		return false, "IsA does not follow the class tree"
	end

	-- A member outranks a child of the same name, as in the engine
	local named: any = env.Instance.new("Folder")
	named.Name = "Name"
	named.Parent = folder
	if folder.Name ~= "Holder" then
		return false, "a child named Name hid the Name property"
	end

	part:SetAttribute("Artist", "Mike")
	part:SetAttribute("Take", TAKE)
	if part:GetAttribute("Artist") ~= "Mike" or part:GetAttributes().Take ~= TAKE then
		return false, "an attribute did not read back"
	end

	part:SetAttribute("Take", nil)
	if part:GetAttribute("Take") ~= nil then
		return false, "setting an attribute to nil did not clear it"
	end

	if pcall(part.SetAttribute, part, "Bad Name", 1) or pcall(part.SetAttribute, part, "Table", {}) then
		return false, "SetAttribute took a name or a value the engine refuses"
	end

	local changes: number = 0
	sound:GetPropertyChangedSignal("Volume"):Connect(function ()
		changes += 1
	end)

	sound.Volume = LOUD
	sound.Volume = LOUD
	if changes ~= 1 then
		return false, `a changed signal fired {changes} times for one change`
	end

	if pcall(sound.GetPropertyChangedSignal, sound, "Loudness") then
		return false, "GetPropertyChangedSignal took a property Sound does not have"
	end

	local moved: { any } = {}
	part.AncestryChanged:Connect(function (child: any, parent: any)
		moved = { child, parent }
	end)

	local storage: any = env.game:GetService("ReplicatedStorage")
	folder.Parent = storage
	if moved[1] ~= folder or moved[2] ~= storage then
		return false, "AncestryChanged did not reach a descendant with the moved instance and its parent"
	end

	if pcall(function ()
		folder.Parent = part
	end) then
		return false, "an instance became its own descendant's child"
	end

	if folder:WaitForChild("Part") ~= part then
		return false, "WaitForChild did not give a child that was already there"
	end

	local timedOut: any = false
	local arrived: any = nil
	env.task.spawn(function ()
		timedOut = folder:WaitForChild("Missing", TIMEOUT)
	end)

	env.task.spawn(function ()
		arrived = folder:WaitForChild("Later")
	end)

	local later: any = env.Instance.new("Folder")
	later.Name = "Later"
	later.Parent = folder
	if arrived ~= later or timedOut ~= false then
		return false, "WaitForChild missed a child that arrived, or gave up before its timeout"
	end

	env.step(TIMEOUT)
	if timedOut ~= nil then
		return false, "WaitForChild with a timeout did not give nil once it passed"
	end

	return true, nil
end
