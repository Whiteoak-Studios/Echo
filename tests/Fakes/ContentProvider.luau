--[[
    The fake ContentProvider, whose PreloadAsync records the ids of every
    call, refuses an id passed as a bare string as the engine refuses every
    audio id, and reports an instance's ids with the status a case gives each
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Instance = require("./Instance")

type Spec = Instance.Spec
type World = Instance.World

local ContentProvider = {}

-- An instance stands for every asset it and its descendants name, as the engine preloads them
local function addIds(instance: any, ids: { string })
	local all: { any } = instance:GetDescendants()
	table.insert(all, 1, instance)

	for _, each: any in all do
		local id: string = ""
		if each:IsA("Sound") then
			id = each.SoundId
		elseif each:IsA("AudioPlayer") then
			id = each.Asset
		end

		if id ~= "" then
			table.insert(ids, id)
		end
	end
end

function ContentProvider.classes(world: World): { [string]: Spec }
	return {
		ContentProvider = {
			methods = {
				PreloadAsync = function (_: any, list: any, callback: ((id: string, status: any) -> ())?)
					local preload: Instance.Preload = world.settings.preload

					if world.type(list) ~= "table" then
						error(`Unable to cast {world.typeof(list)} to Array`, 2)
					elseif preload.error then
						error(preload.error, 2)
					end

					-- Whiteoak TODO: the call answers at once; park it on the clock once a case needs a preload still running
					local ids: { string } = {}
					local bare: { [number]: boolean } = {} -- The places in ids of the ones passed as strings
					for _, item: any in list do
						if world.is(item) then
							addIds(item, ids)
						elseif type(item) == "string" then
							table.insert(ids, item)
							bare[#ids] = true
						end
					end

					table.insert(preload.calls, ids)

					for index: number, id: string in ids do
						local status: any = preload.statuses[id] or roblox.Enum.AssetFetchStatus.Success
						if bare[index] then
							status = roblox.Enum.AssetFetchStatus.Failure
						end

						if callback then
							callback(id, status)
						end
					end
				end,
			},
		},
	}
end

return ContentProvider
