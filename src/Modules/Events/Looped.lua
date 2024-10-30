return function (sound: Sound, callback: () -> ())
    local connection: RBXScriptConnection
    connection = sound.DidLoop:Connect(function(id: string, count: number)
        callback(id, count)
    end)

    -- Cleanup
    return function ()
        if connection then
            connection:Disconnect()
        end
    end
end