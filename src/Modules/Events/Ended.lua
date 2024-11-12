return function (sound: Sound, callback: () -> ())
    local connection1: RBXScriptConnection
    local connection2: RBXScriptConnection

    connection1 = sound.Ended:Connect(function()
        callback()
    end)

    connection2 = sound:GetPropertyChangedSignal("Playing"):Connect(function()
        if not sound.Playing then
            callback()
        end
    end)

    -- Cleanup
    return function ()
        if connection1 then
            connection1:Disconnect()
        end

        if connection2 then
            connection2:Disconnect()
        end
    end
end