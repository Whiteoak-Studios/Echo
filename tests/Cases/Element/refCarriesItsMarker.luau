--[[
    Element.ref gives a table holding its initial value in current and the
    ref marker, which Element.isRef reads and finds on nothing else
--]]

--!strict
local Environment = require("../../Environment")

local INITIAL: number = 1

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local ref: any = Element.ref(INITIAL)
	if ref.current ~= INITIAL or ref[Keys.Ref] ~= true or not Element.isRef(ref) then
		return false, "a ref does not hold its initial value with the ref marker"
	end

	if not Element.isRef(Element.ref(nil)) then
		return false, "a ref made with nil is not a ref"
	end

	local others: { [string]: any } = {
		lookalike = { current = INITIAL },
		state = { [Keys.State] = true, current = INITIAL },
		element = Element.create("Sound"),
		number = INITIAL,
		["function"] = function () end,
	}

	for what: string, value: any in others do
		if Element.isRef(value) then
			return false, `a {what} was taken for a ref`
		end
	end

	if Element.isRef(nil) then
		return false, "nil was taken for a ref"
	end

	return true, nil
end
