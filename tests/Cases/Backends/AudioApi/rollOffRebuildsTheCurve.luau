--[[
    Each roll-off property rebuilds the emitter's curve from all three,
    starting from a legacy Sound's, whatever order they arrive in, and a
    min not yet below its max waits for the other end
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

local function sameCurve(first: { [number]: number }, second: { [number]: number }): boolean
	for distance: number, volume: number in first do
		if second[distance] ~= volume then
			return false
		end
	end

	for distance: number in second do
		if first[distance] == nil then
			return false
		end
	end

	return true
end

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local AudioApi: any = env.require("Backends/AudioApi")
	local RollOff: any = env.require("Backends/RollOff")
	local modes: any = roblox.Enum.RollOffMode

	local tree: any = AudioApi.template()
	local emitter: any = tree.AudioEmitter

	AudioApi.apply(tree, "RollOffMode", modes.Linear)
	if not sameCurve(emitter:GetDistanceAttenuation(), RollOff.points(modes.Linear, 10, 10000)) then
		return false, "a RollOffMode alone did not keep a legacy Sound's distances"
	end

	AudioApi.apply(tree, "RollOffMaxDistance", 300)
	AudioApi.apply(tree, "RollOffMinDistance", 28)
	if not sameCurve(emitter:GetDistanceAttenuation(), RollOff.points(modes.Linear, 28, 300)) then
		return false, "the curve is not Linear from 28 to 300 studs"
	end

	-- A min past the current max arrives before the max that clears it
	AudioApi.apply(tree, "RollOffMinDistance", 500)
	if not sameCurve(emitter:GetDistanceAttenuation(), RollOff.points(modes.Linear, 28, 300)) then
		return false, "a min past its max changed the curve before the max arrived"
	end

	AudioApi.apply(tree, "RollOffMaxDistance", 2000)
	AudioApi.apply(tree, "RollOffMode", modes.InverseTapered)
	if not sameCurve(emitter:GetDistanceAttenuation(), RollOff.points(modes.InverseTapered, 500, 2000)) then
		return false, "the curve is not InverseTapered from 500 to 2000 studs"
	end

	local bad: { { any } } = {
		{ "RollOffMinDistance", -5 },
		{ "RollOffMaxDistance", 0 / 0 },
		{ "RollOffMaxDistance", "far" },
	}

	for _, pair: { any } in bad do
		if AudioApi.apply(tree, pair[1], pair[2]) ~= false then
			return false, `apply took {pair[1]} = {pair[2]}`
		end
	end

	if
		#env.warnings ~= #bad
		or not sameCurve(emitter:GetDistanceAttenuation(), RollOff.points(modes.InverseTapered, 500, 2000))
	then
		return false, "a refused distance did not warn once, or changed the curve"
	end

	return true, nil
end
