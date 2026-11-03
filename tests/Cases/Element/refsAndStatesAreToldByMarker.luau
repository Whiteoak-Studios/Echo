--[[
    A sound tells a ref and a state only by their markers: a ref under any
    string key is kept as a ref, a state is bound to its property, and a
    table that only looks like a ref is a plain value
--]]

--!strict
local Environment = require("../../Environment")

local VOLUME: number = 0.5

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")

	local handle: any = Element.ref(nil)
	local other: any = Element.ref(nil)
	local state: any = { [Keys.State] = true, current = VOLUME }
	local lookalike: { current: number } = { current = VOLUME }

	local sound: any = Element.create("Sound", {
		Handle = handle,
		Volume = state,
		PlaybackRegion = lookalike,
		Name = other,
	})

	if #sound.refs ~= 2 or not table.find(sound.refs, handle) or not table.find(sound.refs, other) then
		return false, `a sound kept {#sound.refs} of its two refs`
	end

	if sound.properties.Handle ~= nil or sound.properties.Name ~= nil then
		return false, "a ref reached the sound's properties"
	end

	if sound.properties.Volume ~= state then
		return false, "a state was not bound to its property as itself"
	end

	if sound.properties.PlaybackRegion ~= lookalike then
		return false, "a table holding current with no marker was not taken as a plain value"
	end

	return true, nil
end
