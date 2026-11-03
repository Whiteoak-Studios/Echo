--[[
    Limit 3 on 7.8.6: a root with no parent, one given nil and one given a
    string each make a folder inside the package to hold their sounds
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local NAME: string = "Ambience"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = "legacy" })
	local Echo: any = env.require()
	local package: any = env.game:GetService("ReplicatedStorage").Packages.Echo
	local before: number = #package:GetChildren()

	Echo:root({ Echo.createElement("Sound", { SoundId = ID }) })
	Echo:root(nil, { Echo.createElement("Sound", { SoundId = ID }) })
	Echo:root(NAME, { Echo.createElement("Sound", { SoundId = ID }) })

	local made: number = #package:GetChildren() - before
	if made ~= 0 then
		return false, `three roots with no instance to play from made {made} folders inside the package`
	end

	return true, nil
end
