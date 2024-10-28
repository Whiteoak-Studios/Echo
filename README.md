## Setup (Roblox)
1. Set up a Wally project.
2. Add Echo as a dependency in your `Wally.toml` file.
3. Run `wally install`.

🎉 Congratulations! You've installed Echo.

# Usage

### Root

```lua
--[[
    The root is the sound(s) are going to be parented and stored within.
    If you want to have multiple sounds within the same root, create a fragment,
    which will return a table of all sound elements to be added into the root.

    You can also choose where the root is parented into, instead of having Echo
    create a new folder to store the sound within. An example of this would be to
    store the sound within a part.

    @Param parent: Folder | table | nil
    @Param elements: Sound elements being created

    Note: If no parent is not provided, a new folder will also be created - will
    not error. Example:

    ```lua
    -- Works the exact same way with fragments
    Echo:root(workspace, Echo.createElement(Arctic)) -- Parents into workspace
    Echo:root(Echo.createElement(Arctic)) -- Parents into a new folder
    Echo:root(nil, Echo.createElement(Arctic)) -- Parents into a new folder because parent is nil
    Echo:root("Combat", Echo.createElement(Arctic)) -- Parents into a new folder with the name "Combat"
    ```
--]]

-- Creates 2 sound elements
Echo:root(workspace, Echo.createElement(Echo.Fragment, {
    Reward,
    Arctic,
}))

-- Creates only 1 sound element
Echo:root(workspace, Echo.createElement(Arctic))
```

### Fragement

```lua
--[[
    Fragments allows for multiple sound elements to be created and
    parented within the same root. You should not create mulitple roots
    for 2 different sounds if they're for the same feature - unless otherwise
    needed.
--]]

Echo.createElement(Echo.Fragment, {
    Reward, -- Does not to be wrapped in a `Echo.createElement`, this is already done for you
    Arctic,
})
```

### UseState

```lua
--[[
    Like in React, we can update a property's value or state directly
    by firing the signal for the subscribed callback. Unlike in React however,
    we can update the property without having to re-render the entire component -
    making it more performant. Due to this, we don't need a `useEffect` function
    to prevent the conditions from running again on re-render. The script runs onces,
    and will only render once - even when updating states.
--]]

local level, setLevel = Echo.useState(0) -- Pass the initial value you want the property to be

task.delay(2, function()
    setLevel(.5) -- Changes the level from 0 to .5
end)

-- Example
Distortion = Echo.createElement("DistortionSoundEffect", {
    Level = level
})
```

### UseSpring

```lua
-- Styles (table) is the value that is changed, api (returned module script) is the function that changes it
local styles: {}, api: {() -> ()} = Echo.useSpring(function()
    return {
        volume = 0, -- Initial value to lerp from
        rollOfDistance = 10,

        config = {
            duration = 5,
            delay = 0 -- If you want to delay the effect
        }
    }
end)

-- Start the spring, which will gradually increase the volume from 0 to .25 over 5 seconds
api:start({
    volume = .25, -- The new value to lerp to
    rollOfDistance = 100000,
    -- Additionally you can override the initial config values by providing a new config table, like such:
    --[[
        config = {
            duration = 1,
            delay = 2
        }
    --]]
})

-- Make sure to return the created element if it's within a function!!
return Echo.createElement("Sound", {
    SoundId = "rbxassetid://17612500198",
    Looped = true,
    Name = "Arctic",
    Volume = styles.volume, -- Set volume to the current value of the spring binded to
})
```

### CreateBinding

```lua
--[[
    One of the main features with Echo is being able to bind custom
    events such as playing sounds ONLY when a player walks into an area.
    As of right now, there is only one bind, which is an `area` bind.

    You must have both `enter` and `leave` functions which will be called
    when the player enters or leaves the area. The functions will only be given
    1 parameters - player parameter. Do whatever you wish when the player enters
    and leaves - this example is setup to smoothly lerp volume up on enter, and
    smoothly lerp volume down on leave.
--]]

Echo.createBinding(Echo.Binds.Area, function() -- Type of bind (Area only as of right now)
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

### CreateSignal

```lua
--[[
    You can create custom signals to communicate between different  components,
    by providing the name of the signal, along with a callback. You can create
    multiple signals using the same name, and they will all be called when a signal
    of a matching name is fired.
    
    @Param string: name - The name of the signal
    @Param function: callback - The callback function that will be called when the signal is triggered
--]]

Echo.createSignal("Play Reward", function(state: boolean)by
    setPlaying(state)

    return function ()
        -- You must manually perform your cleanup actions here
        -- Cleanup, will also break the subscription
    end
end)
```

### UseSignal

```lua
--[[
    Fire a signal that has been created, using the same name of the
    signal created. If the signal does not exists, it will throw an
    error.

    @Param string: name - The name of the signal(s) to fire
    @Param variadic: any - Any arguments to pass to the callback(s)
--]]

Echo.useSignal("Play Reward", true)

Echo.useSignal("Play Reward", function()
    -- Can even send custom callbacks if needed
end)
```

# Script Examples:

### Basic

```lua
local Echo = require(Path.To.Echo)

return function ()
    -- Make sure to always return the created element, even though the function is returned!
    return Echo.createElement("Sound", {
        SoundId = "rbxassetid://873617644",
        Volume = .25,
        Looped = true,
        Name = "Reward"
    }, {
        -- Child of
        Distortion = Echo.createElement("DistortionSoundEffect", {
            Level = 0.25
        })
    })
end
```

### Complex

```lua
local Echo = require(Path.To.Echo)

return function ()
    local timePosition, setTimePosition = Echo.useState(0)
    local playing, setPlaying = Echo.useState(true)

    local styles, api = Echo.useSpring(function()
        return {
            volume = 0,
            rollOfDistance = 10,

            config = {
                duration = 5,
            }
        }
    end)

    Echo.createBinding(Echo.Binds.Area, function()
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

    return Echo.createElement("Sound", {
        SoundId = "rbxassetid://17612500198",
        Looped = true,
        Name = "Arctic",
        Volume = styles.volume,
        RollOffMaxDistance = styles.rollOfDistance,
        Playing = playing,
        TimePosition = timePosition
    }, {
        Distortion = Echo.createElement("DistortionSoundEffect", {
            Level = styles.volume
        })
    })
end
```