--[[
    The scene the jobs play into: the folder both pools' voices live in, the
    bus's SoundGroup and AudioFader wired to an output, the listeners at the
    camera, the bus's analyzer, the wall, and the props roots follow
--]]

--!strict
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local BUS_NAME: string = Config.bus.name
local BUS_GROUP: string = Config.bus.interactionGroup
local BUS_VOLUME: number = Config.bus.volume
local WALL_SIZE: Vector3 = Config.audible.wall.size
local PROP_SIZE: Vector3 = Config.propSize
local VOICES_FOLDER: string = Config.voicesFolder
local NO_GROUP: string = "" -- The interaction group Echo gives a world voice with no bus

export type Scene = {
	folder: Folder, -- Under SoundService, holding everything here that has no place in the world
	voices: Folder, -- Under Workspace, the config's parent, where both pools' voice trees live and play
	group: SoundGroup,
	fader: AudioFader,
	output: AudioDeviceOutput,
	analyzer: AudioAnalyzer, -- Hears the bus's fader, so whatever plays on the bus in Audio API mode
	wall: Part, -- Unparented until the audible test stands it between the camera and its sounds
}

local Scene = {}

local function wire(source: Instance, target: Instance, parent: Instance)
	local link: Wire = Instance.new("Wire")
	link.SourceInstance = source
	link.TargetInstance = target
	link.Parent = parent
end

--[[
    Builds the scene once, for the session. Each listener sits on the
    camera the session starts with, one for each interaction group
--]]

function Scene.build(): Scene
	local camera = Workspace.CurrentCamera :: Camera

	local folder: Folder = Instance.new("Folder")
	folder.Name = "EchoDev"
	folder.Parent = SoundService

	local voices: Folder = Instance.new("Folder")
	voices.Name = VOICES_FOLDER
	voices.Parent = Workspace

	local group: SoundGroup = Instance.new("SoundGroup")
	group.Name = BUS_NAME
	group.Volume = BUS_VOLUME
	group.Parent = folder

	local output: AudioDeviceOutput = Instance.new("AudioDeviceOutput")
	output.Parent = folder

	local fader: AudioFader = Instance.new("AudioFader")
	fader.Name = BUS_NAME
	fader.Volume = BUS_VOLUME
	fader.Parent = folder
	wire(fader, output, folder)

	local analyzer: AudioAnalyzer = Instance.new("AudioAnalyzer")
	analyzer.Parent = folder
	wire(fader, analyzer, folder)

	-- The bus's listener plays through its fader, and the other straight to the output
	local busListener: AudioListener = Instance.new("AudioListener")
	busListener.Name = BUS_NAME
	busListener.AudioInteractionGroup = BUS_GROUP
	busListener.Parent = camera
	wire(busListener, fader, folder)

	local worldListener: AudioListener = Instance.new("AudioListener")
	worldListener.Name = "EchoDevWorld"
	worldListener.AudioInteractionGroup = NO_GROUP
	worldListener.Parent = camera
	wire(worldListener, output, folder)

	local wall: Part = Instance.new("Part")
	wall.Name = "EchoDevWall"
	wall.Anchored = true
	wall.Size = WALL_SIZE

	return {
		folder = folder,
		voices = voices,
		group = group,
		fader = fader,
		output = output,
		analyzer = analyzer,
		wall = wall,
	}
end

--[[
    A point the given studs ahead of the camera now, along its look
--]]

function Scene.ahead(distance: number): Vector3
	local view: CFrame = (Workspace.CurrentCamera :: Camera).CFrame

	return view.Position + view.LookVector * distance
end

--[[
    A Part standing at a point, which a root follows as a game's object
--]]

function Scene.part(position: Vector3): Part
	local part: Part = Instance.new("Part")
	part.Name = "EchoDevProp"
	part.Anchored = true
	part.CanCollide = false
	part.Size = PROP_SIZE
	part.Position = position
	part.Parent = Workspace

	return part
end

--[[
    A Tool the character holds while a first-person voice plays from a 2D root
--]]

function Scene.tool(character: Model): Tool
	local tool: Tool = Instance.new("Tool")
	tool.Name = "EchoDevTool"
	tool.RequiresHandle = false
	tool.Parent = character

	return tool
end

return Scene
