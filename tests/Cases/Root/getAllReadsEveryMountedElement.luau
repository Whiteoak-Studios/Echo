--[[
    getAll gives every element of every live root in mount order, with its
    Name or nil, its SoundId or "", its Volume or a legacy Sound's default,
    each a bound state's current, and its root's target
--]]

--!strict
local Environment = require("../../Environment")

local WIND: string = "rbxassetid://1"
local GUST: string = "rbxassetid://2"
local SHOT: string = "rbxassetid://3"
local NAME: string = "Wind"
local AMBIENCE: string = "Ambience"
local QUIET: number = 0.25
local LOUD: number = 0.75
local SIZE: { [string]: number } = { initial = 4, growAt = 2, growBy = 2, ceiling = 8 }

type Expected = {
	name: string?,
	soundId: string,
	volume: number,
	root: any,
}

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Root: any = env.require("Root")
	local Element: any = env.require("Element")
	local Keys: any = env.require("Keys")
	local State: any = env.require("State")
	local defaultVolume: number = env.Instance.new("Sound").Volume

	Root.configure({ mode = "Legacy", cache = { Legacy = SIZE } })

	local part: any = env.Instance.new("Part")
	part.Parent = env.game.Workspace

	local soundId: any, setSoundId: (value: any) -> () = State.new(WIND)
	local volume: any, setVolume: (value: any) -> () = State.new(LOUD)

	local ambience: any = Root.mount(
		AMBIENCE,
		Element.create(Keys.Fragment, {
			Element.create("Sound", { Name = NAME, SoundId = soundId, Volume = QUIET }),
			Element.create("Sound", {}),
		})
	)

	Root.mount(part, Element.create("Sound", { SoundId = SHOT, Volume = volume }))

	local function compare(expected: { Expected }, when: string): (boolean, string | nil)
		local mounted: { any } = Root.getAll()
		if #mounted ~= #expected then
			return false, `getAll gave {#mounted} elements {when}, not {#expected}`
		end

		for index: number, entry: Expected in expected do
			local found: any = mounted[index]
			local same: boolean = found.name == entry.name
				and found.soundId == entry.soundId
				and found.volume == entry.volume
				and found.root == entry.root
			if not same then
				return false,
					`getAll's element {index} {when} read {found.name}, {found.soundId}, {found.volume} and {found.root}`
			end
		end

		return true, nil
	end

	local passed: boolean, reason: string? = compare({
		{ name = NAME, soundId = WIND, volume = QUIET, root = AMBIENCE },
		{ name = nil, soundId = "", volume = defaultVolume, root = AMBIENCE },
		{ name = nil, soundId = SHOT, volume = LOUD, root = part },
	}, "at mount")

	if not passed then
		return false, reason
	end

	setSoundId(GUST)
	setVolume(nil)

	passed, reason = compare({
		{ name = NAME, soundId = GUST, volume = QUIET, root = AMBIENCE },
		{ name = nil, soundId = "", volume = defaultVolume, root = AMBIENCE },
		{ name = nil, soundId = SHOT, volume = defaultVolume, root = part },
	}, "after its states were set")

	if not passed then
		return false, reason
	end

	ambience:destroy()

	return compare({
		{ name = nil, soundId = SHOT, volume = defaultVolume, root = part },
	}, "after a root was destroyed")
end
