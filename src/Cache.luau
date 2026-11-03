--[[
    The pools of voices Echo plays from, one Cellar category per Mode under
    a given parent or Terrain: taking a voice under its cap, growing and
    stealing at the ceiling, giving a voice back, and following its target
--]]

--!strict
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Cellar = require(script.Parent.Parent.Cellar)

local Constants = require(script.Parent.Constants)

local Types = require(script.Parent.Types)

type Backend = Types.Backend
type CacheCount = Types.CacheCount
type CacheSize = Types.CacheSize
type Mode = Types.Mode
type TakeRequest = Types.TakeRequest
type VoiceToken = Types.VoiceToken

type Pool = {
	category: string,
	backend: Backend,
	template: Attachment, -- Every voice is cloned from this one tree, so growing makes no template
	margin: number, -- A growth step starts once a take leaves this many voices free, or fewer
	growBy: number,
	ceiling: number, -- The initial of a pool given no growth fields, so it never grows
	total: number, -- The voices made so far, free and out
	inUse: number,
	pending: number, -- The voices the running growth step has still to make, 0 with no step running
}

local Pools: { [Mode]: Pool } = {}
local Live: { VoiceToken } = {} -- Every voice out of either pool, in start order
local Groups: { [string]: number } = {} -- How many live voices each cap group holds
local Following: { [VoiceToken]: Instance } = {} -- Each followed voice's target

local takes: number = 0 -- Every take so far, which gives each voice its start order
local heartbeat: RBXScriptConnection? = nil -- Held only while some voice follows a target
local growth: RBXScriptConnection? = nil -- Held only while some pool's growth step runs

local Cache = {}

local function checkCount(mode: Mode, field: string, value: number?): number
	assert(
		type(value) == "number" and value >= 1 and value % 1 == 0,
		`Cache.create needs {mode}'s {field} to be a whole number of 1 or more, not {value}`
	)

	return value
end

--[[
    Declares a Mode's pool under the given parent, or Terrain when none is
    given, and fills it with its initial voices, all cloned there from one
    template the backend builds. A pool given no growth fields is fixed at
    its initial
--]]

function Cache.create(mode: Mode, size: CacheSize, backend: Backend, parent: Instance?)
	local initial: number = checkCount(mode, "initial", size.initial)
	local growAt: number, growBy: number, ceiling: number = 0, 0, initial

	-- The growth fields come together, so once one is given each is checked
	if size.growAt or size.growBy or size.ceiling then
		growAt = checkCount(mode, "growAt", size.growAt)
		growBy = checkCount(mode, "growBy", size.growBy)
		ceiling = checkCount(mode, "ceiling", size.ceiling)

		assert(growAt <= initial, `Cache.create needs {mode}'s growAt to be at most its initial`)
		assert(ceiling >= initial, `Cache.create needs {mode}'s ceiling to be at least its initial`)
	end

	local category: string = Constants.CATEGORIES[mode]
	local template: Attachment = backend.template()

	Cellar:create(category, parent or Workspace.Terrain)
	Cellar:add(template, initial, nil, category)

	Pools[mode] = {
		category = category,
		backend = backend,
		template = template,
		margin = initial - growAt,
		growBy = growBy,
		ceiling = ceiling,
		total = initial,
		inUse = 0,
		pending = 0,
	}
end

local function poolOf(mode: Mode): Pool
	local pool: Pool? = Pools[mode]
	assert(pool, `Echo: config.cache gives {mode} no pool; it sizes one pool for each Mode the game plays`)

	return pool
end

-- Makes some of the running growth step's voices
local function make(pool: Pool, count: number)
	Cellar:add(pool.template, count, nil, pool.category)
	pool.total += count
	pool.pending -= count
end

-- Makes a few of each running step's voices a frame, since cloning a whole step on one frame costs milliseconds
local function grow()
	local running: boolean = false
	for _, pool: Pool in Pools do
		if pool.pending > 0 then
			make(pool, math.min(Constants.GROW_PER_FRAME, pool.pending))
			running = running or pool.pending > 0
		end
	end

	-- Disconnected on the frame no step remains, and connected again by the next step to start
	if growth and not running then
		growth:Disconnect()
		growth = nil
	end
end

-- Starts a growth step of growBy voices, cut so the pool never passes its ceiling
local function startGrowth(pool: Pool)
	pool.pending = math.min(pool.growBy, pool.ceiling - pool.total)

	if not growth then
		growth = RunService.Heartbeat:Connect(grow)
	end
end

-- Whiteoak TODO: an O(n) scan of every live voice, both ceilings at most; per-group and per-Mode lists if it shows
local function earliest(matches: (voice: VoiceToken) -> boolean): VoiceToken?
	for _, voice: VoiceToken in Live do
		if matches(voice) then
			return voice
		end
	end

	return nil
end

--[[
    Takes a voice for one play. A capped group gives back its
    earliest-started voice first, a pool with no free voice below its
    ceiling makes one at once, and at the ceiling the earliest-started
    one-shot gives up its voice. Nil means the pool is at its ceiling with
    nothing but loops playing
--]]

function Cache.take(mode: Mode, request: TakeRequest): VoiceToken?
	local pool: Pool = poolOf(mode)
	local group: string? = request.group
	local limit: number? = request.limit

	-- 1) A capped play frees its own voice first
	if group and limit and (Groups[group] or 0) >= limit then
		local oldest: VoiceToken? = earliest(function (voice: VoiceToken): boolean
			return voice.group == group
		end)

		if oldest then
			Cache.give(oldest)
		end
	end

	-- 2) Take a free voice, or make one at once below the ceiling, so a play never waits on a step's frames
	local copies: { Instance }? = Cellar:get(nil, pool.category)
	if not copies and pool.total < pool.ceiling then
		-- The voice counts against the running step, so a step still makes growBy voices in all
		if pool.pending == 0 then
			startGrowth(pool)
		end

		make(pool, 1)
		copies = Cellar:get(nil, pool.category)
	end

	-- 3) At the ceiling the earliest one-shot gives up its voice, and a loop never does
	if not copies then
		local oldest: VoiceToken? = earliest(function (voice: VoiceToken): boolean
			return voice.mode == mode and not voice.looped
		end)

		if oldest then
			Cache.give(oldest)
			copies = Cellar:get(nil, pool.category)
		end
	end

	if not copies then
		return nil
	end

	local tree = copies[1] :: Attachment
	takes += 1

	local voice: VoiceToken = {
		instance = pool.backend.playable(tree),
		tree = tree,
		mode = mode,
		order = takes,
		looped = request.looped,
		group = group,
		release = request.release,
	}

	table.insert(Live, voice)
	pool.inUse += 1

	if group then
		Groups[group] = (Groups[group] or 0) + 1
	end

	-- 4) Grow ahead of need once the free voices fall to the pool's margin, one step at a time
	if pool.pending == 0 and pool.total < pool.ceiling and pool.total - pool.inUse <= pool.margin then
		startGrowth(pool)
	end

	return voice
end

local function unfollow(voice: VoiceToken)
	Following[voice] = nil

	if heartbeat and next(Following) == nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

--[[
    Gives a voice back to its pool, the one path every voice returns by.
    A voice already given back is left alone
--]]

function Cache.give(voice: VoiceToken)
	local index: number? = table.find(Live, voice)
	if not index then
		return
	end

	-- The records go first, so a give from inside the release hook finds the voice already back
	local pool: Pool = poolOf(voice.mode)
	table.remove(Live, index)
	pool.inUse -= 1

	local group: string? = voice.group
	if group then
		local held: number = Groups[group] - 1
		Groups[group] = held > 0 and held or nil
	end

	voice.release(voice)
	pool.backend.clear(voice.tree)
	unfollow(voice)
	Cellar:rebound(voice.tree)
	voice.instance = nil
end

--[[
    Writes a voice's position from its target, and reports false for a
    target no voice follows: one outside the DataModel, or one with no
    position of its own
--]]

local function place(voice: VoiceToken, target: Instance): boolean
	local position: Vector3
	if not target:IsDescendantOf(game) then
		return false
	elseif target:IsA("BasePart") then
		position = (target :: BasePart).Position
	elseif target:IsA("Attachment") then
		position = (target :: Attachment).WorldPosition
	elseif target:IsA("Model") then
		position = (target :: Model):GetPivot().Position
	else
		return false
	end

	poolOf(voice.mode).backend.place(voice.tree, position)

	return true
end

-- A voice whose target left the DataModel stays where it last was
local function step()
	for voice: VoiceToken, target: Instance in Following do
		if not place(voice, target) then
			unfollow(voice)
		end
	end
end

--[[
    Has a live voice follow a BasePart, Attachment or Model, placed at once
    and on every Heartbeat until it is given back or its target leaves the
    DataModel. Any other target, nil included, stops it following. The one
    Heartbeat connection is released once no voice follows
--]]

function Cache.follow(voice: VoiceToken, target: Instance?)
	if not target or not voice.instance or not place(voice, target) then
		unfollow(voice)
		return
	end

	Following[voice] = target
	if not heartbeat then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

--[[
    A Mode's voices in use and the voices its pool has made so far, from
    the cache's own counts, so reading them costs nothing on a play
--]]

function Cache.count(mode: Mode): CacheCount
	local pool: Pool = poolOf(mode)

	return { inUse = pool.inUse, size = pool.total }
end

return Cache
