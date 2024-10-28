local Module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage.Packages

local Promise = require(Packages.Promise)

local IS_STUDIO: boolean = RunService:IsStudio()

type Config = {
    duration: number?,
    delay: number?
}

type NewValues = {
    string: number,
    config: Config?
}

type Property = {
    update: () -> (),
    initialValue: number
}

-- Incase a config table is not provided
local DEFAULT_CONFIG: {} = {
    duration = 1,
    delay = 0
}

function Module.new(config: {})
    local self = {
        _config = config or DEFAULT_CONFIG,
        properties = {}, -- Store all updateable properties within this table
    }

    setmetatable(self, { __index = table.clone(Module) })
    return self
end

--[[
    Starts the spring
--]]
function Module:start(newValues: NewValues) : typeof(Promise)
    if not newValues then
        warn(`Cannot start spring, provided parameter is invalid!`)
        return
    end

    local config: Config = newValues.config or self._config -- Incase we want to use new config values
    local duration: number? = config.duration or 0
    local delay: number? = config.delay or 0

    local timeStarted: number = tick()

    return Promise.new(function(resolve)
        task.wait(delay)

        local initialCurrentValues: {[string]: number} = {}
        for name: string, property: Property in self.properties do
            initialCurrentValues[name] = property.currentValue
        end

        while true do
            local timeSinceOpened: number = tick() - timeStarted
            local progress: number = timeSinceOpened / duration

            for name: string, property: Property in self.properties do
                if not newValues[name] then
                    continue
                end

                local endValue: number = newValues[name]
                local startValue: number = initialCurrentValues[name]
                local newValue: number

                local minClamp: number = 0
                local maxClamp: number = endValue

                -- Determine whether we're reducing or increasing the value
                if endValue > startValue then
                    newValue = startValue + (endValue - startValue) * progress -- Increasing
                else
                    -- Handle reducing values
                    startValue = initialCurrentValues[name]
                    endValue = newValues[name]
                    newValue = startValue - (startValue - endValue) * progress -- Decreasing

                    minClamp = newValues[name]
                    maxClamp = startValue
                end

                local finalValue: number = math.clamp(newValue, minClamp, maxClamp)
                self.properties[name].currentValue = finalValue

                property.update(finalValue)

                if progress >= 1 then
                    resolve()
                end
            end

            -- Break the loop if the duration has been exceeded
            if timeSinceOpened >= duration + .25 then
                resolve()
            end

            if IS_STUDIO then
                RunService.Heartbeat:Wait()
            else
                RunService.RenderStepped:Wait()
            end
        end
    end)
end

return Module