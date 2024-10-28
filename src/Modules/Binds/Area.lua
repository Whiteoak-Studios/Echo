--[[
    Binds playing sound on enter, and stopping sound
    on leave - supports tweening
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Promise = require(Packages.Promise)

local ZoneModule = require(script.Parent.Parent.ZoneTracker)
ZoneModule.Settings.Heartbeat = 30
ZoneModule.Settings.FrontCenterPosition = true -- Caculates front hit geometry for faster detection

local RegisterdAreas: {[number]: string} = {}
local Promises: {[string]: typeof(Promise)} = {}

return function (props: {})
    local cframe: CFrame = props.cframe
    local size: Vector3 = props.size

    local zoneName: string = `Area{#RegisterdAreas + 1}`
    local zone = ZoneModule.addArea(zoneName, cframe, size)

    local function cancel()
        if Promises[zoneName] then
            Promises[zoneName]:cancel()
        end
    end

    zone.onEnter:Connect(function(player: Player)
        if props.enter then
            cancel()
            Promises[zoneName] = props.enter(player)
        end
    end)

    zone.onLeave:Connect(function(player: Player)
        if props.leave then
            cancel()
            Promises[zoneName] = props.leave(player)
        end
    end)
end