return function ()
    local Echo = require(script.Parent)
    local Reward: () -> typeof(Echo.Element) = require(script.Parent.Modules.Sound.Reward)
    local Arctic: () -> typeof(Echo.Element) = require(script.Parent.Modules.Sound.Arctic)

    describe("root", function()
        it("create a new root that can store and handle sound elements within (React for sound)", function()
            Echo:root(nil, Echo.createElement(Echo.Fragment, {
                Reward,
                Arctic,
            }))

            -- Echo:root(workspace, Echo.createElement(Arctic))
        end)
    end)
end