--[[
    The legacy template is an unparented, archivable Attachment holding one
    Sound, a clone's playable is the clone's own Sound, and a tree that is
    no clone of it is refused by name
--]]

--!strict
local Environment = require("../../../Environment")

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Legacy: any = env.require("Backends/Legacy")

	local template: any = Legacy.template()
	local children: { any } = template:GetChildren()
	if not template:IsA("Attachment") or template.Parent ~= nil or not template.Archivable then
		return false, "the template is not an unparented, archivable Attachment"
	elseif #children ~= 1 or not children[1]:IsA("Sound") or not children[1].Archivable then
		return false, `the template holds {#children} children, not one archivable Sound`
	end

	local copy: any = template:Clone()
	local sound: any = Legacy.playable(copy)
	if not sound or not sound:IsA("Sound") or sound.Parent ~= copy then
		return false, "a clone's playable is not the clone's own Sound"
	end

	local passed: boolean, message: any = pcall(Legacy.playable, env.Instance.new("Attachment"))
	if passed or not tostring(message):find("holds no Sound") then
		return false, `a bare Attachment was taken as a voice: {message}`
	end

	return true, nil
end
