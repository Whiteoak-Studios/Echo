--[[
    Makes the elements a game writes its sounds as, each a description that
    owns no instance, reads a tree's sounds back out, and records each
    SoundId in the order its first sound was made
--]]

--!strict
local Constants = require(script.Parent.Constants)
local Keys = require(script.Parent.Keys)

-- The Event and Action tokens, which a sound reads by its key before its value
local EVENTS: { [any]: boolean } = {
	[Keys.Event.Ended] = true,
	[Keys.Event.Playing] = true,
	[Keys.Event.Looped] = true,
	[Keys.Event.Loaded] = true,
}

local ACTIONS: { [any]: boolean } = {
	[Keys.Action.Play] = true,
	[Keys.Action.Pause] = true,
}

local Types = require(script.Parent.Types)

type Component = Types.Component
type EffectElement = Types.EffectElement
type Element = Types.Element
type FragmentElement = Types.FragmentElement
type FragmentKey = Types.FragmentKey
type Props = Types.Props
type Ref<T> = Types.Ref<T>
type SoundElement = Types.SoundElement

-- Each SoundId once, in the order its first sound was made, and the same ids as a set
local Ids: { string } = {}
local Recorded: { [string]: boolean } = {}

local Element = {}

local function marked(value: any, marker: { nil }): boolean
	return type(value) == "table" and value[marker] == true
end

local function isElement(value: any): boolean
	return type(value) == "table" and (value.kind == "Sound" or value.kind == "Effect" or value.kind == "Fragment")
end

--[[
    Names a value for a message: a token by its name, an element by its
    kind, a string, number or boolean as itself, and anything else by type
--]]

local function describe(value: any): string
	if type(value) == "table" and type(value.name) == "string" then
		return value.name
	elseif isElement(value) then
		return `a {value.kind} element`
	elseif type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
		return `{value}`
	end

	return typeof(value)
end

--[[
    Calls a component with its props and gives back the element it returns
    as it is, so a component may return another component's element
--]]

local function render(component: Component, props: Props): Element
	local element: any = component(props)
	assert(isElement(element), `A component returned {describe(element)}, where it returns an element`)

	return element
end

--[[
    Reads a sound's props, each by its key before its value, so a value
    under one of Echo's keys is never taken for a ref, a binding or an event
--]]

local function sound(props: Props, children: { [string]: Element }?): SoundElement
	local element: SoundElement = {
		kind = "Sound",
		properties = {},
		events = {},
		actions = {},
		refs = {},
		attributes = {},
		effects = {},
	}

	for key: any, value: any in props do
		if EVENTS[key] then
			assert(type(value) == "function", `{key.name} takes a function, not {describe(value)}`)
			element.events[key] = value
		elseif ACTIONS[key] then
			assert(marked(value, Keys.State), `{key.name} takes a state, not {describe(value)}`)
			element.actions[key] = value
		elseif key == Keys.Util.Cap then
			assert(type(value) == "string", `{key.name} takes a cap group's name, not {describe(value)}`)
			element.cap = value
		elseif key == Keys.Util.Bus then
			assert(type(value) == "string", `{key.name} takes a bus's name, not {describe(value)}`)
			element.bus = value
		elseif type(key) ~= "string" then
			error(`A Sound's prop key {describe(key)} is neither a string nor one of Echo's keys`)
		elseif key == "Attributes" then
			local plain: boolean = type(value) == "table"
				and not marked(value, Keys.State)
				and not marked(value, Keys.Ref)
			assert(plain, `Attributes takes a table of attributes, not {describe(value)}`)
			element.attributes = table.clone(value)
		elseif Constants.REFUSED_PROPERTIES[key] then
			error(`A Sound's {key} is Echo's own; play the sound with Echo.Action.Play`)
		elseif marked(value, Keys.Ref) then
			table.insert(element.refs, value)
		elseif type(value) == "function" then
			error(`A Sound's {key} is a function, which no property takes; an event goes under an Echo.Event key`)
		else
			element.properties[key] = value -- A plain value, or a state bound to the property
		end
	end

	for key: any, child: any in children or {} do
		assert(type(key) == "string", `A Sound's child key {describe(key)} is not a string`)
		assert(isElement(child) and child.kind == "Effect", `A Sound's child {key} is {describe(child)}, not an effect`)
		element.effects[key] = child
	end

	-- A SoundId bound to a state is recorded at the state's value now
	local id: any = element.properties.SoundId
	if marked(id, Keys.State) then
		id = id.current
	end

	if type(id) == "string" and not Recorded[id] then
		Recorded[id] = true
		table.insert(Ids, id)
	end

	return element
end

local function effect(className: string, props: Props): EffectElement
	local properties: { [string]: any } = {}
	for key: any, value: any in props do
		assert(type(key) == "string", `A {className}'s prop key {describe(key)} is not a string`)
		properties[key] = value
	end

	return { kind = "Effect", className = className, properties = properties }
end

--[[
    Reads a fragment's list, calling each component in it with an empty
    props table and keeping each element as it is
--]]

local function fragment(list: Props): FragmentElement
	local children: { Element } = {}
	for index: any, entry: any in list do
		if type(entry) == "function" then
			table.insert(children, render(entry, {}))
		else
			assert(
				isElement(entry),
				`Echo.Fragment's entry {describe(index)} is {describe(entry)}, not a component or an element`
			)
			table.insert(children, entry)
		end
	end

	return { kind = "Fragment", children = children }
end

local function collect(element: Element, found: { SoundElement })
	assert(isElement(element), `Echo was handed {describe(element)}, where it takes an element`)

	if element.kind == "Sound" then
		table.insert(found, element :: SoundElement)
	elseif element.kind == "Fragment" then
		for _, child: Element in (element :: FragmentElement).children do
			collect(child, found)
		end
	else
		error(`A {(element :: EffectElement).className} sits outside a Sound, the one element that takes an effect`)
	end
end

--[[
    Makes an element: a Sound, an effect of one of the legacy effect
    classes, a fragment of components and elements, or the element a
    component returns for its props. A missing props is an empty table
--]]

function Element.create(
	kind: string | Component | FragmentKey,
	props: Props?,
	children: { [string]: Element }?
): Element
	local given: Props = props or {}
	assert(type(given) == "table", `An element's props are a table, not {describe(given)}`)
	assert(kind == "Sound" or children == nil, `Only a Sound takes children, and {describe(kind)} was given them`)

	if kind == "Sound" then
		return sound(given, children)
	elseif type(kind) == "string" and Constants.EFFECTS[kind] then
		return effect(kind, given)
	elseif type(kind) == "function" then
		return render(kind, given)
	elseif kind == Keys.Fragment then
		return fragment(given)
	end

	local kinds: string = `"Sound", a legacy effect class, a component or Echo.Fragment`
	error(`Echo can't create an element of kind {describe(kind)}; a kind is {kinds}`)
end

--[[
    Makes a ref, which an element hands its handle to at mount
--]]

function Element.ref<T>(initial: T): Ref<T>
	return { current = initial, [Keys.Ref] = true }
end

function Element.isRef(value: any): boolean
	return marked(value, Keys.Ref)
end

--[[
    Gives every sound element in a tree, at any depth through fragments,
    and refuses an effect element outside a sound, naming its class
--]]

function Element.sounds(element: Element): { SoundElement }
	local found: { SoundElement } = {}
	collect(element, found)

	return found
end

--[[
    Gives a fresh list of every SoundId recorded so far, in the order its
    first sound was made
--]]

function Element.ids(): { string }
	return table.clone(Ids)
end

return Element
