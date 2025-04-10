return function ()
    local Echo = require(script.Parent)
    local Reward: () -> typeof(Echo.Element) = require(script.Parent.Modules.Sound.Reward)
    local Arctic: () -> typeof(Echo.Element) = require(script.Parent.Modules.Sound.Arctic)
    local Spin: () -> typeof(Echo.Element) = require(script.Parent.Modules.Sound.Spin)
    local Footstep: () -> typeof(Echo.Element) = require(script.Parent.Modules.Sound.Footstep)

    describe("root", function()
        it("create a new root that can store and handle sound elements within (React for sound)", function()
            Echo:root("Footsteps", Echo.createElement(Echo.Fragment, {
                Reward,
                Arctic,
                Spin,
                Footstep
            }))

            task.delay(2, function()
                Echo.useSignal("Artic")
            end)

            -- Echo:root(workspace, Echo.createElement(Arctic))
        end)
    end)
end