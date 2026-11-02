--[[
    A file in the fixture package's Backends folder, the deepest a file in
    src/ sits, which reaches a dependency three Parents up
--]]

--!strict
local Cellar = require(script.Parent.Parent.Parent.Cellar)
local Promise: any = require(script.Parent.Parent.Parent.Promise)

return {
	Cellar = Cellar,
	Promise = Promise,
}
