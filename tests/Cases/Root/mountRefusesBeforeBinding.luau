--[[
    A mount refuses, naming it, a Mode with no pool, a target of the wrong
    type, a property, effect property or bound value its Mode refuses, a
    label that is no string, and a cap group or bus the configuration lacks,
    before anything binds, so a failed mount leaves no ref, voice or root
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

type Refusal = {
	target: any,
	element: any,
	mode: string?,
	names: string, -- What the error must name
}

return function (): (boolean, string | nil)
	local single: Environment.Environment = Environment.new()
	local SingleRoot: any = single.require("Root")
	local SingleElement: any = single.require("Element")

	SingleRoot.configure({ mode = "Legacy", cache = { Legacy = SIZE } })

	local unsized: boolean, message: any =
		pcall(SingleRoot.mount, nil, SingleElement.create("Sound", { SoundId = ID }), "AudioApi")
	if unsized or string.find(tostring(message), "AudioApi", 1, true) == nil then
		return false, `a root in a Mode config.cache does not size did not error naming it: {message}`
	end

	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")
	local State: any = env.require("State")
	local Cache: any = env.require("Cache")

	Root.configure({
		mode = "Legacy",
		cache = { Legacy = SIZE, AudioApi = SIZE },
		caps = { Gun = 2 },
		buses = { Effects = {} },
	})

	local wrong: any = State.new("loud")
	local numbered: any = State.new(5)
	local refusals: { Refusal } = {
		{ target = 5, element = Element.create("Sound", { SoundId = ID }), names = "target" },
		{ target = nil, element = Element.create("Sound", { Bogus = 1 }), names = "Bogus" },
		{ target = nil, element = Element.create("Sound", { Volume = "loud" }), names = "Volume" },
		{ target = nil, element = Element.create("Sound", { PlaybackSpeed = wrong }), names = "PlaybackSpeed" },
		{
			target = nil,
			element = Element.create("Sound", { EmitterSize = 1 }),
			mode = "AudioApi",
			names = "EmitterSize",
		},
		{ target = nil, element = Element.create("Sound", { Name = 5 }), names = "Name" },
		{ target = nil, element = Element.create("Sound", { Name = numbered }), mode = "AudioApi", names = "Name" },
		{
			target = nil,
			element = Element.create("Sound", { SoundId = ID }, {
				Equalizer = Element.create("EqualizerSoundEffect", { MidRange = 1 }),
			}),
			names = "MidRange",
		},
		{ target = nil, element = Element.create("Sound", { [Keys.Util.Cap] = "Footsteps" }), names = "Footsteps" },
		{ target = nil, element = Element.create("Sound", { [Keys.Util.Bus] = "Interface" }), names = "Interface" },
	}

	for index: number, refusal: Refusal in refusals do
		local mounted: boolean, reason: any = pcall(Root.mount, refusal.target, refusal.element, refusal.mode)
		if mounted then
			return false, `refusal {index} was mounted`
		elseif string.find(tostring(reason), refusal.names, 1, true) == nil then
			return false, `refusal {index} errored without naming {refusal.names}: {reason}`
		end
	end

	-- A good sound beside a refused one: the refusal must leave the good one unbound
	local ref: any = Element.ref(nil)
	local playing: any, setPlaying: (value: any) -> () = State.new(true)
	local volume: any = State.new(0.25)
	local good: any = Element.create("Sound", {
		SoundId = ID,
		Volume = volume,
		Handle = ref,
		[Keys.Action.Play] = playing,
	})

	local refused: any = Element.create("Sound", { Volume = "loud" })
	local tree: any = Element.create(Keys.Fragment, { good, refused })

	if pcall(Root.mount, nil, tree) then
		return false, "a tree holding a refused sound was mounted"
	end

	setPlaying(false)
	setPlaying(true)

	if ref.current ~= nil then
		return false, "a failed mount set a ref"
	elseif Cache.count("Legacy").inUse ~= 0 then
		return false, "a failed mount left a voice playing, at mount or from a later set of its action"
	elseif #Root.getAll() ~= 0 then
		return false, "a failed mount left a root in getAll"
	end

	return true, nil
end
