--[[
    preload refuses at the call, before it makes any holder, a priority list
    holding anything Echo did not make as a root, naming the entry, a root
    or a string handed where the list belongs, and an id that is no string
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local NOT_A_ROOT: string = "not a root Echo made"
local NOT_A_LIST: string = "a list of roots"
local NOT_AN_ID: string = "ids[1]"
local ROOT_NAME: string = "Menu"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Echo: any = env.require()
	local Constants: any = env.require("Constants")

	Echo.configure({ mode = "Legacy", cache = { Legacy = SIZE } })

	local element: any = Echo.createElement("Sound", { SoundId = ID })
	local root: any = Echo:root(ROOT_NAME, element)

	-- Values a game might hand over in a root's place
	local entries: { any } = { {}, ROOT_NAME, element, Echo.createRef(), { destroy = root.destroy } }
	for _, entry: any in entries do
		local loaded: boolean, message: any = pcall(Echo.preload, { root, entry })
		local said: string = tostring(message)
		if
			loaded
			or string.find(said, NOT_A_ROOT, 1, true) == nil
			or string.find(said, tostring(entry), 1, true) == nil
		then
			return false, `preload took {entry} as a priority root, or refused it without naming it: {message}`
		end
	end

	local single: boolean, singleMessage: any = pcall(Echo.preload, root)
	if single or string.find(tostring(singleMessage), NOT_A_ROOT, 1, true) == nil then
		return false, `preload took one root in place of a list of them: {singleMessage}`
	end

	local named: boolean, namedMessage: any = pcall(Echo.preload, ROOT_NAME)
	if named or string.find(tostring(namedMessage), NOT_A_LIST, 1, true) == nil then
		return false, `preload took a string in place of its list of roots: {namedMessage}`
	end

	local numbered: boolean, numberedMessage: any = pcall(Echo.preload, nil, { 1 })
	if numbered or string.find(tostring(numberedMessage), NOT_AN_ID, 1, true) == nil then
		return false, `preload took a number among its ids: {numberedMessage}`
	end

	-- configure made the folder, so a refused preload leaves it holding no AudioPlayer
	local folder: any = env.game:GetService("SoundService"):FindFirstChild(Constants.FOLDER_NAME)
	for _, child: any in folder:GetChildren() do
		if child:IsA("AudioPlayer") then
			return false, `a refused preload still made a holder for {child.Name}`
		end
	end

	return true, nil
end
