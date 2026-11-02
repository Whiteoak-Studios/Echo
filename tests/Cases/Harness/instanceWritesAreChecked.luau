--[[
    A fake instance refuses what the engine refuses: an unknown member, a
    read-only property, a value of the wrong type and a class Instance.new
    cannot make, and starts each property at the engine's default
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local ID: string = "rbxassetid://1"

-- Classes Instance.new refuses: abstract, a service, unknown, and real but not faked here
local REFUSED: { string } = { "BasePart", "Workspace", "Nonsense", "BindableEvent" }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local package: any = env.require()
	local Enum: any = package.Enum
	local sound: any = env.Instance.new("Sound")

	if sound.Volume ~= 0.5 or sound.SoundId ~= "" or sound.RollOffMode ~= Enum.RollOffMode.Inverse or sound.Looped then
		return false, "a new Sound does not start at the engine's defaults"
	end

	if pcall(function ()
		local _ = sound.Loudness
	end) or pcall(function ()
		sound.Loudness = 1
	end) then
		return false, "a member Sound does not have was read or written"
	end

	if pcall(function ()
		sound.IsPlaying = true
	end) or pcall(function ()
		sound.ClassName = "Part"
	end) then
		return false, "a read-only property was written"
	end

	local typed: boolean, message: any = pcall(function ()
		sound.Volume = "loud"
	end)

	if typed or not tostring(message):find("Volume", 1, true) then
		return false, "a string went into Volume, or the refusal did not name the property"
	end

	if pcall(function ()
		sound.Looped = 1
	end) or pcall(function ()
		sound.SoundGroup = ID
	end) then
		return false, "a number went into a bool, or a string into an instance reference"
	end

	-- An enum property takes an item of its enum, an item's name or its value
	sound.RollOffMode = "Linear"
	if sound.RollOffMode ~= Enum.RollOffMode.Linear then
		return false, "an enum property did not take an item's name"
	end

	sound.RollOffMode = Enum.RollOffMode.InverseTapered.Value
	if sound.RollOffMode ~= Enum.RollOffMode.InverseTapered then
		return false, "an enum property did not take an item's value"
	end

	if
		pcall(function ()
			sound.RollOffMode = Enum.PartType.Block
		end) or pcall(function ()
			sound.RollOffMode = "Nonsense"
		end)
	then
		return false, "an enum property took another enum's item or a name its enum lacks"
	end

	sound.SoundId = ID
	sound.Name = 5 :: any
	if sound.SoundId ~= ID or sound.Name ~= "5" then
		return false, "a string property did not take a string, or a number as the engine turns it into one"
	end

	for _, className: string in REFUSED do
		if pcall(env.Instance.new, className) then
			return false, `Instance.new made a {className}`
		end
	end

	local _, unfaked: any = pcall(env.Instance.new, "BindableEvent")
	if not tostring(unfaked):find("tests/Fakes", 1, true) then
		return false, "a real class the harness does not fake was not named as missing from tests/Fakes"
	end

	return true, nil
end
