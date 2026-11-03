--[[
    A later pass keeps each id's holder and makes no second one, so an id
    already ready settles at once and one still unready waits again, and a
    sound made after a pass gets a holder of its own in the next
--]]

--!strict
local Environment = require("../../Environment")

local READY: string = "rbxassetid://1"
local UNREADY: string = "rbxassetid://2"
local NEWER: string = "rbxassetid://3"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Constants: any = env.require("Constants")
	local Element: any = env.require("Element")
	local Preload: any = env.require("Preload")

	Element.create("Sound", { SoundId = READY })
	Element.create("Sound", { SoundId = UNREADY })

	local first: any = Preload.run()
	local folder: any = env.game:GetService("SoundService"):FindFirstChild(Constants.FOLDER_NAME)
	local ready: any = folder and folder:FindFirstChild(READY)
	local unready: any = folder and folder:FindFirstChild(UNREADY)
	if not ready or not unready then
		return false, `the first pass made no holder for {READY} or {UNREADY} in SoundService's Echo folder`
	end

	env.load(ready)
	env.step(Constants.PRELOAD_WAIT)
	if first:getStatus() ~= "Resolved" then
		return false, `the first pass was {first:getStatus()} once its wait ended`
	end

	local second: any = Preload.run()
	if
		#folder:GetChildren() ~= 2
		or folder:FindFirstChild(READY) ~= ready
		or folder:FindFirstChild(UNREADY) ~= unready
	then
		return false, `the second pass left {#folder:GetChildren()} holders, where it reuses the 2 the first made`
	elseif second:getStatus() ~= "Started" then
		return false, `the second pass was {second:getStatus()} while {UNREADY} was still not ready`
	end

	env.load(unready)
	if second:getStatus() ~= "Resolved" then
		return false, `the second pass was {second:getStatus()} once {UNREADY} turned ready on its old holder`
	end

	Element.create("Sound", { SoundId = NEWER })
	local third: any = Preload.run()
	local children: { any } = folder:GetChildren()
	local newer: any = children[3]
	if #children ~= 3 or not newer or newer.Name ~= NEWER then
		return false, `the third pass did not add one holder for {NEWER} after the two it reuses`
	end

	env.load(newer)
	if third:getStatus() ~= "Resolved" then
		return false, `the third pass was {third:getStatus()} once {NEWER} turned ready`
	end

	-- Every id is held ready now, so a pass settles without a wait
	local fourth: any = Preload.run()
	if fourth:getStatus() ~= "Resolved" then
		return false, `a pass of ids already ready was {fourth:getStatus()}, where it resolves at once`
	end

	local _, failed: any = fourth:await()
	if type(failed) ~= "table" or next(failed) ~= nil or #folder:GetChildren() ~= 3 then
		return false, `a pass of ids already ready resolved {failed} or made a holder, not an empty list and none`
	end

	return true, nil
end
