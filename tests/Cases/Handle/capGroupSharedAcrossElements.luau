--[[
    Elements that name one cap group share its limit: a play past it stops
    the group's earliest-started voice, whichever element or Mode played it,
    and leaves every other group alone
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local SIZE: { [string]: number } = { initial = 8, growAt = 4, growBy = 2, ceiling = 16 }
local GROUP: string = "Gun/AKM/FirstPerson"
local OTHER: string = "Footsteps"
local LIMIT: number = 2

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	Root.configure({
		mode = "Legacy",
		cache = { Legacy = SIZE, AudioApi = SIZE },
		caps = { [GROUP] = LIMIT, [OTHER] = LIMIT },
	})

	local function mount(group: string, mode: string?): any
		local ref: any = Element.ref(nil)
		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = ref, [Keys.Util.Cap] = group }), mode)

		return ref.current
	end

	local near: any = mount(GROUP)
	local far: any = mount(GROUP)
	local steps: any = mount(OTHER)
	local remote: any = mount(GROUP, "AudioApi")

	local step: any = steps:play()
	local first: any = near:play()
	local second: any = far:play()
	local third: any = near:play()

	if first.instance ~= nil then
		return false, "a play past the group's cap did not stop the group's earliest voice"
	elseif second.instance == nil or third.instance == nil or step.instance == nil then
		return false, "a play past the group's cap stopped a voice other than the group's earliest"
	end

	local fourth: any = remote:play()
	if second.instance ~= nil or not fourth.instance:IsA("AudioPlayer") then
		return false, "an Audio API play in the group did not stop the group's earliest legacy voice"
	elseif third.instance == nil or step.instance == nil then
		return false, "an Audio API play in the group stopped a voice other than the group's earliest"
	end

	return true, nil
end
