local Echo = require(script.Parent.Parent.Parent)

return function ()
    local playing, setPlaying = Echo.useState(false)

    -- `Reward` as name since that's the sound we want to make changes to, which is this sound element
    -- You can create multiple signals using the same name, and they will all be updated with just 1 call
    Echo.createSignal("Play Reward", function(state: boolean)
        setPlaying(state)

        return function ()
            -- You must manually perform your cleanup actions here
            -- Cleanup, will also break the subscription
        end
    end)

    return Echo.createElement("Sound", {
        SoundId = "rbxassetid://873617644",
        Volume = .25,
        Looped = true,
        Name = "Reward",
        Playing = playing
    }, {
        Distortion = Echo.createElement("DistortionSoundEffect", {
            Level = 0.25
        })
    })
end