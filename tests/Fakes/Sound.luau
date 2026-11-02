--[[
    The fake legacy sound system: SoundService, SoundGroup, the nine
    SoundEffect classes and Sound, whose playback a case drives with the
    helpers that finish, loop and load it
--]]

--!strict
local Instance = require("./Instance")

type Spec = Instance.Spec
type World = Instance.World

local LOOPS: string = "LoopsSincePlay" -- A value no script can read, the count DidLoop reports

local Sound = {}

local function setPlaying(world: World, sound: any, playing: boolean)
	world.write(sound, "Playing", playing)
	world.write(sound, "IsPlaying", playing)
	world.write(sound, "IsPaused", not playing)
end

function Sound.classes(world: World): { [string]: Spec }
	return {
		SoundService = {},
		SoundGroup = {},

		EqualizerSoundEffect = {},
		DistortionSoundEffect = {},
		ReverbSoundEffect = {},
		ChorusSoundEffect = {},
		CompressorSoundEffect = {},
		EchoSoundEffect = {},
		FlangeSoundEffect = {},
		PitchShiftSoundEffect = {},
		TremoloSoundEffect = {},

		Sound = {
			events = { "Ended", "DidLoop", "Loaded" },

			init = function (sound: any)
				world.write(sound, "IsPaused", true)
			end,

			set = {
				Playing = function (sound: any, playing: boolean)
					setPlaying(world, sound, playing)
				end,

				-- A new asset has not loaded, and reports no length until it does
				SoundId = function (sound: any, id: string)
					if id == world.read(sound, "SoundId") then
						return
					end

					world.write(sound, "SoundId", id)
					world.write(sound, "IsLoaded", false)
					world.write(sound, "TimeLength", 0)
				end,
			},

			-- Play starts from the TimePosition a script last set, which nothing but a script moves here
			-- Whiteoak TODO: TimePosition never advances while playing; move it on each step once a case reads one mid-play
			methods = {
				Play = function (self: any)
					world.write(self, LOOPS, 0)
					setPlaying(world, self, true)
				end,

				Stop = function (self: any)
					setPlaying(world, self, false)
					world.write(self, "TimePosition", 0)
				end,

				Pause = function (self: any)
					setPlaying(world, self, false)
				end,

				Resume = function (self: any)
					setPlaying(world, self, true)
				end,
			},
		},
	}
end

--[[
    Ends a playing sound that does not loop as its asset running out would,
    firing Ended once
--]]

function Sound.finish(world: World, sound: any)
	if not sound.Playing then
		error(`env.finish was given {sound:GetFullName()}, which is not playing`, 3)
	elseif sound.Looped then
		error(`env.finish was given {sound:GetFullName()}, which loops; env.loop runs its loop`, 3)
	end

	setPlaying(world, sound, false)
	world.write(sound, "TimePosition", 0)
	world.fire(sound, "Ended", sound.SoundId)
end

--[[
    Runs one loop of a playing looped sound, firing DidLoop with the loops
    counted since its last Play
--]]

function Sound.loop(world: World, sound: any)
	if not sound.Playing then
		error(`env.loop was given {sound:GetFullName()}, which is not playing`, 3)
	elseif not sound.Looped then
		error(`env.loop was given {sound:GetFullName()}, which does not loop; env.finish ends it`, 3)
	end

	local loops: number = (world.read(sound, LOOPS) or 0) + 1
	world.write(sound, LOOPS, loops)
	world.write(sound, "TimePosition", 0)
	world.fire(sound, "DidLoop", sound.SoundId, loops)
end

function Sound.load(world: World, sound: any)
	if sound.IsLoaded then
		error(`env.load was given {sound:GetFullName()}, which has already loaded`, 3)
	end

	world.write(sound, "IsLoaded", true)
	world.fire(sound, "Loaded", sound.SoundId)
end

return Sound
