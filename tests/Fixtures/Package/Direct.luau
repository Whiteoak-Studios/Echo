--[[
    A file directly in the fixture package, which reaches a dependency two
    Parents up and keeps a count that shows whether module state leaks
--]]

--!strict
local Cellar = require(script.Parent.Parent.Cellar)
local Promise: any = require(script.Parent.Parent.Promise)

local Direct = {
	Cellar = Cellar,
	Promise = Promise,
	_calls = 0, -- How many times count ran in this environment
}

--[[
    Counts one more call and gives the count so far
--]]

function Direct.count(self: Self): number
	self._calls += 1

	return self._calls
end

type Self = typeof(Direct)

return Direct
