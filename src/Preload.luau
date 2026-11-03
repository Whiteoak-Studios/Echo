--[[
    The one preload pass: the ids given first, then every SoundId Echo has
    recorded, then the ids given last, each once, in one PreloadAsync call
--]]

--!strict
local ContentProvider = game:GetService("ContentProvider")

local Promise: any = require(script.Parent.Parent.Promise)

local Element = require(script.Parent.Element)

local Preload = {}

--[[
    Refuses a list that is no table, or an entry in one that is no string,
    naming the argument and the entry, at the call that handed it over
--]]

local function check(argument: string, list: any)
	if list == nil then
		return
	elseif type(list) ~= "table" then
		error(`Echo: preload's {argument} is a list of ids, not {typeof(list)}`, 3)
	end

	for key: any, id: any in list do
		if type(id) ~= "string" then
			error(`Echo: preload's {argument}[{key}] is {typeof(id)}, where every entry is an id string`, 3)
		end
	end
end

--[[
    Preloads the ids given first, then every SoundId recorded so far, then
    the ids given last, each once at its first place, in one PreloadAsync
    call. Resolves with the ids that did not load, in the order the pass
    took them, so one asset that fails never fails or stalls the pass, and
    rejects only when PreloadAsync itself throws

    @ first | the ids that load ahead of the recorded ones, such as a priority root's
    @ ids | the ids that load after them, such as the takes a game plays only as overrides
--]]

function Preload.run(first: { string }?, ids: { string }?): any
	check("first", first)
	check("ids", ids)

	local list: { string } = {}
	local listed: { [string]: boolean } = {}

	for _, group: { string } in { first or {}, Element.ids(), ids or {} } do
		for _, id: string in group do
			-- An empty SoundId names no asset, so it never joins the pass
			if id ~= "" and not listed[id] then
				listed[id] = true
				table.insert(list, id)
			end
		end
	end

	if #list == 0 then
		return Promise.resolve({})
	end

	return Promise.new(function (resolve: (failed: { string }) -> (), reject: (message: any) -> ())
		local statuses: { [string]: Enum.AssetFetchStatus } = {}
		local function report(id: string, status: Enum.AssetFetchStatus)
			statuses[id] = status
		end

		local ran: boolean, message: any = pcall(function ()
			ContentProvider:PreloadAsync(list, report)
		end)
		if not ran then
			return reject(message)
		end

		-- An id the pass never reported has no Success to show, so it counts as failed
		local failed: { string } = {}
		for _, id: string in list do
			if statuses[id] ~= Enum.AssetFetchStatus.Success then
				table.insert(failed, id)
			end
		end

		resolve(failed)
	end)
end

type Self = typeof(Preload)

return Preload
