--[[
    The property helpers both backends share: reads and writes by name, a
    write that warns where the engine refuses it, and the probes that check
    and clear read and write instead of a voice
--]]

--!strict
-- One instance of each class that no voice uses, made the first time it is asked for
local Probes: { [string]: Instance } = {}

local Properties = {}

function Properties.read(instance: any, property: string): any
	return instance[property]
end

function Properties.write(instance: any, property: string, value: any)
	instance[property] = value
end

--[[
    Writes a property, or warns and leaves it when the engine refuses the
    value, so a bad write never throws out of a binding
--]]

function Properties.assign(instance: Instance, property: string, value: any): boolean
	local written: boolean, reason: any = pcall(Properties.write, instance, property, value)
	if not written then
		warn(`Echo left {instance.ClassName}.{property}, which refused {typeof(value)} {value}: {reason}`)
	end

	return written
end

--[[
    The one instance of a class that no voice uses, holding that class's
    defaults, made on first use so requiring a backend makes no instance
--]]

function Properties.probe(className: string): Instance
	local instance: Instance? = Probes[className]
	if not instance then
		instance = (Instance.new :: any)(className)
		Probes[className] = instance
	end

	return instance :: Instance
end

--[[
    The reason the engine refuses the value for a property, or refuses any
    write when no value is given, tried on a probe and put back after
--]]

function Properties.refusal(instance: Instance, property: string, value: any): string?
	local readable: boolean, original: any = pcall(Properties.read, instance, property)
	if not readable then
		return `{instance.ClassName} has no property {property}`
	end

	local given: any = value
	if given == nil then
		given = original
	end

	local written: boolean, reason: any = pcall(Properties.write, instance, property, given)
	if not written then
		return `{instance.ClassName}.{property} refuses {typeof(given)} {given}: {reason}`
	end

	Properties.write(instance, property, original)

	return nil
end

return Properties
