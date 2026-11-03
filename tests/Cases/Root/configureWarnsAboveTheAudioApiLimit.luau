--[[
    Configure warns once when the Audio API pool can hold more voices than
    its soft limit, naming both, and fills the pool anyway; false silences
    it, and the Legacy pool never warns whatever its size
--]]

--!strict
local Environment = require("../../Environment")

local LIMIT: string = "150"
local SILENT: string = "may stay silent"
local SILENCE: string = "config.warnAudioApiLimit = false"

type Row = {
	config: { [string]: any },
	names: number?, -- The size the one warning names, or nil when nothing warns
}

-- A growing pool of 4 voices up to the ceiling given
local function sized(ceiling: number): { [string]: number }
	return { initial = 4, growAt = 2, growBy = 2, ceiling = ceiling }
end

return function (): (boolean, string | nil)
	local rows: { Row } = {
		{ config = { mode = "AudioApi", cache = { AudioApi = sized(151) } }, names = 151 },
		{ config = { mode = "AudioApi", cache = { AudioApi = sized(150) } }, names = nil },
		{ config = { mode = "AudioApi", cache = { AudioApi = sized(151) }, warnAudioApiLimit = false }, names = nil },
		{ config = { mode = "AudioApi", cache = { AudioApi = sized(151) }, warnAudioApiLimit = true }, names = 151 },
		{ config = { mode = "Legacy", cache = { Legacy = sized(400) } }, names = nil },
		{ config = { mode = "AudioApi", cache = { AudioApi = { initial = 200 } } }, names = 200 },
	}

	for index: number, row: Row in rows do
		-- Configure runs once per environment, so each row takes its own
		local env: Environment.Environment = Environment.new()
		local configured: boolean, message: any = pcall(env.require("Root").configure, row.config)
		if not configured then
			return false, `row {index} errored: {message}`
		end

		local mode: string = row.config.mode
		local initial: number = row.config.cache[mode].initial
		local size: number = env.require("Cache").count(mode).size

		if size ~= initial then
			return false, `row {index} filled {size} voices, not its initial {initial}`
		elseif row.names == nil and #env.warnings ~= 0 then
			return false, `row {index} warned: {env.warnings[1]}`
		elseif row.names == nil then
			continue
		elseif #env.warnings ~= 1 then
			return false, `row {index} warned {#env.warnings} times, not once`
		end

		for _, part: string in { `{row.names}`, LIMIT, SILENT, SILENCE } do
			if string.find(env.warnings[1], part, 1, true) == nil then
				return false, `row {index}'s warning does not name {part}: {env.warnings[1]}`
			end
		end
	end

	return true, nil
end
