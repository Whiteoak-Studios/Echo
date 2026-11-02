--[[
    `lune run tests` runs every case under tests/Cases in path order and
    stops at the first failure; `lune run tests legacy` runs every twin under
    tests/Legacy and reports each. A path prefix after either narrows the run
--]]

--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")

local Environment = require("./tests/Environment")

local CASES: string = "tests/Cases"
local LEGACY: string = "tests/Legacy"
local LEGACY_FLAG: string = "legacy"
local CASE_FILE: string = "%.luau$"

type Case = {
	path: string,
	name: string, -- Its path below the root, without the extension
}

local Paths: { string } = {}

--[[
    Collects every case file under a directory
--]]

local function collect(directory: string)
	for _, name: string in fs.readDir(directory) do
		local path: string = `{directory}/{name}`

		if fs.isDir(path) then
			collect(path)
		elseif name:match(CASE_FILE) then
			table.insert(Paths, path)
		end
	end
end

--[[
    Loads one case file and runs it to the case contract, a failed require
    counting as the case's failure
--]]

local function run(case: Case): (boolean, string | nil)
	-- In an init.luau, ./ is the folder's parent, the repo root the runner runs from
	local loaded: boolean, result: any = pcall(require :: any, `./{(case.path:gsub(CASE_FILE, ""))}`)
	if not loaded then
		return false, `its require failed: {result}`
	end

	return Environment.run(result)
end

local legacy: boolean = process.args[1] == LEGACY_FLAG
local prefix: string? = process.args[1]
if legacy then
	prefix = process.args[2]
end

local root: string = legacy and LEGACY or CASES
if fs.isDir(root) then
	collect(root)
end

table.sort(Paths)

local cases: { Case } = {}
for _, path: string in Paths do
	local name: string = (path:sub(#root + 2):gsub(CASE_FILE, ""))
	if not prefix or name:sub(1, #prefix) == prefix then
		table.insert(cases, { path = path, name = name })
	end
end

if #cases == 0 then
	print(`No case under {root} starts with {prefix or "anything"}`)
	process.exit(1)
end

-- A twin is meant to fail on 7.8.6, so a legacy run reports every case where a normal run stops at the first failure
if legacy then
	local failed: number = 0
	for _, case: Case in cases do
		local passed: boolean, reason: string? = run(case)
		if passed then
			print(`Passed {case.name}`)
		else
			failed += 1
			print(`Failed {case.name}: {reason}`)
		end
	end

	print(`{#cases - failed} passed, {failed} failed`)
	if failed > 0 then
		process.exit(1)
	end
else
	for _, case: Case in cases do
		local passed: boolean, reason: string? = run(case)
		if not passed then
			print(`Failed {case.name}: {reason}`)
			process.exit(1)
		end
	end

	print(`{#cases} cases passed`)
end
