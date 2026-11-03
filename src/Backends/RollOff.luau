--[[
    The distance curve an Audio API voice's emitter takes in place of a
    legacy Sound's RollOffMode, as points from distance to volume
--]]

--!strict
local Constants = require(script.Parent.Parent.Constants)

local RollOff = {}

--[[
    The volume a legacy Sound's mode gives at a distance between its two
    roll-off distances
--]]

local function volume(mode: Enum.RollOffMode, min: number, max: number, distance: number): number
	local linear: number = (max - distance) / (max - min)

	if mode == Enum.RollOffMode.Linear then
		return linear
	elseif mode == Enum.RollOffMode.LinearSquare then
		return linear * linear
	elseif mode == Enum.RollOffMode.InverseTapered then
		return math.min(min / distance, linear * linear)
	end

	return min / distance
end

--[[
    Samples a RollOffMode from full at min to silent at max. The engine
    holds each end's volume past it, so the curve stays full below min and
    silent past max
--]]

function RollOff.points(mode: Enum.RollOffMode, min: number, max: number): { [number]: number }
	assert(min >= 0 and min < math.huge, `RollOff.points takes a min distance of 0 or more studs, not {min}`)
	assert(max > min and max < math.huge, `RollOff.points takes a max distance past its min of {min}, not {max}`)

	local points: { [number]: number } = { [min] = 1, [max] = 0 }
	local last: number = Constants.CURVE_POINTS - 1
	local ratio: number = (max + 1) / (min + 1)

	for index: number = 1, last - 1 do
		-- Samples crowd toward min, where the inverse modes fall fastest, and the 1 spaces a min of 0 too
		local distance: number = (min + 1) * ratio ^ (index / last) - 1

		if distance > min and distance < max then
			points[distance] = volume(mode, min, max, distance)
		end
	end

	return points
end

return RollOff
