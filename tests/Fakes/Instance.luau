--[[
    The fake instances a world is made of: tables whose class tree, property
    names, types and defaults come from Lune's reflection database, whose
    members come from the fake families, and whose every write is checked
--]]

--!strict
local roblox: any = require("@lune/roblox")

local Clock = require("./Clock")
local Signal = require("./Signal")

local DATABASE: any = roblox.getReflectionDatabase()
local ATTRIBUTE_NAME: string = "^[%w_]+$"
local ATTRIBUTE_NAME_LIMIT: number = 100 -- Characters, as the engine caps an attribute's name
local RESERVED_ATTRIBUTE_PREFIX: string = "RBX"

local NUMBERS: { [string]: boolean } = { Float32 = true, Float64 = true, Int32 = true, Int64 = true }
local STRINGS: { [string]: boolean } = { String = true, ContentId = true }
local SCRIPTABLE: { [string]: boolean } = { ReadWrite = true, Read = true }
local NEW_DEFAULTS: { [string]: boolean } = { Vector3 = true, Vector2 = true, CFrame = true, Color3 = true }

-- The types the engine stores in an attribute
local ATTRIBUTE_TYPES: { [string]: boolean } = {
	string = true,
	boolean = true,
	number = true,
	UDim = true,
	UDim2 = true,
	BrickColor = true,
	Color3 = true,
	Vector2 = true,
	Vector3 = true,
	CFrame = true,
	NumberSequence = true,
	ColorSequence = true,
	NumberRange = true,
	Rect = true,
	Font = true,
	EnumItem = true,
}

type Clock = Clock.Clock

-- Whiteoak TODO: a property a getter works out fires no changed signal; fire it beside the stored one once a case listens
export type Spec = {
	internal: boolean?, -- Made only by the harness, never by Instance.new
	events: { string }?,
	methods: { [string]: (...any) -> ...any }?,
	get: { [string]: (instance: any) -> any }?, -- Reads worked out from other properties
	set: { [string]: (instance: any, value: any) -> () }?, -- Writes, after the value passed its type check
	init: ((instance: any) -> ())?, -- Runs on each new instance of the class, never on a clone
}

export type Preload = {
	calls: { { string } }, -- The ids of each PreloadAsync call, in order
	statuses: { [string]: any }, -- The AssetFetchStatus a case gives an id; Success when it gives none
	error: string?, -- A message PreloadAsync throws, when a case sets one
}

export type Settings = {
	studio: boolean,
	client: boolean,
	preload: Preload,
}

export type World = {
	clock: Clock,
	settings: Settings,
	new: (className: string) -> any,
	create: (className: string) -> any,
	read: (instance: any, property: string) -> any,
	write: (instance: any, property: string, value: any) -> (),
	set: (instance: any, property: string, value: any) -> (),
	fire: (instance: any, event: string, ...any) -> (),
	is: (value: any) -> boolean,
	typeof: (value: any) -> string,
	type: (value: any) -> string,
}

export type Family = {
	classes: (world: World) -> { [string]: Spec },
}

type Property = {
	datatype: string,
	readOnly: boolean,
}

type Class = {
	name: string,
	tags: { string },
	ancestors: { [string]: boolean },
	properties: { [string]: Property },
	defaults: { [string]: any },
	methods: { [string]: (...any) -> ...any },
	events: { [string]: boolean },
	get: { [string]: (instance: any) -> any },
	set: { [string]: (instance: any, value: any) -> () },
	init: { (instance: any) -> () }, -- From the base class down
	creatable: boolean,
}

type Record = {
	class: Class,
	clock: Clock,
	values: { [string]: any }, -- Every property but Parent, and what a family keeps under a name no script can read
	attributes: { [string]: any },
	children: { any },
	parent: any,
	events: { [string]: any }, -- Each event's signal, made when first read
	changed: { [string]: any }, -- Each property's changed signal, made when first asked for
	destroyed: boolean,
}

-- The key each instance keeps its record under, which no code outside this file can name
local RECORD: { nil } = {}

local Metatable: { [string]: any } = {}

local Instance = {}

local function isInstance(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Metatable
end

-- The message is built only on failure, since naming an instance reads its record through here
local function recordOf(instance: any): Record
	if not isInstance(instance) then
		error(`{typeof(instance)} {instance} is not a fake instance`, 2)
	end

	return rawget(instance, RECORD)
end

local function typeOf(value: any): string
	if isInstance(value) then
		return "Instance"
	elseif Signal.is(value) then
		return "RBXScriptSignal"
	elseif Signal.isConnection(value) then
		return "RBXScriptConnection"
	end

	return typeof(value)
end

local function enumNamed(datatype: string): any?
	local found: boolean, enum: any = pcall(function (): any
		return roblox.Enum[datatype:sub(#"Enum." + 1)]
	end)

	return found and enum or nil
end

--[[
    The value a property starts at when the database gives it no default:
    the zero of its type, or the enum item of lowest value
--]]

local function fallback(datatype: string): any
	if datatype == "Bool" then
		return false
	elseif NUMBERS[datatype] then
		return 0
	elseif STRINGS[datatype] then
		return ""
	elseif datatype == "NumberRange" then
		return roblox.NumberRange.new(0)
	elseif NEW_DEFAULTS[datatype] then
		return roblox[datatype].new()
	end

	local enum: any? = datatype:sub(1, #"Enum.") == "Enum." and enumNamed(datatype) or nil
	if not enum then
		return nil
	end

	local items: { any } = enum:GetEnumItems()
	table.sort(items, function (first: any, second: any): boolean
		return first.Value < second.Value
	end)

	return items[1]
end

--[[
    An enum property takes one of its enum's items, or an item's name or
    value, as the engine coerces them
--]]

local function enumItem(datatype: string, value: any): any?
	local enum: any? = enumNamed(datatype)
	if not enum then
		return nil
	elseif typeOf(value) == "EnumItem" then
		return tostring(value.EnumType) == tostring(enum) and value or nil
	elseif type(value) == "string" then
		local found: boolean, item: any = pcall(function (): any
			return enum[value]
		end)

		return found and item or nil
	elseif type(value) == "number" then
		for _, item: any in enum:GetEnumItems() do
			if item.Value == value then
				return item
			end
		end
	end

	return nil
end

--[[
    Checks a value against a property's datatype as the engine does on a
    write, giving the value to store or the reason it was refused
--]]

local function check(property: Property, value: any): (boolean, any)
	local datatype: string = property.datatype
	local given: string = typeOf(value)

	if datatype == "Ref" then
		if value == nil or isInstance(value) then
			return true, value
		end

		return false, `Object expected, got {given}`
	elseif datatype == "Bool" then
		if type(value) == "boolean" then
			return true, value
		end

		return false, `bool expected, got {given}`
	elseif NUMBERS[datatype] then
		if type(value) == "number" then
			return true, value
		end

		return false, `number expected, got {given}`
	elseif STRINGS[datatype] then
		if type(value) == "number" then
			return true, tostring(value)
		elseif type(value) == "string" then
			return true, value
		end

		return false, `string expected, got {given}`
	elseif datatype:sub(1, #"Enum.") == "Enum." then
		local item: any? = enumItem(datatype, value)
		if item then
			return true, item
		end

		return false, `{datatype} expected, got {given}`
	elseif given == datatype then
		return true, value
	end

	return false, `{datatype} expected, got {given}`
end

local function fullName(instance: any): string
	local names: { string } = {}
	local current: any = instance

	-- The engine leaves the DataModel out of any name but its own
	while current do
		local record: Record = recordOf(current)
		if record.class.name == "DataModel" and current ~= instance then
			break
		end

		table.insert(names, 1, record.values.Name)
		current = record.parent
	end

	return table.concat(names, ".")
end

local function descendants(instance: any): { any }
	local found: { any } = {}

	local function walk(parent: any)
		for _, child: any in recordOf(parent).children do
			table.insert(found, child)
			walk(child)
		end
	end

	walk(instance)

	return found
end

local function isDescendantOf(instance: any, ancestor: any): boolean
	local current: any = recordOf(instance).parent
	while current do
		if current == ancestor then
			return true
		end

		current = recordOf(current).parent
	end

	return false
end

local function event(instance: any, name: string): any
	local record: Record = recordOf(instance)
	local signal: any = record.events[name]
	if not signal then
		signal = Signal.new(record.clock)
		record.events[name] = signal
	end

	return signal
end

local function fire(instance: any, name: string, ...: any)
	local signal: any = recordOf(instance).events[name]
	if signal then
		Signal.fire(signal, ...)
	end
end

local function write(instance: any, property: string, value: any)
	local record: Record = recordOf(instance)
	local old: any = record.values[property]
	record.values[property] = value

	local changed: any = record.changed[property]
	if changed and old ~= value then
		Signal.fire(changed)
	end
end

local function setParent(instance: any, parent: any)
	local record: Record = recordOf(instance)
	local writer: number = 3 -- The line that wrote, past this function and the metatable's

	if record.destroyed then
		local newName: string = parent and isInstance(parent) and recordOf(parent).values.Name or "NULL"
		error(
			`The Parent property of {record.values.Name} is locked, current parent: NULL, new parent {newName}`,
			writer
		)
	elseif parent ~= nil and not isInstance(parent) then
		error(`Unable to assign property Parent. Object expected, got {typeOf(parent)}`, writer)
	elseif parent == record.parent then
		return
	elseif parent == instance or (parent and isDescendantOf(parent, instance)) then
		error(`Attempt to set {fullName(instance)} as its own parent`, writer)
	end

	local old: any = record.parent
	if old then
		local siblings: { any } = recordOf(old).children
		table.remove(siblings, table.find(siblings, instance) :: number)
	end

	record.parent = parent
	if parent then
		table.insert(recordOf(parent).children, instance)
	end

	local changed: any = record.changed.Parent
	if changed then
		Signal.fire(changed)
	end

	fire(instance, "AncestryChanged", instance, parent)
	for _, descendant: any in descendants(instance) do
		fire(descendant, "AncestryChanged", instance, parent)
	end

	if parent then
		fire(parent, "ChildAdded", instance)
	end
end

local function instantiate(class: Class, clock: Clock): any
	local record: Record = {
		class = class,
		clock = clock,
		values = table.clone(class.defaults),
		attributes = {},
		children = {},
		parent = nil,
		events = {},
		changed = {},
		destroyed = false,
	}

	return setmetatable({ [RECORD] = record }, Metatable)
end

--[[
    Copies an instance and its archivable descendants, and points every
    reference inside the copied tree at the copy, as the engine's Clone does
--]]

local function clone(instance: any): any?
	if not recordOf(instance).values.Archivable then
		return nil
	end

	local copies: { [any]: any } = {}

	local function copy(original: any): any
		local source: Record = recordOf(original)
		local twin: any = instantiate(source.class, source.clock)
		local target: Record = recordOf(twin)
		target.values = table.clone(source.values)
		target.attributes = table.clone(source.attributes)
		copies[original] = twin

		for _, child: any in source.children do
			if recordOf(child).values.Archivable then
				local childTwin: any = copy(child)
				recordOf(childTwin).parent = twin
				table.insert(target.children, childTwin)
			end
		end

		return twin
	end

	local root: any = copy(instance)

	for _, twin: any in copies do
		local record: Record = recordOf(twin)
		for name: string, property: Property in record.class.properties do
			local value: any = record.values[name]
			if property.datatype == "Ref" and value ~= nil and copies[value] then
				record.values[name] = copies[value]
			end
		end
	end

	return root
end

--[[
    Destroys as the engine does in immediate signal mode: Destroying fires,
    the instance leaves its parent with its Parent locked and its events
    ended, then each child is destroyed the same way
--]]

local function destroy(instance: any)
	local record: Record = recordOf(instance)
	if record.destroyed then
		return
	end

	fire(instance, "Destroying")
	if record.parent then
		setParent(instance, nil)
	end

	record.destroyed = true
	for _, signal: any in record.events do
		Signal.clear(signal)
	end

	for _, signal: any in record.changed do
		Signal.clear(signal)
	end

	for _, child: any in table.clone(record.children) do
		destroy(child)
	end
end

local function notMember(instance: any, key: any): string
	local record: Record = recordOf(instance)

	return `{key} is not a valid member of {record.class.name} "{fullName(instance)}"`
end

Metatable.__index = function (instance: any, key: any): any
	local record: Record = rawget(instance, RECORD)
	local class: Class = record.class

	local getter: ((instance: any) -> any)? = class.get[key]
	if getter then
		return getter(instance)
	elseif key == "Parent" then
		return record.parent
	elseif class.properties[key] then
		return record.values[key]
	elseif class.methods[key] then
		return class.methods[key]
	elseif class.events[key] then
		return event(instance, key)
	end

	-- A child is found by name only after every member, as the engine looks
	for _, child: any in record.children do
		if recordOf(child).values.Name == key then
			return child
		end
	end

	error(notMember(instance, key), 2)
end

Metatable.__newindex = function (instance: any, key: any, value: any)
	local class: Class = recordOf(instance).class

	if key == "Parent" then
		setParent(instance, value)
		return
	end

	local property: Property? = class.properties[key]
	local setter: ((instance: any, value: any) -> ())? = class.set[key]
	if not property and not setter then
		error(notMember(instance, key), 2)
	end

	local stored: any = value
	if property then
		if property.readOnly then
			error(`Unable to assign property {key}. Property is read only`, 2)
		end

		local passed: boolean, result: any = check(property, value)
		if not passed then
			error(`Unable to assign property {key}. {result}`, 2)
		end

		stored = result
	end

	if setter then
		setter(instance, stored)
	else
		write(instance, key, stored)
	end
end

Metatable.__tostring = function (instance: any): string
	return recordOf(instance).values.Name
end

--[[
    Builds a class from its database entry and the specs of it and each
    class above it, a derived class's member winning over its base's
--]]

local function build(specs: { [string]: Spec }, name: string): Class?
	local database: any = DATABASE:GetClass(name)
	if not database then
		return nil
	end

	local chain: { any } = {}
	local current: any = database
	while current do
		table.insert(chain, 1, current)
		current = current.Superclass and DATABASE:GetClass(current.Superclass) or nil
	end

	local spec: Spec? = specs[name]
	local class: Class = {
		name = name,
		tags = database.Tags,
		ancestors = {},
		properties = {},
		defaults = {},
		methods = {},
		events = {},
		get = {},
		set = {},
		init = {},
		creatable = spec ~= nil
			and not spec.internal
			and not table.find(database.Tags, "NotCreatable")
			and not table.find(database.Tags, "Service"),
	}

	for _, entry: any in chain do
		class.ancestors[entry.Name] = true

		-- A lowercase name is a deprecated alias the engine keeps beside the property
		for propertyName: string, property: any in entry.Properties do
			if SCRIPTABLE[property.Scriptability] and propertyName:match("^%u") then
				class.properties[propertyName] = {
					datatype = property.Datatype,
					readOnly = property.Scriptability == "Read",
				}
			end
		end

		local own: Spec? = specs[entry.Name]
		if own then
			for _, eventName: string in own.events or {} do
				class.events[eventName] = true
			end

			for methodName: string, method: (...any) -> ...any in own.methods or {} do
				class.methods[methodName] = method
			end

			for propertyName: string, getter: (instance: any) -> any in own.get or {} do
				class.get[propertyName] = getter
			end

			for propertyName: string, setter: (instance: any, value: any) -> () in own.set or {} do
				class.set[propertyName] = setter
			end

			if own.init then
				table.insert(class.init, own.init)
			end
		end
	end

	for propertyName: string, property: Property in class.properties do
		local default: any = database.DefaultProperties[propertyName]
		if default == nil then
			default = fallback(property.datatype)
		end

		class.defaults[propertyName] = default
	end

	class.defaults.Name = name

	return class
end

--[[
    Builds one environment's world: the class specs of every family over
    the members every instance has, and the functions the families, the
    environment and the package's Instance.new reach it through
--]]

function Instance.world(clock: Clock, settings: Settings, families: { Family }): World
	local specs: { [string]: Spec } = {}
	local classes: { [string]: Class } = {}

	local function classNamed(name: string): Class?
		local cached: Class? = classes[name]
		if not cached then
			cached = build(specs, name)
			classes[name] = cached
		end

		return cached
	end

	local function create(className: string): any
		local class: Class? = classNamed(className)
		if not class then
			error(`The fake game has no class {className}`, 2)
		end

		local instance: any = instantiate(class, clock)
		for _, init: (instance: any) -> () in class.init do
			init(instance)
		end

		return instance
	end

	local function new(className: any): any
		local class: Class? = type(className) == "string" and classNamed(className) or nil
		if class and class.creatable then
			return create(className)
		elseif class and not specs[className] and not table.find(class.tags, "NotCreatable") then
			error(`The harness fakes no {className}; add it to a family in tests/Fakes`, 2)
		end

		error(`Unable to create an Instance of type "{className}"`, 2)
	end

	local function find(instance: any, name: string, recursive: boolean?): any?
		local candidates: { any } = recursive and descendants(instance) or recordOf(instance).children
		for _, child: any in candidates do
			if recordOf(child).values.Name == name then
				return child
			end
		end

		return nil
	end

	specs.Instance = {
		events = { "Destroying", "AncestryChanged", "ChildAdded" },

		get = {
			ClassName = function (instance: any): string
				return recordOf(instance).class.name
			end,
		},

		set = {
			ClassName = function ()
				error("Unable to assign property ClassName. Property is read only", 3)
			end,
		},

		methods = {
			IsA = function (self: any, className: string): boolean
				return recordOf(self).class.ancestors[className] == true
			end,

			GetFullName = fullName,
			GetDescendants = descendants,
			IsDescendantOf = isDescendantOf,
			Clone = clone,
			Destroy = destroy,

			GetChildren = function (self: any): { any }
				return table.clone(recordOf(self).children)
			end,

			FindFirstChild = find,

			-- Parks until a child of the name arrives or the timeout passes, and forever with no timeout, as the engine does
			WaitForChild = function (self: any, name: string, timeout: number?): any?
				local child: any? = find(self, name)
				if child then
					return child
				end

				local hold: () -> ...any, resume: (...any) -> () = clock.pending()
				local connection: any = event(self, "ChildAdded"):Connect(function (added: any)
					if recordOf(added).values.Name == name then
						resume(added)
					end
				end)

				local timer: thread? = nil
				if timeout then
					timer = clock.task.delay(timeout, resume)
				end

				local arrived: any? = hold()
				connection:Disconnect()

				-- Only a timer still waiting can be cancelled; one that gave nil is the thread resuming this one
				if timer and arrived ~= nil then
					clock.task.cancel(timer)
				end

				return arrived
			end,

			SetAttribute = function (self: any, name: any, value: any)
				local valid: boolean = type(name) == "string"
					and #name <= ATTRIBUTE_NAME_LIMIT
					and (name :: string):match(ATTRIBUTE_NAME) ~= nil
					and (name :: string):sub(1, #RESERVED_ATTRIBUTE_PREFIX) ~= RESERVED_ATTRIBUTE_PREFIX
				if not valid then
					error(`Attribute name '{name}' is invalid`, 2)
				elseif value ~= nil and not ATTRIBUTE_TYPES[typeOf(value)] then
					error(`SetAttribute: {typeOf(value)} is not a supported attribute type`, 2)
				end

				recordOf(self).attributes[name] = value
			end,

			GetAttribute = function (self: any, name: string): any
				return recordOf(self).attributes[name]
			end,

			GetAttributes = function (self: any): { [string]: any }
				return table.clone(recordOf(self).attributes)
			end,

			GetPropertyChangedSignal = function (self: any, property: string): any
				local record: Record = recordOf(self)
				local known: boolean = record.class.properties[property] ~= nil or record.class.get[property] ~= nil
				if not known then
					error(`{property} is not a valid property name.`, 2)
				end

				local signal: any = record.changed[property]
				if not signal then
					signal = Signal.new(clock)
					record.changed[property] = signal
				end

				return signal
			end,
		},
	}

	local world: World = {
		clock = clock,
		settings = settings,
		new = new,
		create = create,
		write = write,
		fire = fire,
		is = isInstance,
		typeof = typeOf,

		read = function (instance: any, property: string): any
			return recordOf(instance).values[property]
		end,

		-- A case's write, which goes past read-only and type checks but not past the property list
		set = function (instance: any, property: string, value: any)
			local record: Record = recordOf(instance)
			if not record.class.properties[property] then
				error(notMember(instance, property), 2)
			end

			write(instance, property, value)
		end,

		type = function (value: any): string
			if isInstance(value) or Signal.is(value) or Signal.isConnection(value) then
				return "userdata"
			end

			return type(value)
		end,
	}

	for _, family: Family in families do
		for className: string, spec: Spec in family.classes(world) do
			specs[className] = spec
		end
	end

	return world
end

return Instance
