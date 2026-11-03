--[[
    On 7.8.6, an element's Echo.Event.Loaded handler runs, through a defer,
    when its Sound has already loaded as the handler connects (limit 7)
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()

	-- A Sound whose asset the engine already holds has loaded by the time a script reads it
	local new: (className: string) -> any = env.Instance.new
	env.Instance.new = function (className: string): any
		local instance: any = new(className)
		if className == "Sound" then
			env.set(instance, "SoundId", ID)
			env.set(instance, "IsLoaded", true)
		end

		return instance
	end

	local loaded: number = 0
	Echo.createElement("Sound", {
		[Echo.Event.Loaded] = function ()
			loaded += 1
		end,
	})

	env.step(0)
	if loaded ~= 1 then
		return false, `Loaded ran {loaded} times for a Sound that had already loaded, not once`
	end

	return true, nil
end
