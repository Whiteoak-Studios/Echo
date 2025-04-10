--[[
    This is an example for how you can create a sound object
    and play it whenever a player enters a zone. It follows a very
    similar apporach to React, using the same naming conventions.
    However, unlike React which re-renders the function every state change,
    Echo does not.

    Echo works by setting a state or binding (which are all callbacks internally)
    to a specific property, which will update only that property whenever the callback
    is fired. Refer to the official documentation for more information on how to use

    # States -------------------------------------

    ```lua
    local volume, setVolume = Echo.useState(0) -- Pass the initial value you want the property to be

    task.delay(2, function()
        setVolume(.5) -- Changes the volume from 0 to .5
    end)

    -- Example
    Distortion = Echo.createElement("DistortionSoundEffect", {
        Level = volume
    })
    ```

    If you however want to gradually increase a property (numbers only),
    you would create a spring like such:

    # Springs -------------------------------------

    ```lua
    local styles, api = Echo.useSpring(function() -- Styles is the value that is changed, api is the function that changes it
        return {
            volume = 0,
            rollOfDistance = 10,

            config = {
                duration = 5,
                delay = 0 -- If you want to delay the effect
            }
        }
    end)

    -- Start the spring, which will gradually increase the volume from 0 to .25 over 5 seconds
    api:start({
        volume = .25,
        rollOfDistance = 100000,
    })
    
    return Echo.createElement("Sound", {
        SoundId = "rbxassetid://17612500198",
        Looped = true,
        Name = "Arctic",
        Volume = styles.volume, -- Set volume to the current value of the spring binded to
    })
    ```

    # Binds

    Bind a connection to play the sound whenver the player enters an area,
    and stop playing it when the player leaves.

    ```lua
    Echo.createBinding(Echo.Bind.Area, function() -- Type of bind (Area only as of right now)
        return {
            cframe = CFrame.new(0, 0, 0), -- Position of the area
            size = Vector3.new(15, 15, 15), -- Range / size of the area

            enter = function(player: Player) -- What to do when the player enters the area
                setPlaying(true)

                -- api:start() returns a promise, return that promise if you want to cancel the promise
                -- upon leaving, while still lerping
                return api:start({
                    volume = .25, -- The new values that are being lerped to
                    rollOfDistance = 100000,
                })
            end,

            -- Must return the promise returned from the spring if we want to cancel promise
            leave = function(player: Player)
                return api:start({ -- Again returns a promise, just like on enter
                    volume = 0,
                    rollOfDistance = 10
                })
                -- Since it returns a promise and is resolved once finished, we can
                -- perform actions after it's finished.
                :andThen(function()
                    setPlaying(false)
                    setTimePosition(0)
                end)
            end
        }
    end)
    ```

    Official Documentation: https://github.com/Whiteoak-Studios/Echo/blob/main/README.md
--]]

local Echo = require(script.Parent.Parent.Parent)

return function ()
    local timePosition, setTimePosition = Echo.useState(0)
    local playing, setPlaying = Echo.useState(true)

    local styles, api = Echo.useSpring(function()
        return {
            volume = 0,
            rollOfDistance = 10,

            config = {
                duration = 5,
                delay = 2,
            }
        }
    end)

    Echo.createSignal("Artic", function()
        print "called!"
    end)

    -- Create a binding that will play the sound once the player enters a area
    -- And stops playing as they leave that area
    Echo.createBinding(Echo.Bind.Area, function()
        return {
            cframe = CFrame.new(0, 0, 0),
            size = Vector3.new(15, 15, 15),

            enter = function(player: Player)
                setPlaying(true)
                return api:start({
                    volume = .25,
                    rollOfDistance = 100000,
                })
            end,

            -- Must return the promise returned from the spring if we want to cancel promise
            leave = function(player: Player)
                return api:start({
                    volume = 0,
                    rollOfDistance = 10
                }):
                andThen(function()
                    setPlaying(false)
                    setTimePosition(0)
                end)
            end
        }
    end)

    -- Fire the signal which is connected to a sound element, that sound element is `Reward`
    -- Pass any arguments you may need
    Echo.useSignal("PlayReward", true)

    return Echo.createElement("Sound", {
        SoundId = "rbxassetid://17612500198",
        Looped = true,
        Name = "Arctic",
        Volume = styles.volume,
        RollOffMaxDistance = styles.rollOfDistance,
        Playing = playing,
        TimePosition = timePosition,

        [Echo.Event.Loaded] = function() -- Does not fire if `Looped` is enabled
            print "Sound Loaded"

            return function () -- Cleanup and disconnect connection
                -- Always provide a cleanup for one time events like this!
            end
        end
    }, {
        Distortion = Echo.createElement("DistortionSoundEffect", {
            Level = styles.volume -- Even works on children components!
        })
    })
end