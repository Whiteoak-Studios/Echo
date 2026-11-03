--[[
    Configure refuses every value it cannot use, naming its field, before it
    sets anything up, so a good configuration still takes after them all
--]]

--!strict
local Environment = require("../../Environment")

local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

type Refusal = {
	config: any,
	names: string, -- What the error must name
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local group: any = env.Instance.new("SoundGroup")
	local folder: any = env.Instance.new("Folder")

	-- The good size with some fields changed
	local function sized(fields: { [string]: any }): { [string]: any }
		local size: { [string]: any } = table.clone(SIZE)
		for field: string, value: any in fields do
			size[field] = value
		end

		return size
	end

	local function with(fields: { [string]: any }): { [string]: any }
		local config: { [string]: any } = { mode = "Legacy", cache = { Legacy = SIZE } }
		for field: string, value: any in fields do
			config[field] = value
		end

		return config
	end

	local refusals: { Refusal } = {
		{ config = "Legacy", names = "configure takes a table" },
		{ config = with({ volume = 1 }), names = "config.volume" },
		{ config = { mode = "Legacy" }, names = "config.cache" },
		{ config = { mode = "Legacy", cache = { Classic = SIZE } }, names = "config.cache.Classic" },
		{ config = { mode = "Legacy", cache = { Legacy = 300 } }, names = "config.cache.Legacy" },
		{ config = with({ cache = { Legacy = sized({ initial = 0 }) } }), names = "config.cache.Legacy.initial" },
		{ config = with({ cache = { Legacy = sized({ growBy = 1.5 }) } }), names = "config.cache.Legacy.growBy" },
		{ config = with({ cache = { Legacy = sized({ ceiling = "8" }) } }), names = "config.cache.Legacy.ceiling" },
		{ config = with({ cache = { Legacy = sized({ growAt = 5 }) } }), names = "config.cache.Legacy.growAt" },
		{ config = with({ cache = { Legacy = sized({ ceiling = 3 }) } }), names = "config.cache.Legacy.ceiling" },
		{ config = with({ mode = "Classic" }), names = "config.mode" },
		{ config = with({ mode = "AudioApi" }), names = "config.mode" },
		{ config = with({ caps = 12 }), names = "config.caps" },
		{ config = with({ caps = { 12 } }), names = "config.caps" },
		{ config = with({ caps = { Gun = 0 } }), names = `config.caps["Gun"]` },
		{ config = with({ caps = { Gun = 1.5 } }), names = `config.caps["Gun"]` },
		{ config = with({ buses = "Effects" }), names = "config.buses" },
		{ config = with({ buses = { Effects = 1 } }), names = "config.buses.Effects" },
		{ config = with({ buses = { Effects = { group = folder } } }), names = "config.buses.Effects.group" },
		{ config = with({ buses = { Effects = { fader = group } } }), names = "config.buses.Effects.fader" },
		{
			config = with({ buses = { Effects = { interactionGroup = 1 } } }),
			names = "config.buses.Effects.interactionGroup",
		},
	}

	for index: number, refusal: Refusal in refusals do
		local configured: boolean, message: any = pcall(Root.configure, refusal.config)
		if configured then
			return false, `refusal {index} was taken`
		elseif string.find(tostring(message), refusal.names, 1, true) == nil then
			return false, `refusal {index} errored without naming {refusal.names}: {message}`
		end
	end

	local sound: any = env.game:GetService("SoundService")
	if sound:FindFirstChild("Echo") or #env.game.Workspace.Terrain:GetChildren() ~= 0 then
		return false, "a refused configuration set a backend up or filled a pool"
	end

	local good: { [string]: any } = with({
		caps = { Gun = 1 },
		buses = { Effects = { group = group, interactionGroup = "Effects" } },
	})

	local configured: boolean, message: any = pcall(Root.configure, good)
	if not configured then
		return false, `a good configuration after every refusal errored: {message}`
	end

	return true, nil
end
