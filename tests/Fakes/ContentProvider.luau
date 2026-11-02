--[[
    The fake ContentProvider, whose PreloadAsync records the ids of every
    call and reports each with the status a case gives it
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
					for _, item: any in list do
						if world.is(item) then
							addIds(item, ids)
						elseif type(item) == "string" then
							table.insert(ids, item)
						end
					end

					table.insert(preload.calls, ids)

					for _, id: string in ids do
						if callback then
							callback(id, preload.statuses[id] or roblox.Enum.AssetFetchStatus.Success)
						end
					end
				end,
			},
		},
	}
end

return ContentProvider
