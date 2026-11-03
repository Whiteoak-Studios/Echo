--[[
    ids gives the SoundIds of each root it is handed, in the list's order
    and each root's mount order, a bound one at its state's current and
    strings only. A destroyed root gives none, and a value that is no root
    errors, naming it
--]]

--!strict
local Environment = require("../../Environment")

local FIRST: string = "rbxassetid://1"
local SECOND: string = "rbxassetid://2"
local THIRD: string = "rbxassetid://3"
local FOURTH: string = "rbxassetid://4"
local RETUNED: string = "rbxassetid://5"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")
	local State: any = env.require("State")

	Root.configure({ mode = "Legacy", cache = { Legacy = SIZE } })

	local bound: any, setBound: (value: any) -> () = State.new(SECOND)
	local unset: any = State.new(nil)

	local weapons: any = Root.mount(
		nil,
		Element.create(Keys.Fragment, {
			Element.create("Sound", { SoundId = FIRST }),
			Element.create("Sound", { SoundId = bound }),
			Element.create("Sound", {}),
			Element.create("Sound", { SoundId = unset }),
		})
	)

	local cues: any = Root.mount(nil, Element.create("Sound", { SoundId = THIRD }))
	local gone: any = Root.mount(nil, Element.create("Sound", { SoundId = FOURTH }))
	gone:destroy()

	setBound(RETUNED)

	local ids: { string } = Root.ids({ cues, weapons, gone })
	local expected: { string } = { THIRD, FIRST, RETUNED }
	if #ids ~= #expected then
		return false, `ids gave {#ids} ids, not {#expected}: {table.concat(ids, ", ")}`
	end

	for index: number, id: string in expected do
		if ids[index] ~= id then
			return false, `ids gave {ids[index]} at {index}, not {id}`
		end
	end

	if #Root.ids({}) ~= 0 then
		return false, "ids of no roots gave ids"
	end

	local notRoots: { any } = { {}, "Weapons", { destroy = weapons.destroy } }
	for _, value: any in notRoots do
		local read: boolean, message: any = pcall(Root.ids, { weapons, value })
		if read or string.find(tostring(message), tostring(value), 1, true) == nil then
			return false, `ids took {value}, which is no root, or errored without naming it: {message}`
		end
	end

	return true, nil
end
