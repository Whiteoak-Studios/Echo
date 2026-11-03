--[[
    A play checks its overrides the way a mount checks properties and errors
    at the call, naming the one its Mode refuses, before it takes a voice;
    overrides the Mode takes play
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local LOUD: number = 0.75
local LOW: number = -6

type Refusal = {
	overrides: any,
	names: string, -- What the error must name
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")
	local Cache: any = env.require("Cache")

	Root.configure({ mode = "Legacy", cache = { Legacy = SIZE, AudioApi = SIZE } })

	local legacy: any = Element.ref(nil)
	local audioApi: any = Element.ref(nil)
	local children: { [string]: any } = {
		Equalizer = Element.create("EqualizerSoundEffect", { HighGain = LOW }),
	}

	Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = legacy }, children))
	Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = audioApi }, children), "AudioApi")

	local refusals: { Refusal } = {
		{ overrides = "loud", names = "overrides" },
		{ overrides = { Volume = "loud" }, names = "Volume" },
		{ overrides = { Parent = env.game.Workspace }, names = "Parent" },
		{ overrides = { Bogus = 1 }, names = "Bogus" },
		{ overrides = { Name = "Shot" }, names = "Name" },
		{ overrides = { at = 5 }, names = "at" },
		{ overrides = { [1] = LOUD }, names = "1" },
		{ overrides = { Equalizer = LOW }, names = "Equalizer" },
		{ overrides = { Equalizer = { MidRange = LOW } }, names = "MidRange" },
		{ overrides = { Equalizer = { [1] = LOW } }, names = "1" },
	}

	for index: number, refusal: Refusal in refusals do
		local played: boolean, message: any = pcall(legacy.current.play, legacy.current, refusal.overrides)
		if played then
			return false, `refusal {index} played`
		elseif string.find(tostring(message), refusal.names, 1, true) == nil then
			return false, `refusal {index} errored without naming {refusal.names}: {message}`
		end
	end

	local refused: boolean, message: any = pcall(audioApi.current.play, audioApi.current, { EmitterSize = 1 })
	if refused or string.find(tostring(message), "EmitterSize", 1, true) == nil then
		return false, `an Audio API play took an EmitterSize override, or errored without naming it: {message}`
	elseif Cache.count("Legacy").inUse ~= 0 or Cache.count("AudioApi").inUse ~= 0 then
		return false, "a refused play took a voice"
	end

	local point: any = roblox.Vector3.new(1, 2, 3)
	local voice: any = legacy.current:play({ Volume = LOUD, Equalizer = { HighGain = LOW }, at = point })

	if not voice or voice.instance.Volume ~= LOUD or voice.tree.WorldPosition ~= point then
		return false, "a play with overrides the Mode takes did not play with them"
	end

	return true, nil
end
