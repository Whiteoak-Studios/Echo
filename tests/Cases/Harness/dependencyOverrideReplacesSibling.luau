--[[
    A case's own table stands in for a dependency at every depth of one
    environment only, and can stand in for a sibling the package lacks
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"

return function (): (boolean, string | nil)
	-- A counting stand-in records every member the package reads off it
	local reads: { string } = {}
	local counting: any = setmetatable({}, {
		__index = function (_: any, key: string): any
			table.insert(reads, key)
			return nil
		end,
	})

	local env: Environment.Environment = Environment.new({ source = FIXTURE, dependencies = { Promise = counting } })
	local root: any = env.require()

	if root.Promise ~= counting or root.Direct.Promise ~= counting or root.Nested.Promise ~= counting then
		return false, "a file reached the installed Promise past the override"
	end

	if type(root.Cellar.create) ~= "function" then
		return false, "the override replaced Cellar as well as Promise"
	end

	local _ = root.Promise.new
	if #reads ~= 1 or reads[1] ~= "new" then
		return false, `the stand-in counted {#reads} reads`
	end

	if Environment.new({ source = FIXTURE }).require().Promise == counting then
		return false, "the override reached a second environment"
	end

	local extra: Environment.Environment = Environment.new({ source = FIXTURE, dependencies = { Sift = {} } })
	local packages: any = extra.game:GetService("ReplicatedStorage").Packages
	if not packages:FindFirstChild("Sift") then
		return false, "an override for a sibling the package lacks mounted nothing"
	end

	return true, nil
end
