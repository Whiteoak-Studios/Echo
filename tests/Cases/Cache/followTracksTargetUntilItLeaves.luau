--[[
    A voice following a part, an attachment or a model is placed at its
    target at once and again each Heartbeat, and once the target is
    destroyed it stays at the target's last position, still playing
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 4, growAt = 1, growBy = 1, ceiling = 8 }
local FRAME: number = 1 / 60
local FRAMES: number = 3

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local backend: FakeBackend.FakeBackend = FakeBackend.new(env)
	local new: (className: string) -> any = env.Instance.new
	local workspace: any = env.game.Workspace
	local Vector3: any = roblox.Vector3
	local CFrame: any = roblox.CFrame

	Cache.create(MODE, SIZE, backend)

	local function take(): any
		return Cache.take(MODE, { looped = false, release = function () end })
	end

	local function places(tree: any): number
		local count: number = 0
		for _, call: FakeBackend.Call in backend.calls do
			if call.name == "place" and call.args[1] == tree then
				count += 1
			end
		end

		return count
	end

	local part: any = new("Part")
	part.Position = Vector3.new(10, 0, 0)
	part.Parent = workspace

	local voice: any = take()
	Cache.follow(voice, part)
	if voice.tree.WorldPosition ~= Vector3.new(10, 0, 0) then
		return false, `a followed voice was not placed at its part at once, but at {voice.tree.WorldPosition}`
	end

	part.Position = Vector3.new(20, 0, 0)
	env.step(FRAME)
	if voice.tree.WorldPosition ~= Vector3.new(20, 0, 0) then
		return false, `a part's move did not reach its voice on the next Heartbeat: {voice.tree.WorldPosition}`
	end

	part:Destroy()
	env.step(FRAME)
	local placed: number = places(voice.tree)
	env.step(FRAME * FRAMES)

	if voice.tree.WorldPosition ~= Vector3.new(20, 0, 0) or places(voice.tree) ~= placed then
		return false, "a voice whose part was destroyed moved, or kept being placed"
	end

	if voice.instance == nil or Cache.count(MODE).inUse ~= 1 then
		return false, "a voice whose part was destroyed stopped playing"
	end

	local carrier: any = new("Part")
	carrier.CFrame = CFrame.new(0, 0, 5)
	carrier.Parent = workspace

	local attachment: any = new("Attachment")
	attachment.Position = Vector3.new(0, 2, 0)
	attachment.Parent = carrier

	local onAttachment: any = take()
	Cache.follow(onAttachment, attachment)
	carrier.CFrame = CFrame.new(0, 0, 9)
	env.step(FRAME)
	if onAttachment.tree.WorldPosition ~= Vector3.new(0, 2, 9) then
		return false, `a voice did not follow its attachment's world position: {onAttachment.tree.WorldPosition}`
	end

	local model: any = new("Model")
	local inside: any = new("Part")
	inside.Parent = model
	model.Parent = workspace
	model:PivotTo(CFrame.new(3, 0, 0))

	local onModel: any = take()
	Cache.follow(onModel, model)
	model:PivotTo(CFrame.new(6, 1, 0))
	env.step(FRAME)
	if onModel.tree.WorldPosition ~= Vector3.new(6, 1, 0) then
		return false, `a voice did not follow its model's pivot: {onModel.tree.WorldPosition}`
	end

	return true, nil
end
