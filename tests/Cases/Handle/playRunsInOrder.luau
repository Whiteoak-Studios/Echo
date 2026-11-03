--[[
    A play applies each property with its override standing in, never one
    whose value is nil nor the label, sets each effect with its override
    merged, routes, places and sets its attributes, then connects its
    events, plays, and sets TimePosition after; at places it, following none
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }
local ID: string = "rbxassetid://1"
local QUIET: number = 0.25
local LOUD: number = 0.75
local START: number = 2
local HIGH: number = -3
local LOW: number = -6
local ARTIST: string = "Mike"
local NAME: string = "Wind"
local FRAME: number = 1 / 60

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local Element: any = env.require("Element")
	local Handle: any = env.require("Handle")
	local Keys: any = env.require("Keys")
	local State: any = env.require("State")
	local backend: FakeBackend.FakeBackend = FakeBackend.new(env)
	local bus: { [string]: any } = { interactionGroup = "Effects" }

	local part: any = env.Instance.new("Part")
	part.Position = roblox.Vector3.new(10, 0, 0)
	part.Parent = env.game.Workspace

	Cache.create(MODE, SIZE, backend)

	local volume: any = State.new(QUIET)
	local speed: any = State.new(nil)
	local element: any = Element.create("Sound", {
		Name = NAME,
		SoundId = ID,
		Volume = volume,
		PlaybackSpeed = speed,
		TimePosition = START,
		Attributes = { Artist = ARTIST },
		[Keys.Util.Bus] = "Effects",
	}, {
		Equalizer = Element.create("EqualizerSoundEffect", { HighGain = HIGH }),
	})

	local handle: any = Handle.new(element, {
		mode = MODE,
		backend = backend,
		target = part,
		config = { mode = MODE, cache = { [MODE] = SIZE }, buses = { Effects = bus } },
	})

	handle:bind()

	local first: number = #backend.calls
	local voice: any = handle:play({ Volume = LOUD, Equalizer = { LowGain = LOW } })

	for _, call: FakeBackend.Call in backend.calls do
		if call.name == "check" and call.args[1] == "Name" then
			return false, "a mount checked the element's label against its Mode"
		end
	end

	-- Where each call of this play landed, the applies by property
	local at: { [string]: number } = {}
	local applied: { [string]: { position: number, value: any } } = {}

	for position: number = first + 1, #backend.calls do
		local call: FakeBackend.Call = backend.calls[position]
		if call.name == "apply" then
			applied[call.args[2]] = { position = position, value = call.args[3] }
		elseif not at[call.name] then
			at[call.name] = position
		end
	end

	for _, name: string in { "connect", "effect", "route", "place", "play" } do
		if not at[name] then
			return false, `a play made no {name} call`
		end
	end

	if not (at.effect < at.route and at.route < at.place and at.place < at.connect and at.connect < at.play) then
		return false, "a play did not set effects, route, place, connect and play in that order"
	end

	for name: string, apply: { position: number, value: any } in applied do
		if name ~= "TimePosition" and apply.position > at.connect then
			return false, `a play applied {name} after connecting its events`
		end
	end

	if not applied.SoundId or applied.SoundId.value ~= ID then
		return false, "a play did not apply its SoundId"
	elseif not applied.Volume or applied.Volume.value ~= LOUD then
		return false, `a play applied Volume {applied.Volume and applied.Volume.value}, not its override`
	elseif applied.PlaybackSpeed then
		return false, "a play applied a property whose bound value is nil"
	elseif applied.Name then
		return false, "a play applied the element's label to its voice"
	elseif
		not applied.TimePosition
		or applied.TimePosition.value ~= START
		or applied.TimePosition.position < at.play
	then
		return false, "a play did not set its TimePosition after the play"
	end

	local effect: { any } = backend.calls[at.effect].args
	local properties: { [string]: any } = effect[4]

	if effect[2] ~= "EqualizerSoundEffect" or effect[3] ~= "Equalizer" then
		return false, `a play set its effect as {effect[2]} under {effect[3]}`
	elseif properties.HighGain ~= HIGH or properties.LowGain ~= LOW then
		return false, "a play's effect did not take the element's properties with its override merged"
	end

	local route: { any } = backend.calls[at.route].args
	if route[2] ~= bus or route[3] ~= true then
		return false, "a play under a part did not route to its bus as a world voice"
	elseif voice.instance:GetAttribute("Artist") ~= ARTIST then
		return false, "a play did not set the element's attributes on its voice"
	end

	local point: any = roblox.Vector3.new(1, 2, 3)
	local mark: number = #backend.calls
	local placed: any = handle:play({ at = point })
	local placedAt: number = 0

	for position: number = mark + 1, #backend.calls do
		local call: FakeBackend.Call = backend.calls[position]
		if call.name == "route" and call.args[3] ~= true then
			return false, "a play with at was not routed as a world voice"
		elseif call.name == "place" and call.args[1] == placed.tree then
			placedAt += 1
			if call.args[2] ~= point then
				return false, `a play with at was placed at {call.args[2]}`
			end
		end
	end

	mark = #backend.calls
	env.step(FRAME)

	for position: number = mark + 1, #backend.calls do
		local call: FakeBackend.Call = backend.calls[position]
		if call.name == "place" and call.args[1] == placed.tree then
			return false, "a play with at followed its root's part"
		end
	end

	if placedAt ~= 1 then
		return false, `a play with at was placed {placedAt} times, not once`
	end

	return true, nil
end
