local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

local Cache = require(Packages.Cache)
local Promise = require(Packages.Promise)

return function (sound: Sound, config: {[string]: any})
    local count: number? = config.count
    local category: string? = config.category
    local parent: any | nil = config.parent or workspace

    local callback: () -> ()? = config.callback

    if
        not count
        or not category
        or not sound
    then
        warn(`Invalid params for count: {count} and category: {category}`)
        return
    end

    Promise.new(function(_, reject)
        if not sound:IsDescendantOf(game) then
            local start: number = os.clock()
            local timeout: number = 5

            -- Ensure sound is within game!
            repeat
                task.wait()
                if os.clock() - start >= timeout then
                    reject(`Timer has timed out when while waiting for sound to become {
                        `an instance within the game, while trying to cache said instance!`
                    }`)
                    break
                end
            until sound:IsDescendantOf(game)
        end

        local cachedItems = Cache:create(category, parent)
        Cache:add(sound, count, parent, category)

        if callback then
            callback(cachedItems.items)
        end
    end):catch(function(message: string)
        warn(tostring(message))
    end)
end