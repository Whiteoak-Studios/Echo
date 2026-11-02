--[[
    Players holds a LocalPlayer on the client, with the events 7.8.6's area
    tracker connects when it is required, and none on the server
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"

return function (): (boolean, string | nil)
	local client: Environment.Environment = Environment.new({ source = FIXTURE })
	local typeOf: (value: any) -> string = client.require().typeof
	local players: any = client.game:GetService("Players")
	local player: any = players.LocalPlayer

	if not player or not player:IsA("Player") or player.Parent ~= players then
		return false, "the client has no LocalPlayer inside Players"
	end

	local listed: { any } = players:GetPlayers()
	if #listed ~= 1 or listed[1] ~= player then
		return false, "GetPlayers did not list the LocalPlayer alone"
	end

	for _, event: any in
		{ player.CharacterAdded, player.CharacterRemoving, players.PlayerAdded, players.PlayerRemoving }
	do
		if typeOf(event) ~= "RBXScriptSignal" then
			return false, "a player or Players event is not an RBXScriptSignal"
		end
	end

	player.CharacterAdded:Connect(function () end)
	if client.connections(player.CharacterAdded) ~= 1 then
		return false, "a CharacterAdded connection was not counted"
	end

	if pcall(client.Instance.new, "Player") then
		return false, "Instance.new made a Player"
	end

	local server: Environment.Environment = Environment.new({ source = FIXTURE, client = false })
	local serverPlayers: any = server.game:GetService("Players")
	if serverPlayers.LocalPlayer ~= nil or #serverPlayers:GetPlayers() ~= 0 then
		return false, "the server has a LocalPlayer"
	end

	return true, nil
end
