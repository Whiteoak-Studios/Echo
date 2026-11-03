--[[
    The pools of voices Echo plays from, one Cellar category under Terrain
    per Mode: taking a voice under its cap, growing and stealing at the
    ceiling, giving a voice back, and following a voice's target
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
	size: CacheSize,
	backend: Backend,
	template: Attachment, -- Every voice is cloned from this one tree, so growing makes no template
	total: number, -- The voices the pool holds, free and out
	inUse: number,
}

local Pools: { [Mode]: Pool } = {}
local Live: { VoiceToken } = {} -- Every voice out of either pool, in start order
local Groups: { [string]: number } = {} -- How many live voices each cap group holds
local Following: { [VoiceToken]: Instance } = {} -- Each followed voice's target

local takes: number = 0 -- Every take so far, which gives each voice its start order
local heartbeat: RBXScriptConnection? = nil -- Held only while some voice follows a target

local Cache = {}

local function checkCount(mode: Mode, field: string, value: number)
	assert(
		type(value) == "number" and value >= 1 and value % 1 == 0,
		`Cache.create needs {mode}'s {field} to be a whole number of 1 or more, not {value}`
	)
end

--[[
    Declares a Mode's pool under Terrain and fills it with its initial
    voices, all cloned from one template the backend builds
--]]

function Cache.create(mode: Mode, size: CacheSize, backend: Backend)
	checkCount(mode, "initial", size.initial)
	checkCount(mode, "growAt", size.growAt)
	checkCount(mode, "growBy", size.growBy)
	checkCount(mode, "ceiling", size.ceiling)

	assert(size.growAt <= size.initial, `Cache.create needs {mode}'s growAt to be at most its initial`)
	assert(size.ceiling >= size.initial, `Cache.create needs {mode}'s ceiling to be at least its initial`)

	local category: string = Constants.CATEGORIES[mode]
	local template: Attachment = backend.template()

	Cellar:create(category, Workspace.Terrain)
	Cellar:add(template, size.initial, nil, category)

	Pools[mode] = {
		category = category,
		size = size,
		backend = backend,
		template = template,
		total = size.initial,
		inUse = 0,
	}
end

local function poolOf(mode: Mode): Pool
	local pool: Pool? = Pools[mode]
	assert(pool, `The cache has no pool for {mode}; Cache.create makes one`)

	return pool
end

-- Adds a growth step of voices, never past the ceiling
local function grow(pool: Pool)
	if pool.total >= pool.size.ceiling then
		return
	end

	local count: number = math.min(pool.size.growBy, pool.size.ceiling - pool.total)
	Cellar:add(pool.template, count, nil, pool.category)
	pool.total += count
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
    earliest-started voice first, an empty pool grows up to its ceiling,
    and at the ceiling the earliest-started one-shot gives up its voice.
    Nil means the pool is at its ceiling with nothing but loops playing
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

	-- 2) Take a free voice, growing first when none is free
	local copies: { Instance }? = Cellar:get(nil, pool.category)
	if not copies then
		grow(pool)
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

	-- 4) Grow ahead of need once the free voices fall to the pool's margin
	if pool.total - pool.inUse <= pool.size.initial - pool.size.growAt then
		grow(pool)
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
    A Mode's voices in use and its pool's size, from the cache's own
    counts, so reading them costs nothing on a play
--]]

function Cache.count(mode: Mode): CacheCount
	local pool: Pool = poolOf(mode)

	return { inUse = pool.inUse, size = pool.total }
end

return Cache
