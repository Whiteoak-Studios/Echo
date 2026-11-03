--[[
    A file in the Backends folder of a fixture package with no init file,
    which reaches a dependency three Parents up
--]]

--!strict
local Cellar = require(script.Parent.Parent.Parent.Cellar)
local Promise: any = require(script.Parent.Parent.Parent.Promise)

return {
	Cellar = Cellar,
	Promise = Promise,
}
