return function (sound: Sound, callback: () -> ())
    local connection: RBXScriptConnection
    connection = sound:GetPropertyChangedSignal("Playing"):Connect(function()
        callback(sound.Playing)
    end)

    -- Cleanup
    return function ()
        if connection then
            connection:Disconnect()
        end
    end
end