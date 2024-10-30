return function (sound: Sound, callback: () -> ())
    if sound.IsLoaded then
        return
    end

    local connection: RBXScriptConnection
    connection = sound.Loaded:Connect(function()
        callback()
    end)

    -- Cleanup
    return function ()
        if connection then
            connection:Disconnect()
        end
    end
end