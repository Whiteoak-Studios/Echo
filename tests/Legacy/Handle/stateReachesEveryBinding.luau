--[[
    Limit 18 on 7.8.6: a state's default, and a spring's, reaches only the
    first property bound to it, so a second binding keeps the Sound's own
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local QUIET: number = 0.25
local DURATION: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	local volume: any = Echo.useState(QUIET)
	local first: { any } = Echo.createElement("Sound", { SoundId = ID, Volume = volume })
	local second: { any } = Echo.createElement("Sound", { SoundId = ID, Volume = volume })

	local styles: any = Echo.useSpring(function ()
		return { volume = QUIET, config = { duration = DURATION, delay = 0 } }
	end)

	local sprung: { any } = Echo.createElement("Sound", { SoundId = ID, Volume = styles.volume })
	local sprungAgain: { any } = Echo.createElement("Sound", { SoundId = ID, Volume = styles.volume })
	Echo:root({ first, second, sprung, sprungAgain })

	if second[1].Volume ~= QUIET then
		return false, `a state holding {QUIET} reached its second binding as {second[1].Volume}`
	elseif sprungAgain[1].Volume ~= QUIET then
		return false, `a spring holding {QUIET} reached its second binding as {sprungAgain[1].Volume}`
	end

	return true, nil
end
