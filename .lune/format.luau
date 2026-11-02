--[[
    Formats every .luau file under the repo's roots with StyLua and then
    restores the space after the function keyword of anonymous functions,
    which StyLua removes and the house style requires
--]]

--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS: { string } = { "src", "tests", ".lune", "dev" }

-- Vendored and generated
local SKIPPED: { [string]: boolean } = { ["src/Modules/Libraries"] = true }

local files: { string } = {}

--[[
    Collects every .luau file under a directory, skipping the vendored and
    generated trees
--]]

local function collect(directory: string)
	for _, name: string in fs.readDir(directory) do
		local path: string = `{directory}/{name}`

		if SKIPPED[path] then
			continue
		end

		if fs.isDir(path) then
			collect(path)
		elseif name:match("%.luau$") then
			table.insert(files, path)
		end
	end
end

for _, root: string in ROOTS do
	if fs.isDir(root) then
		collect(root)
	end
end

-- Whiteoak TODO: one command line carries every path and caps out near a thousand files on Windows; batch it then
local result = process.exec("stylua", files, { stdio = "forward" })

if not result.ok then
	process.exit(result.code)
end

-- Only an anonymous function puts a parenthesis straight after the keyword, so the restore is safe
for _, path: string in files do
	local source: string = fs.readFile(path)
	local restored: string = source:gsub("%f[%w_]function%(", "function (")

	if restored ~= source then
		fs.writeFile(path, restored)
	end
end
