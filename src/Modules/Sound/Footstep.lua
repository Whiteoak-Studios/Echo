local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Echo = require(script.Parent.Parent.Parent)
local Cache = require(Packages.Cache)

local GameWorkspace: Folder = workspace:WaitForChild("GameWorkspace")
local Parent: Folder = GameWorkspace.Footsteps

local CATEGORY: string = "Footstep [Concrete]"
local SOUND_IDS: {[number]: string} = {
    [1] = "rbxassetid://1708951436",
    [2] = "rbxassetid://1708951436",
    [3] = "rbxassetid://1708951436",
    [4] = "rbxassetid://1708951436",
}

return function ()
    Echo.createSignal("Footstep [Concrete]", function(parent: BasePart, name: string | number?)
        local sound: {Sound} = Cache:get(nil, CATEGORY, tostring(name))[1]
        sound.Parent = parent
        sound:Play() -- We've exposed sound instance, we can play it directly

        task.delay(.5, function()
            Cache:rebound(sound)
        end)
    end)

    return Echo.createElement("Sound", {
        Volume = .25,
        Name = "1",

        [Echo.Util.Cache] = function()
            return {
                count = 4,
                category = CATEGORY,
                parent = Parent,

                -- Custom callback to perform an action needed when all sounds are cached!
                callback = function(items: {Sound})
                    for index: number, sound: Sound in items do
                        sound.Name = tostring(index)
                        sound.SoundId = SOUND_IDS[index]
                    end
                end
            }
        end
    })
end