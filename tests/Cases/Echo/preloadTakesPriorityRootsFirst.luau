--[[
    preload hands its one PreloadAsync pass the SoundIds of the priority
    roots first, in the list's order, then every other recorded id, then the
    ids it is given, each once, and resolves with the ids that failed
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")

local RECORDED: string = "rbxassetid://1"
local MENU: string = "rbxassetid://2"
local GUN: string = "rbxassetid://3"
local RELOAD: string = "rbxassetid://4"
local TAKE: string = "rbxassetid://5"
local MENU_NAME: string = "Menu"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Echo: any = env.require()
	local Enum: any = roblox.Enum

	Echo.configure({ mode = "Legacy", cache = { Legacy = SIZE } })

	-- Recorded by its creation, though no root mounts it
	Echo.createElement("Sound", { SoundId = RECORDED })

	local menu: any = Echo:root(MENU_NAME, Echo.createElement("Sound", { SoundId = MENU }))
	local weapons: any = Echo:root(
		nil,
		Echo.createElement(Echo.Fragment, {
			Echo.createElement("Sound", { SoundId = GUN }),
			Echo.createElement("Sound", { SoundId = RELOAD }),
		})
	)

	env.preload.statuses[RELOAD] = Enum.AssetFetchStatus.Failure

	local failed: { string }? = nil
	local promise: any = Echo.preload({ weapons, menu }, { TAKE, GUN }):andThen(function (ids: { string })
		failed = ids
	end)

	if #env.preload.calls ~= 1 then
		return false, `preload made {#env.preload.calls} PreloadAsync calls, not 1`
	end

	local call: { string } = env.preload.calls[1]
	local expected: { string } = { GUN, RELOAD, MENU, RECORDED, TAKE }
	if #call ~= #expected then
		return false, `the pass took {#call} ids, not {#expected}: {table.concat(call, ", ")}`
	end

	for index: number, id: string in expected do
		if call[index] ~= id then
			return false, `the pass took {call[index]} at {index}, not {id}: {table.concat(call, ", ")}`
		end
	end

	if promise:getStatus() ~= "Resolved" or not failed or #failed ~= 1 or failed[1] ~= RELOAD then
		local got: string = failed and table.concat(failed, ", ") or "nothing"
		return false, `preload's Promise was {promise:getStatus()} with {got}, where it resolves with {RELOAD}`
	end

	return true, nil
end
