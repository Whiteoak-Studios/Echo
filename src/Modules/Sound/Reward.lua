local Echo = require(script.Parent.Parent.Parent)

return function ()
    return Echo.createElement("Sound", {
        SoundId = "rbxassetid://873617644",
        Volume = .25,
        Looped = true,
        Name = "Reward"
    }, {
        Distortion = Echo.createElement("DistortionSoundEffect", {
            Level = 0.25
        })
    })
end