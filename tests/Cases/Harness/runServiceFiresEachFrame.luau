--[[
    A step fires Heartbeat once a frame it covers, and RenderStepped too on
    the client only, and RunService answers the realm a case sets
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local FRAME_RATE: number = 60
local FRAME: number = 1 / FRAME_RATE
local SECOND: number = 1

return function (): (boolean, string | nil)
	local client: Environment.Environment = Environment.new({ source = FIXTURE })
	local runService: any = client.game:GetService("RunService")

	local heartbeats: { number } = {}
	runService.Heartbeat:Connect(function (delta: number)
		table.insert(heartbeats, delta)
	end)

	local rendered: number = 0
	runService.RenderStepped:Connect(function ()
		rendered += 1
	end)

	client.step(FRAME / 2)
	if #heartbeats ~= 0 then
		return false, "half a frame fired Heartbeat"
	end

	client.step(FRAME / 2)
	client.step(SECOND - FRAME)
	if #heartbeats ~= FRAME_RATE or rendered ~= FRAME_RATE or heartbeats[1] ~= FRAME then
		return false, `a second fired {#heartbeats} Heartbeats and {rendered} RenderSteppeds, not {FRAME_RATE} of each`
	end

	if client.connections(runService.Heartbeat) ~= 1 then
		return false, "env.connections did not count the one Heartbeat connection"
	end

	if not runService:IsClient() or runService:IsServer() or runService:IsStudio() then
		return false, "a default environment is not a live client"
	end

	local server: Environment.Environment = Environment.new({ source = FIXTURE, client = false, studio = true })
	local serverRunService: any = server.game:GetService("RunService")

	local serverRendered: number = 0
	serverRunService.RenderStepped:Connect(function ()
		serverRendered += 1
	end)

	server.step(SECOND)
	if serverRendered ~= 0 then
		return false, "RenderStepped fired on the server"
	end

	if serverRunService:IsClient() or not serverRunService:IsServer() or not serverRunService:IsStudio() then
		return false, "a server environment in Studio did not answer as one"
	end

	return true, nil
end
