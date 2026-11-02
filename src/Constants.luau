--[[
    The constants Echo's own correctness needs: the Modes and their pool
    categories, the SoundService folder's name, the curve's point count, and
    which properties and effects an element takes in each Mode
--]]

--!strict
local MODES: { Mode } = { "Legacy", "AudioApi" }

local CATEGORIES: { [Mode]: string } = {
	Legacy = "Echo/Legacy",
	AudioApi = "Echo/AudioApi",
}

-- Holds a 2D Legacy voice's Sound while it plays
local FOLDER_NAME: string = "Echo"

-- The engine takes at most 400 points, which apply only in its Custom mode
local CURVE_POINTS: number = 32

-- Each element property Audio API mode takes, to the AudioPlayer property it writes
local AUDIO_API_PROPERTIES: { [string]: string } = {
	SoundId = "Asset",
	Volume = "Volume",
	PlaybackSpeed = "PlaybackSpeed",
	TimePosition = "TimePosition",
	Looped = "Looping",
	PlaybackRegion = "PlaybackRegion",
	LoopRegion = "LoopRegion",
}

-- Audio API mode writes no property for these: all three rebuild the emitter's distance curve
local CURVE_PROPERTIES: { [string]: boolean } = {
	RollOffMode = true,
	RollOffMinDistance = true,
	RollOffMaxDistance = true,
}

-- Each effect class an element takes as a child, to the Audio API class built in its place
local EFFECTS: { [string]: string } = {
	EqualizerSoundEffect = "AudioEqualizer",
	DistortionSoundEffect = "AudioDistortion",
	ReverbSoundEffect = "AudioReverb",
	ChorusSoundEffect = "AudioChorus",
	CompressorSoundEffect = "AudioCompressor",
	EchoSoundEffect = "AudioEcho",
	FlangeSoundEffect = "AudioFlanger",
	PitchShiftSoundEffect = "AudioPitchShifter",
	TremoloSoundEffect = "AudioTremolo",
}

-- A pooled voice's parent and playback are Echo's own, so an element never sets them
local REFUSED_PROPERTIES: { [string]: boolean } = {
	Parent = true,
	Playing = true,
}

local Types = require(script.Parent.Types)

type Mode = Types.Mode

return {
	MODES = MODES,
	CATEGORIES = CATEGORIES,
	FOLDER_NAME = FOLDER_NAME,
	CURVE_POINTS = CURVE_POINTS,
	AUDIO_API_PROPERTIES = AUDIO_API_PROPERTIES,
	CURVE_PROPERTIES = CURVE_PROPERTIES,
	EFFECTS = EFFECTS,
	REFUSED_PROPERTIES = REFUSED_PROPERTIES,
}
