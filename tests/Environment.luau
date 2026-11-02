--[[
    Builds a fresh fake game for each case, with a package mounted at
    ReplicatedStorage.Packages.Echo beside Promise and Cellar on a clock the
    case steps, and runs a case to the case contract
--]]

--!strict
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox: any = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local AudioApi = require("./Fakes/AudioApi")
local Clock = require("./Fakes/Clock")
local ContentProvider = require("./Fakes/ContentProvider")
local DataModel = require("./Fakes/DataModel")
local Instance = require("./Fakes/Instance")
local Players = require("./Fakes/Players")
local RunService = require("./Fakes/RunService")
local Signal = require("./Fakes/Signal")
local Sound = require("./Fakes/Sound")
local World = require("./Fakes/World")

local PACKAGE: string = "Echo"
local FIXTURES: string = "tests/Fixtures"
local SIFT: string = "tests/Fakes/Sift.luau"
local CASE_LIMIT: number = 30 -- Real seconds a case may take before it counts as parked
local LINK: string = `_Index%["([^"]+)"%]%["([^"]+)"%]` -- The folder a Wally link file points its alias at

type Source = {
	folder: string,
	extension: string,
}

-- The sources a case names, and the extension each one's files carry
local SOURCES: { [string]: Source } = {
	src = { folder = "src", extension = "luau" },
	legacy = { folder = ".legacy/src", extension = "lua" },
}

-- The packages the package under test finds beside it, as Wally installs them
local DEPENDENCIES: { string } = { "Cellar", "Promise" }

local FAMILIES: { Instance.Family } = {
	DataModel :: any,
	World :: any,
	Sound :: any,
	AudioApi :: any,
	RunService :: any,
	ContentProvider :: any,
	Players :: any,
}

type World = Instance.World

export type Options = {
	source: string?, -- "src" by default, "legacy" for 7.8.6 in .legacy/src, or a folder under tests/Fixtures
	studio: boolean?, -- What RunService:IsStudio() answers, false by default
	client: boolean?, -- What RunService:IsClient() answers, true by default, as Echo runs on the client
	dependencies: { [string]: any }?, -- What a require of each named sibling gives, in place of what it holds
}

export type Environment = {
	game: any,
	Instance: { new: (className: string) -> any },
	task: Clock.Task,
	warnings: { string }, -- Every warn the package made, its arguments joined by spaces
	errors: { string }, -- Every error a thread from the fake task library or a fake event threw
	preload: Instance.Preload,
	require: (path: string?) -> any,
	step: (seconds: number) -> (),
	now: () -> number,
	connections: (signal: any) -> number,
	set: (instance: any, property: string, value: any) -> (),
	finish: (playable: any) -> (),
	loop: (playable: any) -> (),
	load: (playable: any) -> (),
}

type Module = {
	path: string,
	loading: boolean,
	loaded: boolean,
	result: any,
}

type State = {
	world: World,
	globals: { [string]: any },
	modules: { [any]: Module }, -- Each ModuleScript this environment mounted, by the instance
	paths: { [string]: any }, -- The package's ModuleScripts by their path below its root, the root under ""
}

-- Files read once a run, when mounted, since a read yields and a require on a clocked thread must not
local Sources: { [string]: string } = {}
local Bytecode: { [string]: string } = {}

-- The errors list of each environment built while the current Environment.run runs, which it reads when the case returns
local Built: { { string } } = {}

local Environment = {}

local function initFile(folder: string): (string?, string?)
	for _, extension: string in { "luau", "lua" } do
		local path: string = `{folder}/init.{extension}`
		if fs.isFile(path) then
			return path, extension
		end
	end

	return nil, nil
end

--[[
    Finds an installed dependency's root folder through the link file Wally
    writes for its alias and the project file the dependency ships
--]]

local function installed(alias: string): string
	local link: string = `Packages/{alias}.lua`
	assert(fs.isFile(link), `{link} is missing; run wally install`)

	local folder: string?, name: string? = fs.readFile(link):match(LINK)
	assert(folder and name, `{link} names no installed folder; run wally install`)

	local root: string = `Packages/_Index/{folder}/{name}`
	local project: any = serde.decode("json", fs.readFile(`{root}/default.project.json`))

	return `{root}/{project.tree["$path"]}`
end

--[[
    Loads the harness's own copy of Promise on Lune's task. The fake clock
    parks a waiting thread on one of its pending promises, so a resume runs
    the thread at once, and the package under test never sees this copy
--]]

local function ownPromise(): any
	local path: string? = initFile(installed("Promise"))
	assert(path, "The installed Promise has no init file")

	local heartbeat: any = setmetatable({}, {
		__index = function (_: any, key: any)
			error(`The harness's own Promise reached for Heartbeat.{key}, which a pending promise never needs`)
		end,
	})

	local runService: { [string]: any } = { Heartbeat = heartbeat }
	local environment: { [string]: any } = {
		task = task,
		game = {
			GetService = function (): any
				return runService
			end,
		},
	}

	return luau.load(fs.readFile(path), { debugName = path, environment = environment })()
end

local PARKING: any = ownPromise()

--[[
    Runs a mounted ModuleScript's file once per environment, with script set
    to it, as require does in Roblox
--]]

local function load(state: State, module: any): any
	local record: Module? = state.modules[module]
	if not record then
		error(
			`require was given {state.world.typeof(module)} {module}, which is no ModuleScript this environment mounted`,
			3
		)
	elseif record.loaded then
		return record.result
	elseif record.loading then
		error(`{module:GetFullName()} was required while it was still loading`, 3)
	end

	if not Bytecode[record.path] then
		Bytecode[record.path] = luau.compile(Sources[record.path])
	end

	local scope: { [string]: any } = table.clone(state.globals)
	scope.script = module

	record.loading = true
	local chunk: (...any) -> ...any = luau.load(Bytecode[record.path], { debugName = record.path, environment = scope })
	local results: { n: number, [number]: any } = table.pack(pcall(chunk))
	record.loading = false

	if not results[1] then
		error(results[2], 0)
	elseif results.n ~= 2 then
		error(`{record.path} returned {results.n - 1} values, where a module returns exactly one`, 3)
	end

	record.loaded = true
	record.result = results[2]

	return results[2]
end

local function addModule(state: State, name: string, parent: any, path: string, relative: string?): any
	local module: any = state.world.new("ModuleScript")
	module.Name = name
	module.Parent = parent

	if not Sources[path] then
		Sources[path] = fs.readFile(path)
	end

	state.modules[module] = { path = path, loading = false, loaded = false, result = nil }
	if relative then
		state.paths[relative] = module
	end

	return module
end

--[[
    Mounts a folder's contents as Rojo maps them: a file is a ModuleScript,
    a folder holding an init file is one too, and any other folder is a
    Folder. A prefix records each module's path for env.require
--]]

local function mount(state: State, parent: any, directory: string, extension: string, prefix: string?)
	local names: { string } = fs.readDir(directory)
	table.sort(names)

	for _, name: string in names do
		local path: string = `{directory}/{name}`

		if fs.isDir(path) then
			local init: string = `{path}/init.{extension}`
			local child: any

			if fs.isFile(init) then
				child = addModule(state, name, parent, init, prefix and `{prefix}{name}`)
			else
				child = state.world.new("Folder")
				child.Name = name
				child.Parent = parent
			end

			mount(state, child, path, extension, prefix and `{prefix}{name}/`)
		else
			local stem: string? = name:match(`^(.+)%.{extension}$`)
			if stem and stem ~= "init" then
				addModule(state, stem, parent, path, prefix and `{prefix}{stem}`)
			end
		end
	end
end

local function sourceOf(name: string): Source
	local known: Source? = SOURCES[name]
	local source: Source = known or { folder = `{FIXTURES}/{name}`, extension = "luau" }

	if not fs.isFile(`{source.folder}/init.{source.extension}`) then
		local hint: string = name == "legacy" and "; run lune run legacy first" or ""
		error(`{source.folder} has no init.{source.extension}{hint}`, 3)
	end

	return source
end

--[[
    Builds a fresh environment: a new fake game, clock and module cache,
    with the source mounted where a game installs it and its dependencies
    beside it, so nothing a module holds outlives the case that loaded it
--]]

function Environment.new(options: Options?): Environment
	local given: Options = options or {}
	local sourceName: string = given.source or "src"
	local source: Source = sourceOf(sourceName)

	local settings: Instance.Settings = {
		studio = given.studio == true,
		client = given.client ~= false,
		preload = { calls = {}, statuses = {}, error = nil },
	}

	local clock: Clock.Clock = Clock.new(PARKING)
	local world: World = Instance.world(clock, settings, FAMILIES)

	-- A case that expects an error reads it from env.errors and then clears the list, or Environment.run fails the case
	table.insert(Built, clock.errors)
	local game: any = world.create("DataModel")
	local warnings: { string } = {}

	local packages: any = world.new("Folder")
	packages.Name = "Packages"
	packages.Parent = game:GetService("ReplicatedStorage")

	local state: State = {
		world = world,
		globals = {},
		modules = {},
		paths = {},
	}

	state.globals = {
		game = game,
		workspace = game.Workspace,
		Instance = { new = world.new },
		task = clock.task,
		os = clock.os,
		tick = clock.tick,
		typeof = world.typeof,
		type = world.type,

		require = function (module: any): any
			return load(state, module)
		end,

		warn = function (...: any)
			local parts: { string } = {}
			for index: number = 1, select("#", ...) do
				table.insert(parts, tostring((select(index, ...))))
			end

			table.insert(warnings, table.concat(parts, " "))
		end,
	}

	-- The Roblox datatypes and Enum, which Lune's library holds under the names Roblox gives them
	for name: string, value: any in roblox do
		if name:match("^%u") and name ~= "Instance" then
			state.globals[name] = value
		end
	end

	local root: any = addModule(state, PACKAGE, packages, `{source.folder}/init.{source.extension}`, "")
	mount(state, root, source.folder, source.extension, "")

	for _, alias: string in DEPENDENCIES do
		local folder: string = installed(alias)
		local init: string?, extension: string? = initFile(folder)
		assert(init and extension, `The installed {alias} has no init file`)

		mount(state, addModule(state, alias, packages, init, nil), folder, extension, nil)
	end

	if sourceName == "legacy" then
		addModule(state, "Sift", packages, SIFT, nil)
	end

	for name: string, value: any in given.dependencies or {} do
		local module: any = packages:FindFirstChild(name)
		if not module then
			module = world.new("ModuleScript")
			module.Name = name
			module.Parent = packages
		end

		state.modules[module] = { path = `{name} given by the case`, loading = false, loaded = true, result = value }
	end

	local runService: any = game:GetService("RunService")

	local function frame(delta: number)
		if settings.client then
			world.fire(runService, "RenderStepped", delta)
		end

		world.fire(runService, "Heartbeat", delta)
	end

	local function playback(helper: string): (playable: any) -> ()
		return function (playable: any)
			if world.is(playable) and playable:IsA("Sound") then
				(Sound :: any)[helper](world, playable)
			elseif world.is(playable) and playable:IsA("AudioPlayer") then
				(AudioApi :: any)[helper](world, playable)
			else
				error(`env.{helper} takes a Sound or an AudioPlayer, not {world.typeof(playable)}`, 2)
			end
		end
	end

	return {
		game = game,
		Instance = state.globals.Instance,
		task = clock.task,
		warnings = warnings,
		errors = clock.errors,
		preload = settings.preload,
		now = clock.now,
		connections = Signal.count,
		set = world.set,
		finish = playback("finish"),
		loop = playback("loop"),
		load = playback("load"),

		require = function (path: string?): any
			local module: any? = state.paths[path or ""]
			if not module then
				error(`{source.folder} has no module {path}`, 2)
			end

			return load(state, module)
		end,

		step = function (seconds: number)
			clock.step(seconds, frame)
		end,
	}
end

--[[
    Runs one case to the case contract on a thread of its own: it fails when
    it is no function, throws, is still running at the limit, leaves an
    error in any environment it built, or returns anything but true first.
    Nothing resumes a case parked on the fake clock, and Lune ends a run
    without a word when its main thread parks
--]]

function Environment.run(case: any, limit: number?): (boolean, string | nil)
	if type(case) ~= "function" then
		return false, `it returned a {type(case)}, not a function`
	end

	local seconds: number = limit or CASE_LIMIT
	local finished: boolean = false
	local ran: boolean, passed: any, reason: any = false, nil, nil

	-- A run inside a case keeps its own list, and the outer run's comes back once it ends
	local outer: { { string } } = Built
	local built: { { string } } = {}
	Built = built

	task.spawn(function ()
		ran, passed, reason = pcall(case)
		finished = true
	end)

	local deadline: number = os.clock() + seconds
	while not finished and os.clock() < deadline do
		task.wait()
	end

	Built = outer

	if not finished then
		return false, `it had not finished after {seconds} s; a case steps the fake clock instead of waiting on it`
	elseif not ran then
		return false, `it threw: {passed}`
	end

	for _, errors: { string } in built do
		if errors[1] then
			return false, `it left an error in env.errors, which a case that expects one reads and clears: {errors[1]}`
		end
	end

	if passed ~= true then
		return false, reason ~= nil and `{reason}` or `it returned {passed} with no reason`
	end

	return true, nil
end

return Environment
