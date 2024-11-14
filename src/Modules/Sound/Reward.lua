local Echo = require(script.Parent.Parent.Parent)

return function ()
    local playing, setPlaying = Echo.useState(false)

    -- `Reward` as name since that's the sound we want to make changes to, which is this sound element
    -- You can create multiple signals using the same name, and they will all be updated with just 1 call
    Echo.createSignal("PlayReward", function(state: boolean)
        setPlaying(state)
        return function ()
            -- You must manually perform your cleanup actions here
            -- Cleanup, will also break the subscription
        end
    end)

    Echo.useSignal("Footstep [Concrete]", workspace.Test, "2")

    return Echo.createElement("Sound", {
        SoundId = "rbxassetid://873617644",
        Volume = .25,
        -- Looped = true,
        Name = "Reward",
        Playing = playing,

        [Echo.Event.Ended] = function() -- Does not fire if `Looped` is enabled
            print "Sound ended"

            return function () -- Cleanup and disconnect connection
                
            end
        end
    }, {
        Distortion = Echo.createElement("DistortionSoundEffect", {
            Level = 0.25
        })
    })
end