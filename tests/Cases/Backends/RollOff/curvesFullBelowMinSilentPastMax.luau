--[[
    Every RollOffMode's curve is full at min, silent at max, follows the
    legacy formula between them, never rises, keeps to Constants.CURVE_POINTS
    and the engine's 400 points, and an emitter takes it
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../../Environment")

local MAX_POINTS: number = 400
local TOLERANCE: number = 1e-9

-- Min and max pairs: the legacy default, a min of 0, Frontier Zero's gunshot shape and a narrow band
local RANGES: { { number } } = { { 10, 10000 }, { 0, 50 }, { 28, 300 }, { 5, 5.5 } }

local function expected(mode: any, min: number, max: number, distance: number): number
	local linear: number = (max - distance) / (max - min)
	local modes: any = roblox.Enum.RollOffMode

	if mode == modes.Linear then
		return linear
	elseif mode == modes.LinearSquare then
		return linear ^ 2
	elseif mode == modes.InverseTapered then
		return math.min(min / distance, linear ^ 2)
	end

	return min / distance
end

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local RollOff: any = env.require("Backends/RollOff")
	local Constants: any = env.require("Constants")

	for _, mode: any in roblox.Enum.RollOffMode:GetEnumItems() do
		for _, range: { number } in RANGES do
			local min: number, max: number = range[1], range[2]
			local points: { [number]: number } = RollOff.points(mode, min, max)
			local name: string = `{mode.Name} from {min} to {max}`

			local distances: { number } = {}
			for distance: number in points do
				table.insert(distances, distance)
			end

			table.sort(distances)

			if #distances ~= Constants.CURVE_POINTS or #distances > MAX_POINTS then
				return false, `{name} has {#distances} points, not {Constants.CURVE_POINTS}`
			elseif distances[1] ~= min or points[min] ~= 1 then
				return false, `{name} does not start full at its min`
			elseif distances[#distances] ~= max or points[max] ~= 0 then
				return false, `{name} does not end silent at its max`
			end

			for index: number = 2, #distances - 1 do
				local distance: number = distances[index]
				local volume: number = points[distance]

				if math.abs(volume - expected(mode, min, max, distance)) > TOLERANCE then
					return false, `{name} gives {volume} at {distance}, off its formula`
				elseif volume > points[distances[index - 1]] or volume < 0 or volume > 1 then
					return false, `{name} rises or leaves 0 to 1 at {distance}`
				end
			end

			env.Instance.new("AudioEmitter"):SetDistanceAttenuation(points)
		end
	end

	return true, nil
end
