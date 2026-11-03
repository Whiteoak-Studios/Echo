--[[
    configure runs once and on the client only: a second call errors and
    leaves the first configuration standing, and a call on the server errors
    naming the client before it makes anything, so no root mounts after it
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local FIRST_SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local SECOND_SIZE: { [string]: number } = { initial = 6, growAt = 2, growBy = 2, ceiling = 8 }
local ONCE: string = "configure runs once"
local CLIENT: string = "client only"
local BEFORE: string = "configure must run before the first root"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Echo: any = env.require()

	Echo.configure({ mode = "Legacy", cache = { Legacy = FIRST_SIZE } })

	local again: boolean, message: any = pcall(Echo.configure, { mode = "Legacy", cache = { Legacy = SECOND_SIZE } })
	if again or string.find(tostring(message), ONCE, 1, true) == nil then
		return false, `a second configure did not error saying configure runs once: {message}`
	elseif Echo.getCache().size ~= FIRST_SIZE.initial then
		return false, `a refused second configure left the pool at {Echo.getCache().size} voices, not the first's`
	end

	local server: Environment.Environment = Environment.new({ client = false })
	local ServerEcho: any = server.require()
	local instances: number = #server.game:GetDescendants()

	local configured: boolean, serverMessage: any = pcall(ServerEcho.configure, {
		mode = "Legacy",
		cache = { Legacy = FIRST_SIZE },
	})

	if configured or string.find(tostring(serverMessage), CLIENT, 1, true) == nil then
		return false, `configure on the server did not error saying Echo runs on the client only: {serverMessage}`
	end

	local made: number = #server.game:GetDescendants() - instances
	if made ~= 0 then
		return false, `a refused configure on the server still made {made} instances`
	end

	local mounted: boolean, mountMessage: any =
		pcall(ServerEcho.root, ServerEcho, nil, ServerEcho.createElement("Sound", { SoundId = ID }))
	if mounted or string.find(tostring(mountMessage), BEFORE, 1, true) == nil then
		return false, `a root after a refused configure did not error saying configure runs first: {mountMessage}`
	end

	return true, nil
end
