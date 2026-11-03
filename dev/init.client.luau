--[[
    The dev place's LocalScript: builds the scene, configures Echo once for
    the live run, then takes jobs by its Run attribute and from the panel
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Echo = require(ReplicatedStorage.Packages.Echo)

local Audible = require(script.Audible)
local Bench = require(script.Bench)
local Checks = require(script.Checks)
local Click = require(script.Click)
local Config = require(script.Config)
local Panel = require(script.Panel)
local Runner = require(script.Runner)
local Scene = require(script.Scene)

local POOL: Echo.CacheSize = Config.pool
local MODE: Echo.Mode = Config.mode :: Echo.Mode
local RAPID_GROUP: string = Config.audible.rapidFire.group
local RAPID_LIMIT: number = Config.audible.rapidFire.limit
local BUS_NAME: string = Config.bus.name
local BUS_GROUP: string = Config.bus.interactionGroup
local CURVES_BUS: string = Config.curves.bus
local CURVES_GROUP: string = Config.curves.interactionGroup
local PANEL_JOBS: { string } = Config.panel

local scene: Scene.Scene = Scene.build()

-- No warnAudioApiLimit, so the live run reads the Audio API pool's warning in the output at boot
local configuration: Echo.Config = {
	mode = MODE,
	cache = { Legacy = POOL, AudioApi = POOL },
	caps = { [RAPID_GROUP] = RAPID_LIMIT },
	buses = {
		[BUS_NAME] = { group = scene.group, fader = scene.fader, interactionGroup = BUS_GROUP },
		[CURVES_BUS] = { interactionGroup = CURVES_GROUP },
	},
	parent = scene.voices,
}

-- A refused configuration still lets the link job run and report it
local configured: boolean, refusal: any = pcall(Echo.configure, configuration)
local configureError: string? = not configured and tostring(refusal) or nil

local runner: Runner.Runner = Runner.new(script, { Checks, Bench, Audible, Click }, {
	scene = scene,
	configureError = configureError,
	caption = function (text: string)
		Panel:caption(text)
	end,
}, function (text: string)
	Panel:show(text)
end)

Panel:build(PANEL_JOBS, function (name: string)
	runner:run(name)
end)

script:SetAttribute("Status", configureError and `FAIL configure: {configureError}` or "READY")
print(`EchoDev {script:GetAttribute("Status")}`)

runner:listen()
