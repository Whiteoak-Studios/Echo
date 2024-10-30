local Echo = require(script.Parent.Parent.Parent)

return function ()
    -- `Reward` as name since that's the sound we want to make changes to, which is this sound element
    -- You can create multiple signals using the same name, and they will all be updated with just 1 call
    Echo.createSignal("PlayReward", function(state: boolean)
        return function ()
            -- You must manually perform your cleanup actions here
            -- Cleanup, will also break the subscription
        end
    end)

    return Echo.createElement("Sound", {
        SoundId = "rbxassetid://873617644",
        Volume = .25,
        Looped = true,
        Name = "Spinneroo!", -- Name of sound element being created, does not have to the same as signal!
        
        [Echo.Event.Looped] = function(id: string, count: number) -- Only connect if sound is or will be set to looped
            print(`Sound looped with a total of {count} loops.`)
            if count > 2 then
                return function ()
                    print ("Stopping sound")
                end
            end
        end,

        [Echo.Event.Playing] = function(state: boolean)
            if state then
                print "Sound is playing!"
            else
                print "Sound is not playing!"
            end
        end
    }, {
        Distortion = Echo.createElement("DistortionSoundEffect", {
            Level = 0.25
        })
    })
end