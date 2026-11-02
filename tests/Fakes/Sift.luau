--[[
    The one Sift call 7.8.6 makes, Array.is, mounted beside the legacy
    source where it requires Sift, since 8.0.0 depends on no Sift
--]]

--!strict
local Array = {}

--[[
    Whether a value is a table holding a list and nothing else
--]]

function Array.is(object: any): boolean
	return typeof(object) == "table" and #object > 0 and next(object, #object) == nil
end

return {
	Array = Array,
}
