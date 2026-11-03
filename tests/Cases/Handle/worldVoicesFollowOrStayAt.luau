--[[
    A root on a part plays world voices that follow it, and one whose part is
    destroyed mid-play keeps playing at the part's last position; a play with
    at is a world voice at that point under any root and follows nothing; a
    root on a string plays in 2D, in either Mode
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local NAME: string = "Ambience"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 8, growAt = 4, growBy = 2, ceiling = 16 }
local FRAME: number = 1 / 60
local FRAMES: number = 3

return function (): (boolean, string | nil)
	local Vector3: any = roblox.Vector3

	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")

		Root.configure({ mode = mode, cache = { [mode] = SIZE } })
		local folder: any = env.game:GetService("SoundService").Echo

		-- Where a voice is heard from: its Attachment for a world voice, else SoundService's Echo folder
		local function heardAt(voice: any): any
			if voice.instance:IsA("Sound") then
				return voice.instance.Parent
			end

			local wire: any = voice.tree:FindFirstChild("Wire")
			return wire.TargetInstance:IsA("AudioEmitter") and voice.tree or folder
		end

		local function mount(target: any): any
			local ref: any = Element.ref(nil)
			Root.mount(target, Element.create("Sound", { SoundId = ID, Handle = ref }))

			return ref.current
		end

		local part: any = env.Instance.new("Part")
		part.Position = Vector3.new(10, 0, 0)
		part.Parent = env.game.Workspace

		local onPart: any = mount(part)
		local followed: any = onPart:play()
		part.Position = Vector3.new(20, 0, 0)
		env.step(FRAME)

		if followed.tree.WorldPosition ~= Vector3.new(20, 0, 0) or heardAt(followed) ~= followed.tree then
			return false, `a {mode} voice on a part did not follow it as a world voice`
		end

		part:Destroy()
		env.step(FRAME * FRAMES)

		if followed.instance == nil or not followed.instance.IsPlaying then
			return false, `a {mode} voice whose part was destroyed stopped playing`
		elseif followed.tree.WorldPosition ~= Vector3.new(20, 0, 0) then
			return false, `a {mode} voice whose part was destroyed moved to {followed.tree.WorldPosition}`
		end

		local point: any = Vector3.new(5, 5, 5)
		local moving: any = env.Instance.new("Part")
		moving.Parent = env.game.Workspace

		-- Under a root with no target, one on a string and one on a part that then moves
		local handles: { any } = { mount(nil), mount(NAME), mount(moving) }
		for index: number, handle: any in handles do
			local placed: any = handle:play({ at = point })
			moving.Position = Vector3.new(30, 0, 0)
			env.step(FRAME)

			if placed.tree.WorldPosition ~= point or heardAt(placed) ~= placed.tree then
				return false, `a {mode} play with at under root {index} was not a world voice at that point`
			end
		end

		local flat: any = mount(NAME):play()
		if heardAt(flat) ~= folder then
			return false, `a {mode} voice under a string root did not play in 2D`
		end
	end

	return true, nil
end
