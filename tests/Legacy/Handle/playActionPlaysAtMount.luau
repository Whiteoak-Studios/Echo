--[[
    Limit 5 on 7.8.6: an Echo.Action.Play state that holds true when its
    sound mounts never plays it, since an action never gets its default
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local playing: any = Echo.useState(true)
	local sounds: { any } = Echo.createElement("Sound", { SoundId = ID, [Echo.Action.Play] = playing })
	Echo:root({ sounds })

	if not sounds[1].IsPlaying then
		return false, "an Echo.Action.Play state holding true at mount did not play its sound"
	end

	return true, nil
end
