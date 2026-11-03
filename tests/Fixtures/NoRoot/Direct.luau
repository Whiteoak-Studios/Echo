--[[
    A file directly in a fixture package with no init file, which reaches a
    dependency two Parents up through the package's Folder
--]]

--!strict
local Cellar = require(script.Parent.Parent.Cellar)
local Promise: any = require(script.Parent.Parent.Promise)

return {
	Cellar = Cellar,
	Promise = Promise,
}
