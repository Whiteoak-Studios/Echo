return function (sound: Sound, callback: () -> ())
    local connection: RBXScriptConnection
    connection = sound.Ended:Connect(function()
        callback()
    end)

    -- Cleanup
    return function ()
        if connection then
            connection:Disconnect()
        end
    end
end