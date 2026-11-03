--[[
    A component is called with the props it was given, and the element it
    returns comes back as it is, even another component's; anything else
    it returns is refused, naming what it was
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")

	local inner: any = nil
	local function Inner(props: any): any
		inner = Element.create("Sound", { SoundId = props.id })

		return inner
	end

	local function Outer(props: any): any
		return Element.create(Inner, props)
	end

	local props: { [string]: any } = { id = ID }
	local element: any = Element.create(Outer, props)
	if element ~= inner or element.properties.SoundId ~= ID then
		return false, "a component returning another component's element did not give back that element"
	end

	-- A list holding an element is no element either
	local returns: { { what: string, result: any } } = {
		{ what = "nil", result = nil },
		{ what = "string", result = "Sound" },
		{ what = "list", result = { inner } },
		{ what = "ref", result = Element.ref(inner) },
	}

	for _, returned: { what: string, result: any } in returns do
		local made: boolean, message: any = pcall(Element.create, function (): any
			return returned.result
		end)

		if made then
			return false, `a component's {returned.what} was taken as an element`
		elseif not tostring(message):find("A component returned", 1, true) then
			return false, `a component's {returned.what} was refused without naming the component: {message}`
		end
	end

	local _, named: any = pcall(Element.create, function (): any
		return "Sound"
	end)

	if not tostring(named):find("returned Sound", 1, true) then
		return false, `a component's string was refused without naming it: {named}`
	end

	return true, nil
end
