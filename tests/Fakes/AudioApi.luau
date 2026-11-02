--[[
    The fake Audio API: AudioPlayer, AudioEmitter, Wire, AudioFader,
    AudioDeviceOutput and the nine effects, the player's playback driven by
    the same helpers a legacy Sound's is
--]]

--!strict
local Instance = require("./Instance")

type Spec = Instance.Spec
type World = Instance.World

local CURVE: string = "DistanceAttenuation" -- The engine keeps the curve here, where no script reads it
local MAX_POINTS: number = 400 -- Points SetDistanceAttenuation takes at most

local AudioApi = {}

function AudioApi.classes(world: World): { [string]: Spec }
	return {
		AudioFader = {},
		AudioDeviceOutput = {},

		AudioEqualizer = {},
		AudioDistortion = {},
		AudioReverb = {},
		AudioChorus = {},
		AudioCompressor = {},
		AudioEcho = {},
		AudioFlanger = {},
		AudioPitchShifter = {},
		AudioTremolo = {},

		Wire = {
			get = {
				Connected = function (wire: any): boolean
					return wire.SourceInstance ~= nil and wire.TargetInstance ~= nil
				end,
			},
		},

		-- Play never rewinds and Stop keeps TimePosition, so a restart is Stop, TimePosition = 0, Play
		AudioPlayer = {
			events = { "Ended", "Looped" },

			set = {
				Asset = function (player: any, id: string)
					if id == world.read(player, "Asset") then
						return
					end

					world.write(player, "Asset", id)
					world.write(player, "IsReady", false)
					world.write(player, "TimeLength", 0)
				end,
			},

			methods = {
				Play = function (self: any)
					world.write(self, "IsPlaying", true)
				end,

				Stop = function (self: any)
					world.write(self, "IsPlaying", false)
				end,
			},
		},

		AudioEmitter = {
			methods = {
				SetDistanceAttenuation = function (self: any, curve: any)
					if world.type(curve) ~= "table" then
						error(
							`SetDistanceAttenuation takes a table of distances to volumes, not {world.typeof(curve)}`,
							2
						)
					end

					local points: number = 0
					for distance: any, volume: any in curve do
						points += 1

						if type(distance) ~= "number" or distance < 0 then
							error(`SetDistanceAttenuation takes distances of 0 or more, not {distance}`, 2)
						elseif type(volume) ~= "number" or volume < 0 or volume > 1 then
							error(`SetDistanceAttenuation takes volumes from 0 to 1, not {volume}`, 2)
						end
					end

					if points > MAX_POINTS then
						error(`SetDistanceAttenuation takes at most {MAX_POINTS} points, not {points}`, 2)
					end

					world.write(self, CURVE, table.clone(curve))
				end,

				GetDistanceAttenuation = function (self: any): { [number]: number }
					return table.clone(world.read(self, CURVE) or {})
				end,
			},
		},
	}
end

function AudioApi.finish(world: World, player: any)
	if not player.IsPlaying then
		error(`env.finish was given {player:GetFullName()}, which is not playing`, 3)
	elseif player.Looping then
		error(`env.finish was given {player:GetFullName()}, which loops; env.loop runs its loop`, 3)
	end

	world.write(player, "IsPlaying", false)
	world.write(player, "TimePosition", 0)
	world.fire(player, "Ended")
end

function AudioApi.loop(world: World, player: any)
	if not player.IsPlaying then
		error(`env.loop was given {player:GetFullName()}, which is not playing`, 3)
	elseif not player.Looping then
		error(`env.loop was given {player:GetFullName()}, which does not loop; env.finish ends it`, 3)
	end

	world.write(player, "TimePosition", 0)
	world.fire(player, "Looped")
end

-- An AudioPlayer has no Loaded event; IsReady turning true is how it says so
function AudioApi.load(world: World, player: any)
	if player.IsReady then
		error(`env.load was given {player:GetFullName()}, which is already ready`, 3)
	end

	world.write(player, "IsReady", true)
end

return AudioApi
