--[[
    A signal fired fifty times in a row, whose callback plays through the
    handle its ref holds, never holds more voices than the element's cap
    and makes no instance on any play, in either Mode
--]]

--!strict
local Environment = require("../../Environment")

local ID: string = "rbxassetid://1"
local MODES: { string } = { "Legacy", "AudioApi" }
local SIZE: { [string]: number } = { initial = 16, growAt = 16, growBy = 4, ceiling = 32 }
local SIGNAL: string = "Gun/AKM/Shot"
local GROUP: string = "Gun/AKM/FirstPerson"
local LIMIT: number = 12
local BURST: number = 50

return function (): (boolean, string | nil)
	for _, mode: string in MODES do
		local env: Environment.Environment = Environment.new()
		local Root: any = env.require("Root")
		local Element: any = env.require("Element")
		local Keys: any = env.require("Keys")
		local Signals: any = env.require("Signals")
		local Cache: any = env.require("Cache")

		Root.configure({ mode = mode, cache = { [mode] = SIZE }, caps = { [GROUP] = LIMIT } })

		local ref: any = Element.ref(nil)
		Root.mount(nil, Element.create("Sound", { SoundId = ID, Handle = ref, [Keys.Util.Cap] = GROUP }))

		Signals.create(SIGNAL, function ()
			ref.current:play()
		end)

		local instances: number = #env.game:GetDescendants()

		for fire: number = 1, BURST do
			Signals.fire(SIGNAL)

			local live: number = #ref.current:getAll()
			if live > LIMIT or Cache.count(mode).inUse > LIMIT then
				return false, `{mode} fire {fire} left {live} voices live, past the cap of {LIMIT}`
			end
		end

		local made: number = #env.game:GetDescendants() - instances
		if #ref.current:getAll() ~= LIMIT then
			return false, `a {mode} burst ended with {#ref.current:getAll()} voices live, not its cap`
		elseif made ~= 0 then
			return false, `a {mode} burst made {made} instances`
		end
	end

	return true, nil
end
