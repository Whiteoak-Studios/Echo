--[[
    On 7.8.6, an element's Echo.Event.Ended handler runs once when its
    Sound ends of itself and never when the Sound is stopped (limit 6)
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local ended: number = 0
	local sounds: { any } = Echo.createElement("Sound", {
		SoundId = ID,

		[Echo.Event.Ended] = function ()
			ended += 1
		end,
	})

	Echo:root({ sounds })
	local sound: any = sounds[1]

	sound:Play()
	env.finish(sound)
	if ended ~= 1 then
		return false, `a natural end ran Ended {ended} times, not once`
	end

	sound:Play()
	sound:Stop()
	if ended ~= 1 then
		return false, "Stop ran Ended"
	end

	return true, nil
end
