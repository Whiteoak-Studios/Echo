--[[
    Limit 19 on 7.8.6: removing a sound after its binding ended on a set of
    another type disconnects that binding a second time, which throws
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local QUIET: number = 0.25
local LOUD: number = 0.75
local WRONG: string = "loud"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local folder: any = env.Instance.new("Folder")
	folder.Parent = env.game.Workspace

	local volume: any, setVolume: (value: any) -> () = Echo.useState(QUIET)
	local sounds: { any } = Echo.createElement("Sound", { SoundId = ID, Volume = volume })
	Echo:root(folder, { sounds })

	setVolume(LOUD)
	setVolume(WRONG)
	setVolume(QUIET)

	local removed: boolean, message: any = pcall(function ()
		sounds[1].Parent = nil
	end)

	local thrown: string? = env.errors[1]
	table.clear(env.errors)

	if not removed or thrown then
		return false, `removing the sound after any sequence of sets threw: {message or thrown}`
	end

	return true, nil
end
