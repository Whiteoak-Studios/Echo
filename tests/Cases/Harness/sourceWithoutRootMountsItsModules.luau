--[[
    A package with no init file mounts as a Folder, as Rojo maps it, its files
    at both depths still reach the installed Promise and Cellar, and a require
    of its root names the missing init file
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "NoRoot"
local MISSING: string = `{FIXTURE} has no init.luau` -- What a require of the root must name

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local direct: any = env.require("Direct")
	local nested: any = env.require("Backends/Nested")

	if direct.Promise ~= nested.Promise or direct.Cellar ~= nested.Cellar then
		return false, "the two depths reached different copies of Promise or Cellar"
	end

	if type(direct.Promise.new) ~= "function" or type(direct.Cellar.create) ~= "function" then
		return false, "Promise or Cellar is not the installed package"
	end

	local packages: any = env.game:GetService("ReplicatedStorage").Packages
	local echo: any? = packages:FindFirstChild("Echo")
	if not echo or echo.ClassName ~= "Folder" or echo.Backends.ClassName ~= "Folder" then
		return false, "the package is not mounted as a Folder holding a Backends Folder"
	end

	if not packages:FindFirstChild("Promise") or not packages:FindFirstChild("Cellar") then
		return false, "the package's dependencies are not its siblings in ReplicatedStorage.Packages"
	end

	local loaded: boolean, message: any = pcall(env.require, nil)
	if loaded or not tostring(message):find(MISSING, 1, true) then
		return false, `a require of the root did not name the missing init file: {message}`
	end

	return true, nil
end
