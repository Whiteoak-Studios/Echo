--[[
    `lune run legacy` exports 7.8.6's src folder, read from its commit, into
    the gitignored .legacy/src file for file, replacing what was there
--]]

--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")

local REF: string = "606a8ec62cb025c1bb89a9cbfd9c86b24c159b20"
local SOURCE: string = "src"
local TARGET: string = `.legacy/{SOURCE}`

--[[
    Runs git and gives what it printed, stopping the export on any failure
--]]

local function git(arguments: { string }): string
	local result = process.exec("git", arguments)
	if not result.ok then
		print(`git {table.concat(arguments, " ")} failed: {result.stderr}`)
		process.exit(1)
	end

	return result.stdout
end

local listing: string = git({ "ls-tree", "-r", "--name-only", REF, SOURCE })

if fs.isDir(TARGET) then
	fs.removeDir(TARGET)
end

local count: number = 0
for path: string in listing:gmatch("[^\n]+") do
	local folder: string? = path:match("^(.*)/[^/]+$")
	if folder then
		fs.writeDir(`.legacy/{folder}`)
	end

	fs.writeFile(`.legacy/{path}`, git({ "show", `{REF}:{path}` }))
	count += 1
end

if count == 0 then
	print(`{REF} holds no {SOURCE} folder to export`)
	process.exit(1)
end

print(`Exported {count} files from {REF}:{SOURCE} into {TARGET}`)
