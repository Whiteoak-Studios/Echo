--[[
    The preload pass: each id it takes held on an idle AudioPlayer of its
    own in SoundService's Echo folder for as long as the client runs, and
    waited on until it turns ready or its wait ends
--]]

--!strict
local SoundService = game:GetService("SoundService")

local Promise: any = require(script.Parent.Parent.Promise)

local Constants = require(script.Parent.Constants)
local Element = require(script.Parent.Element)
local Legacy = require(script.Parent.Backends.Legacy)

-- Each id's holder by the id, never let go, since an id stays loaded only while something holds it
local Holders: { [string]: AudioPlayer } = {}

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
    The holder an earlier pass made for the id, or a new AudioPlayer named
    by the id and set to it in the folder. A holder is never wired or
    played, since holding the asset is all that keeps it loaded
--]]

local function holderOf(id: string, folder: Instance): AudioPlayer
	local known: AudioPlayer? = Holders[id]
	if known then
		return known
	end

	local holder: AudioPlayer = Instance.new("AudioPlayer")
	holder.Name = id
	holder.Asset = id
	holder.Parent = folder
	Holders[id] = holder

	return holder
end

--[[
    Calls done once: with true when the holder turns ready, at once when it
    already is, or with false when its wait ends first. Before done runs,
    the wait's connection is closed and its delay canceled or spent
--]]

local function whenReady(holder: AudioPlayer, done: (ready: boolean) -> ())
	if holder.IsReady then
		done(true)
		return
	end

	local connection: RBXScriptConnection
	local deadline: thread

	connection = holder:GetPropertyChangedSignal("IsReady"):Connect(function ()
		-- A handler that runs after the deadline ended the wait finds its connection closed
		if holder.IsReady and connection.Connected then
			connection:Disconnect()
			task.cancel(deadline)
			done(true)
		end
	end)

	-- An id that never loads reports neither ready nor failed, so its wait ends here
	deadline = task.delay(Constants.PRELOAD_WAIT, function ()
		connection:Disconnect()
		done(false)
	end)
end

--[[
    Holds the ids given first, then every SoundId recorded so far, then the
    ids given last, each once at its first place, making every holder before
    it waits on any. Resolves with the ids still not ready when their wait
    ended, in the order the pass took them, and never rejects

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

	-- A game may preload before configure, so the folder is found or made as the backends do
	Legacy.setup()
	local folder = SoundService:FindFirstChild(Constants.FOLDER_NAME) :: Instance

	local holders: { AudioPlayer } = {}
	for _, id: string in list do
		table.insert(holders, holderOf(id, folder))
	end

	return Promise.new(function (resolve: (failed: { string }) -> ())
		local ready: { [string]: boolean } = {}
		local waiting: number = #list

		local function settle(id: string, loaded: boolean)
			ready[id] = loaded
			waiting -= 1
			if waiting > 0 then
				return
			end

			local failed: { string } = {}
			for _, each: string in list do
				if not ready[each] then
					table.insert(failed, each)
				end
			end

			resolve(failed)
		end

		for index: number, id: string in list do
			whenReady(holders[index], function (loaded: boolean)
				settle(id, loaded)
			end)
		end
	end)
end

type Self = typeof(Preload)

return Preload
