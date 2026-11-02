--[[
    The environment runs 7.8.6: its init.lua loads from .legacy/src beside
    Promise, Cellar and the Sift stand-in, and the elements it creates are
    fake Sounds it parents into its own folder
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local VOLUME: number = 0.25
local ARTIST: string = "Mike"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	if not Echo.Event.Ended or not Echo.Action.Play then
		return false, "7.8.6's init.lua did not load with its Event and Action keys"
	end

	local sounds: { any } = Echo.createElement("Sound", { SoundId = ID, Volume = VOLUME })
	local sound: any = sounds[1]
	if not sound or not sound:IsA("Sound") or sound.SoundId ~= ID or sound.Volume ~= VOLUME then
		return false, "createElement did not make a fake Sound with the props it was given"
	end

	-- Attributes reach 7.8.6's one Sift call, Array.is
	local tagged: any = Echo.createElement("Sound", { Attributes = { Artist = ARTIST } })[1]
	if tagged:GetAttribute("Artist") ~= ARTIST then
		return false, "the Attributes prop did not reach the sound through the Sift stand-in"
	end

	Echo:root({ sounds })
	if not sound.Parent or not sound:IsDescendantOf(env.game:GetService("ReplicatedStorage").Packages.Echo) then
		return false, "root did not parent the sound into the package's folder"
	end

	if #env.errors ~= 0 then
		return false, `a thread threw while 7.8.6 loaded: {env.errors[1]}`
	end

	return true, nil
end
