--[[
    preload holds the SoundIds of the priority roots first, in the list's
    order, then every other recorded id, then the ids it is given, each
    once, and resolves with the ids whose holder never turned ready
--]]

--!strict
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
	local Constants: any = env.require("Constants")

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

	local failed: { string }? = nil
	local promise: any = Echo.preload({ weapons, menu }, { TAKE, GUN }):andThen(function (ids: { string })
		failed = ids
	end)

	-- The folder holds the holders beside whatever configure put there
	local folder: any = env.game:GetService("SoundService"):FindFirstChild(Constants.FOLDER_NAME)
	local holders: { any } = {}
	local held: { string } = {}
	for _, child: any in folder:GetChildren() do
		if child:IsA("AudioPlayer") then
			table.insert(holders, child)
			table.insert(held, child.Name)
		end
	end

	local expected: { string } = { GUN, RELOAD, MENU, RECORDED, TAKE }
	if #held ~= #expected then
		return false, `the pass held {#held} ids, not {#expected}: {table.concat(held, ", ")}`
	end

	for index: number, id: string in expected do
		if held[index] ~= id then
			return false, `the pass held {held[index]} at {index}, not {id}: {table.concat(held, ", ")}`
		end
	end

	-- Every holder but RELOAD's turns ready, so RELOAD fails once its wait ends
	for _, holder: any in holders do
		if holder.Name ~= RELOAD then
			env.load(holder)
		end
	end

	env.step(Constants.PRELOAD_WAIT)
	if promise:getStatus() ~= "Resolved" or not failed or #failed ~= 1 or failed[1] ~= RELOAD then
		local got: string = failed and table.concat(failed, ", ") or "nothing"
		return false, `preload's Promise was {promise:getStatus()} with {got}, where it resolves with {RELOAD}`
	end

	return true, nil
end
