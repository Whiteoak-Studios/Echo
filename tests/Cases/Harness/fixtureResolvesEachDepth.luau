--[[
    A package's relative requires from its root, a file in it and a file in
    Backends each reach the one copy of the installed Promise and Cellar,
    mounted where a game installs them
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local root: any = env.require()
	local direct: any = env.require("Direct")
	local nested: any = env.require("Backends/Nested")

	if root.Direct ~= direct or root.Nested ~= nested then
		return false, "env.require ran a module the package had already required"
	end

	if direct.Promise ~= root.Promise or nested.Promise ~= root.Promise then
		return false, "a file reached another Promise than the package root did"
	end

	if direct.Cellar ~= root.Cellar or nested.Cellar ~= root.Cellar then
		return false, "a file reached another Cellar than the package root did"
	end

	if type(root.Promise.new) ~= "function" or type(root.Cellar.create) ~= "function" then
		return false, "Promise or Cellar is not the installed package"
	end

	local packages: any = env.game:GetService("ReplicatedStorage").Packages
	local echo: any? = packages:FindFirstChild("Echo")
	if not echo or not packages:FindFirstChild("Promise") or not packages:FindFirstChild("Cellar") then
		return false, "the package and its dependencies are not siblings in ReplicatedStorage.Packages"
	end

	if echo.ClassName ~= "ModuleScript" or echo.Backends.ClassName ~= "Folder" or not echo.Backends.Nested then
		return false, "the package is not mounted as Rojo maps it, a ModuleScript holding a Backends Folder"
	end

	if pcall(env.require, "Missing") then
		return false, "env.require gave a module for a path the package does not hold"
	end

	if pcall(function ()
		Environment.new({ source = "Missing" })
	end) then
		return false, "an environment was built over a fixture that does not exist"
	end

	return true, nil
end
