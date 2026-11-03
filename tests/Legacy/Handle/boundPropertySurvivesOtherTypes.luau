--[[
    Limit 4 on 7.8.6: a set of nil to a bound Volume warns and ends the
    binding for good, and every set also writes an attribute named Volume
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local QUIET: number = 0.25
local LOUD: number = 0.75

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local volume: any, setVolume: (value: any) -> () = Echo.useState(QUIET)
	local sounds: { any } = Echo.createElement("Sound", { SoundId = ID, Volume = volume })
	Echo:root({ sounds })
	local sound: any = sounds[1]

	setVolume(nil)
	setVolume(LOUD)
	if sound.Volume ~= LOUD then
		return false, `a set of nil ended the binding, so a later set of {LOUD} left the Volume at {sound.Volume}`
	elseif sound:GetAttribute("Volume") ~= nil then
		return false, "a set wrote the Volume twice, once more as an attribute"
	end

	return true, nil
end
