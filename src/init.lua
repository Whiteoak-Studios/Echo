--[[
    This package follows the same structure as react does.
    To understand how it's structured, please refer to the React Lua
    documentation. All functions and methods are the same for simplicity.

    https://roblox.github.io/roact-alignment/api-reference/react/
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Promise = require(Packages.Promise)

local Binds: Folder = script.Modules.Binds
local Events: Folder = script.Modules.Events
local Actions: Folder = script.Modules.Actions

local Signal: {connect: () -> ()} = require(script.Modules.Classes.Signal)
local SpringModule: () -> () = require(script.Modules.Spring)

type CreationInfo = {
    name: string,
    type: string,
    isGlobal: boolean
}

type Fragment = boolean
type Property = string | number | boolean
type Props = {
    [string]: any
}

type Area = {
    enter: () -> (),
    leave: () -> ()
}

type Spring = {
    string: number, -- Value to lerp to
    string: {} -- Config table
}

type UseState = {
    subscribe: () -> (),
    connected: () -> (),
    state: any
}

type Ref = {
    current: any
}

export type Elements = {Sound}
export type Element = {string: Property}

local Module = {
    _folders = {},

    Fragment = true,
    Bind = {
        Area = require(Binds.Area)
    },
    
    Event = {
        Looped = require(Events.Looped),
        Ended = require(Events.Ended),
        Loaded = require(Events.Loaded),
        Playing = require(Events.Playing)
    },

    Action = {
        Play = require(Actions.Play),
        Pause = require(Actions.Pause),
    },

    Util = {
        Cache = script.Modules.Classes.Cache,
    },
    
    Signals = {} -- Stores all signals
}

--[[
    Creates a new structure for a new sound, acts the same as
    `React:root`. Creates a new folder structure to store
    sound elements within
--]]
function Module:root(parent: any | Elements | string, elements: Elements | nil)
    local mainFolder: Folder = parent
    local elements: Elements = elements

    if typeof(parent) == "table" then
        mainFolder = Module:_createStructure() -- If first time starting package
        elements = parent
    elseif typeof(parent) == "string" then
        -- Grant ability to add into the same folder
        if Module._folders[parent] then
            mainFolder = Module._folders[parent]
        else
            mainFolder = Module:_createStructure(parent)
            mainFolder.Name = parent

            Module._folders[parent] = mainFolder
        end
    elseif not parent then
        mainFolder = Module:_createStructure() -- Incase parent is nil
    end
    
    -- Parent sounds into the correct folder
    for _, element: Element in elements do
        for _, sound: Sound in element do
            sound.Parent = mainFolder
        end
    end
end

--[[
    Creates and returns a physical sound element, based
    on the properties given, always returns an array
--]]
function Module.createElement(
    type: string | Fragment | () -> Element,
    properties: Element | Props,
    children: Element?
) : {[number]: Sound} | {[number]: Element}

    if typeof(type) == "boolean" then
        return Module._createFragment(properties)
    elseif typeof(type) == "function" then
        return {
            [1] = type(properties)
        }
    end

    local sound: Sound = Instance.new(type)
    for property: string | Instance, value: any | table | () -> () in properties do
        if
            typeof(value) == "function"
            or typeof(property) == "function"
        then
            Module._listenForEventChange(sound, property, value)
        elseif typeof(value) == "table" then -- From signal / useState
            Module._listenForStateChange(sound, property, value)
        elseif typeof(property) == "Instance" then -- For sound caching!
            if property:IsA("ModuleScript") then
                Module._createCache(sound, require(property), value)
            end
        else
            sound[property] = value
        end
    end

    -- Insert child instances into the element
    if children then
        for name: string, child: {[number]: Instance} in children do
            for _, childComponent: Instance in child do
                childComponent.Name = name
                childComponent.Parent = sound
            end
        end
    end

    -- Root table expects an array
    return {
        [1] = sound
    }
end

--[[
    Creates a bind that will be used to change a property
    of an instance
--]]
function Module.useState(defaultState: any) : (any, () -> ())
    local subscribe: () -> (), fire: () -> () = Signal()
    local connected, fireConnected = Signal()

    -- Set default state only once the bind has been connected
    local disconnect: () -> ()
    disconnect = connected(function(value: boolean)
        if value then
            fire(defaultState)
            disconnect()
        end
    end)

    return {
        subscribe = subscribe,
        connected = fireConnected,
        state = defaultState
    }, fire
end

--[[
    Create a custom bind with a `subscribe` and `disconnect`
    callback signal
--]]
function Module.createBinding(type: () -> (), parameters: () -> Area)
    type(parameters())
end

--[[
    Create a spring that can smoothly adjust different
    values set to an instance
--]]
function Module.useSpring(func: () -> Spring) : {[string]: () -> ()} & {() -> any}
    local springSettings: Spring = func()
    local signals: {[string]: () -> ()} = {}

    local springModule: {() -> any} = SpringModule.new(springSettings.config)

    for name: string, value: number | table in springSettings do
        if
            not typeof(value) == "number"
            or typeof(value) == "table"
        then
            continue
        end

        local subscribe: () -> (), fire: () -> () = Signal()
        local connected, fireConnected = Signal()
        local disconnect: () -> ()

        signals[name] = {
            subscribe = subscribe,
            connected = fireConnected
        }
        
        -- Set the initial value of the property once connected!
        disconnect = connected(function()
            fire(value)
            disconnect()
        end)

        -- Add to remote table to update all value at once
        springModule.properties[name] = {
            update = fire,
            initialValue = value,
            currentValue = value
        }
    end

    return signals, springModule
end

--[[
    Create a signal which can be fired within any script
--]]
function Module.createSignal(name: string, callback: () -> ())
    Promise.new(function() -- Incase callback yields
        local subscribe: () -> (), fire: () -> () = Signal()
        local disconnect: () -> ()

        disconnect = subscribe(function(...: any)
            local func: () -> ()? = callback(...)
            if func then
                disconnect()
                func() -- Run cleanup for any possible other connections

                -- Remove the signal completely
                for _, callbackFire: () -> () | string in Module.Signals[name] do
                    if typeof(callback) == "string" then
                        continue
                    end

                    if callbackFire == fire then
                        table.remove(Module.Signals[name],
                            table.find(Module.Signals[name], callbackFire))
                    end
                end
            end
        end)

        if not Module.Signals[name] then
            Module.Signals[name] = {
                name = name
            }
        end

        table.insert(Module.Signals[name], fire)
    end)
end

--[[
    Fires a signal that was created, but waits until the
    package and all elements have been completly loaded to
    ensure that all signals fired at listened to
--]]
function Module.useSignal(signal: {[string]: () -> ()} | string, ...: any)
    local args: {any} = {...}

    Promise.new(function(resolve, reject)
        local started: number = os.clock()
        local timeout: number = 5 -- Before timing out (possibly from an error)

        -- Ensure the sound element has been loaded properly
        if not Module.Signals[signal] then
            repeat
                task.wait()
                if os.clock() - started >= timeout then
                    reject(`{"`useSignal`"}: "{signal}" has timed out, this is likely due {
                    "to an error in the signal or a dependency. Please make sure that the signal was created, and is called using a string!"}`)
                end
            until Module.Signals[signal]

            signal = Module.Signals[signal]
        else
            signal = Module.Signals[signal]
        end

        -- Get the most up to date signal, as `signal` might be outdated from calling before registration!
        for _, newSignal: {[string]: () -> ()}  in Module.Signals do
            if newSignal.name == signal.name then
                signal = table.clone(newSignal) -- Clone because changes are made to original for cleanup!
            end
        end

        -- Fire all signals to subscribed connections
        if signal then
            for _, fire: () -> () | string in signal do
                if typeof(fire) == "string" then
                    continue
                end
                fire(table.unpack(args))
            end
            resolve()
        end
    end):catch(function(err: string?)
        warn(tostring(err))
    end)
end

--[[
    Completely removes all connections tied to the signal, breaking
    all connections
--]]
function Module.removeSignal(name: string)
    Module.Signals[name] = {}
end

--[[
    Simply just returns a table setup similar to
    React's use ref.
--]]
function Module.useRef(initialValue: any) : Ref
    return table.clone({
        current = initialValue
    })
end

--[[
    Creates a cache of sounds to be used
--]]
function Module._createCache(sound: Sound, cache: () -> {() -> ()}, callback: () -> {string: any})
    local config: {[string]: any} = callback()
    config.defaultParent = "Test"
    cache(sound, config)
end

--[[
    Create the folder structure
--]]
function Module:_createStructure() : Folder
    if script:FindFirstChild("Environments") then
        return script["Environments"]
    end

    local mainFolder: Folder = Instance.new "Folder"
    mainFolder.Name = "Sounds"
    mainFolder.Parent = script

    return mainFolder
end

--[[
    Creates a framgment which will allow multiple sounds
    to be created and stored within a single structure
--]]
function Module._createFragment(properties: {}) : {Element}
    local sounds: {Sound} = {}
    for _, method: () -> Element in properties do
        if not typeof(method) == "function" then
            return
        end

        table.insert(sounds, method())
    end
    return sounds
end

--[[
    Subscribe to a callback function for whenever a property
    or `useState` is fired, updating the sound instance's
    properties accordingly
--]]
function Module._listenForStateChange(sound: Sound, property: string, useState: UseState)
    local subscribe: () -> () = useState.subscribe
    local connected: () -> () = useState.connected

    -- Listen for property changes
    local disconnect: () -> ()
    disconnect = subscribe(function(newState: any)
        if sound:GetAttribute(property) then
            if
                typeof(sound:GetAttribute(property)) ~= typeof(newState)
            then
                warn(`Bind has been disconnected, new value {newState} is not the same type as the previous one!`)
                return disconnect() -- Disconnect Signal
            end
        end

        sound[property] = newState
        sound:SetAttribute(property, newState) -- Assign previous state tied to the property changed
    end)

    -- Setup connection to listen for when the sound is removed, thus disconnecting all binds
    local cleanup: RBXScriptConnection
    cleanup = sound.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if cleanup then
                cleanup:Disconnect()
            end

            disconnect()
        end
    end)

    -- Let orignal bind know we've successfully connected our bind, disconnect that initial bind
    connected(true)
end

--[[
    Subscribe to a callback function for whenever an event
    is triggered from the sound instance
--]]
function Module._listenForEventChange(sound: Sound, event: (any) -> (), callback: (any) -> any | UseState)
    local isAction: boolean = typeof(callback) == "table"
    if isAction then
        return Module._listenForActionChange(sound, event, callback)
    else
        local disconnect: () -> ()
        disconnect = event(sound, function(...: any)
            local cleanup: () -> ()? = callback(...)
            if cleanup then
                cleanup()
                disconnect()
            end
        end)
    end
end

--[[
    Calls certain actions from the sound, like
    "pause" or "resume", that's tied to a useState
    connection.
--]]
function Module._listenForActionChange(sound: Sound, event: (any) -> (), useState: UseState)
    local disconnect: () -> ()
    local connection: RBXScriptConnection

    disconnect = useState.subscribe(function(state: boolean)
        print(state, "state")
        event(sound, state)
    end)

    connection = sound.AncestryChanged:Connect(function(_, parent: nil?)
        if not parent then
            disconnect()
            connection:Disconnect()
        end
    end)
end

return Module