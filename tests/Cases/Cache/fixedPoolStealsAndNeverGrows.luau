--[[
    A pool of initial alone never grows over takes and frames, and with every
    voice out a take gives back the earliest-started one-shot and plays on
    it, while with only loops out a take gets nothing and stops none
--]]

--!strict
local Environment = require("../../Environment")
local FakeBackend = require("../../Fixtures/FakeBackend")

local MODE: string = "Legacy"
local SIZE: { [string]: number } = { initial = 4 }
local FRAME: number = 1 / 60
local AFTER: number = 60 -- Frames run between and after the takes, in which a growing pool would grow

-- Whether each take that fills the pool loops: a loop first, so the earliest one-shot is not the earliest voice
local FILL: { boolean } = { true, false, false, true }

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local Cache: any = env.require("Cache")
	local terrain: any = env.game.Workspace.Terrain
	local heartbeat: any = env.game:GetService("RunService").Heartbeat

	Cache.create(MODE, SIZE, FakeBackend.new(env))

	local released: { any } = {}
	local function take(looped: boolean): any
		return Cache.take(MODE, {
			looped = looped,
			release = function (voice: any)
				table.insert(released, voice)
			end,
		})
	end

	local function fixed(when: string): string?
		local count: any = Cache.count(MODE)
		if count.size ~= SIZE.initial or #terrain:GetChildren() ~= SIZE.initial then
			return `{when} the pool holds {count.size} voices with {#terrain:GetChildren()} under Terrain`
		elseif env.connections(heartbeat) ~= 0 then
			return `{when} the pool holds a Heartbeat connection`
		end

		return nil
	end

	local voices: { any } = {}
	for index: number, looped: boolean in FILL do
		table.insert(voices, take(looped))
		env.step(FRAME * AFTER)

		local reason: string? = fixed(`after take {index}`)
		if reason then
			return false, reason
		end
	end

	-- 1) With every voice out, a one-shot plays on the earliest-started one-shot's tree
	local oneShot: any = take(false)
	if #released ~= 1 or released[1] ~= voices[2] or voices[2].instance ~= nil then
		return false, "a one-shot with every voice out did not give back the earliest-started one-shot"
	elseif not oneShot or oneShot.tree ~= voices[2].tree then
		return false, "the one-shot did not play on the voice it took"
	end

	-- 2) Two loops take the next one-shots, which leaves nothing but loops out
	local loops: { any } = { voices[1], voices[4], take(true), take(true) }
	if #released ~= 3 or released[2] ~= voices[3] or released[3] ~= oneShot then
		return false, "the loops did not take the one-shots in their start order"
	end

	-- 3) With only loops out, neither a one-shot nor a loop gets a voice
	if take(false) ~= nil or take(true) ~= nil then
		return false, "a take with nothing but loops out of a fixed pool got a voice"
	elseif #released ~= 3 then
		return false, `the refused takes gave back {#released - 3} loops`
	end

	for index: number, loop: any in loops do
		if not loop or loop.instance == nil then
			return false, `loop {index} lost its voice`
		end
	end

	env.step(FRAME * AFTER)

	local reason: string? = fixed("after every take")
	if reason then
		return false, reason
	elseif Cache.count(MODE).inUse ~= SIZE.initial then
		return false, `the pool reads {Cache.count(MODE).inUse} in use, not {SIZE.initial}`
	end

	return true, nil
end
