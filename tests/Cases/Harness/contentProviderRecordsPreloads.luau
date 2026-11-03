--[[
    PreloadAsync records the ids of every call, reports an id passed as a
    bare string as failed and an instance's ids with the status a case
    gives each, and throws the error a case sets
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local FIRST_ID: string = "rbxassetid://1"
local SECOND_ID: string = "rbxassetid://2"
local THIRD_ID: string = "rbxassetid://3"
local FAILURE: string = "Preload failed"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local Enum: any = env.require().Enum
	local content: any = env.game:GetService("ContentProvider")

	local sound: any = env.Instance.new("Sound")
	sound.SoundId = SECOND_ID
	local folder: any = env.Instance.new("Folder")
	local inner: any = env.Instance.new("Sound")
	inner.SoundId = THIRD_ID
	inner.Parent = folder

	env.preload.statuses[SECOND_ID] = Enum.AssetFetchStatus.Failure

	local reported: { [string]: any } = {}
	content:PreloadAsync({ FIRST_ID, sound, folder }, function (id: string, status: any)
		reported[id] = status
	end)

	local call: { string } = env.preload.calls[1]
	if #env.preload.calls ~= 1 or call[1] ~= FIRST_ID or call[2] ~= SECOND_ID or call[3] ~= THIRD_ID then
		return false, "PreloadAsync did not record the ids of a string, a Sound and a Sound inside a Folder"
	end

	-- The engine refuses every audio id passed as a bare string
	local failure: any = Enum.AssetFetchStatus.Failure
	if
		reported[FIRST_ID] ~= failure
		or reported[SECOND_ID] ~= failure
		or reported[THIRD_ID] ~= Enum.AssetFetchStatus.Success
	then
		return false, "the callback did not report the bare id as failed and each instance's id with its status"
	end

	content:PreloadAsync({ FIRST_ID })
	if #env.preload.calls ~= 2 then
		return false, "a PreloadAsync with no callback was not recorded"
	end

	env.preload.error = FAILURE
	local threw: boolean, message: any = pcall(content.PreloadAsync, content, { FIRST_ID })
	if threw or not tostring(message):find(FAILURE, 1, true) then
		return false, "PreloadAsync did not throw the error the case set"
	end

	env.preload.error = nil
	if pcall(content.PreloadAsync, content, FIRST_ID) then
		return false, "PreloadAsync took an id that is not in a list"
	end

	return true, nil
end
