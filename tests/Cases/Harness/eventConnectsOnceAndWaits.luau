--[[
    A fake event connects, connects once and waits; a connection made during
    a fire runs from the next one, a disconnect twice is safe, and a handler
    that throws is kept in env.errors while the others still run
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = "Package"
local BROKEN: string = "broken handler"

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new({ source = FIXTURE })
	local package: any = env.require()
	local folder: any = env.Instance.new("Folder")
	local added: any = folder.ChildAdded

	if package.typeof(added) ~= "RBXScriptSignal" or package.type(added) ~= "userdata" then
		return false, `an event's typeof is {package.typeof(added)} and its type {package.type(added)}`
	end

	local function addChild(name: string): any
		local child: any = env.Instance.new("Folder")
		child.Name = name
		child.Parent = folder

		return child
	end

	local seen: { string } = {}
	local connection: any = added:Connect(function (child: any)
		table.insert(seen, child.Name)
	end)

	if package.typeof(connection) ~= "RBXScriptConnection" or not connection.Connected then
		return false, "Connect gave no live RBXScriptConnection"
	end

	local once: number = 0
	added:Once(function ()
		once += 1
	end)

	local late: number = 0
	added:Once(function ()
		added:Connect(function ()
			late += 1
		end)
	end)

	local broken: any = added:Connect(function ()
		error(BROKEN)
	end)

	if env.connections(added) ~= 4 then
		return false, `env.connections counted {env.connections(added)} of 4`
	end

	addChild("First")
	if seen[1] ~= "First" or once ~= 1 or late ~= 0 then
		return false, "the first fire did not run each handler connected before it, and only those"
	end

	if #env.errors ~= 1 or not env.errors[1]:find(BROKEN, 1, true) then
		return false, "a throwing handler's error was not kept in env.errors"
	end

	-- The error was expected, so the case clears it, or Environment.run fails the case for leaving it
	broken:Disconnect()
	table.clear(env.errors)

	addChild("Second")
	if seen[2] ~= "Second" or once ~= 1 or late ~= 1 then
		return false, "a Once handler ran twice, or one connected during a fire missed the next"
	end

	connection:Disconnect()
	connection:Disconnect()
	if connection.Connected then
		return false, "a connection stayed connected after Disconnect"
	end

	addChild("Third")
	if #seen ~= 2 then
		return false, "a disconnected handler ran"
	end

	local waited: any = nil
	env.task.spawn(function ()
		waited = added:Wait()
	end)

	local fourth: any = addChild("Fourth")
	if waited ~= fourth then
		return false, "Wait did not resume with what the event fired"
	end

	-- An event with nothing connected fires without a word
	local lonely: any = env.Instance.new("Folder")
	local _ = lonely.ChildAdded
	env.Instance.new("Folder").Parent = lonely

	if pcall(added.Connect, added, "not a function") then
		return false, "Connect took something that is not a function"
	end

	return true, nil
end
