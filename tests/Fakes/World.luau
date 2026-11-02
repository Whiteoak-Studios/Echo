--[[
    The fake world a voice plays in: Workspace and its Terrain, Folder,
    Attachment, Part and Model, with the positions and pivots that follow
    from each other
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Instance = require("./Instance")

type Spec = Instance.Spec
type World = Instance.World

local World = {}

-- An attachment's position is relative to the part it sits in, and to the world anywhere else
local function frameOf(parent: any): any
	if parent and parent:IsA("BasePart") then
		return parent.CFrame
	end

	return roblox.CFrame.new()
end

local function checkCFrame(world: World, method: string, value: any)
	if world.typeof(value) ~= "CFrame" then
		error(`Unable to cast {world.typeof(value)} to CoordinateFrame in {method}`, 3)
	end
end

function World.classes(world: World): { [string]: Spec }
	-- Moves a CFrame-stored instance to a position, keeping its rotation
	local function place(instance: any, position: any)
		local cframe: any = world.read(instance, "CFrame")
		world.write(instance, "CFrame", cframe - cframe.Position + position)
	end

	return {
		Workspace = {
			init = function (workspace: any)
				local terrain: any = world.create("Terrain")
				terrain.Parent = workspace
				world.write(workspace, "Terrain", terrain)
			end,
		},

		Terrain = {},
		Folder = {},

		Attachment = {
			get = {
				Position = function (attachment: any): any
					return world.read(attachment, "CFrame").Position
				end,

				WorldPosition = function (attachment: any): any
					return frameOf(attachment.Parent) * attachment.Position
				end,
			},

			set = {
				Position = place,

				WorldPosition = function (attachment: any, value: any)
					place(attachment, frameOf(attachment.Parent):Inverse() * value)
				end,
			},
		},

		BasePart = {
			get = {
				Position = function (part: any): any
					return world.read(part, "CFrame").Position
				end,
			},

			set = {
				Position = place,
			},
		},

		Part = {},

		PVInstance = {
			methods = {
				GetPivot = function (self: any): any
					if self:IsA("BasePart") then
						return self.CFrame * self.PivotOffset
					end

					return self.WorldPivot
				end,

				PivotTo = function (self: any, target: any)
					checkCFrame(world, "PivotTo", target)

					if self:IsA("BasePart") then
						self.CFrame = target * self.PivotOffset:Inverse()
						return
					end

					-- A model's parts keep where they sit against its pivot
					local offset: any = target * self.WorldPivot:Inverse()
					for _, descendant: any in self:GetDescendants() do
						if descendant:IsA("BasePart") then
							descendant.CFrame = offset * descendant.CFrame
						end
					end

					self.WorldPivot = target
				end,
			},
		},

		Model = {},
	}
end

return World
