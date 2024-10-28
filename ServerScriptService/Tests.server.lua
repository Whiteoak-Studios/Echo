local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

local Echo = script.Parent.Parent.Module

TestEZ.TestBootstrap:run({
    Echo["init.spec"],
})