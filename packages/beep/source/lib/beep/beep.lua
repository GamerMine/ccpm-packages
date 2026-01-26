--[[
    beep - Audio generation library
    Copyright (C) 2026 Maxime Savary <msavary@dwightstudio.fr>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses>.
--]]

local exp = require("cc.expect")
local w = require("/lib/beep/wave")

--- @export
local beep = {}

beep.SINE   = "sine"
beep.SQUARE = "square"
beep.NOISE1 = "noise1"
beep.NOISE2 = "noise2"
beep.NOISE3 = "noise3"
beep.NOISE4 = "noise4"
beep.NOISE5 = "noise5"
beep.NOISE6 = "noise6"
beep.NOISE7 = "noise7"
beep.VOLUME = "volume"
beep.START_LOOP = "start_loop"
beep.END_LOOP = "end_loop"

local noises = {[beep.NOISE1]=3, [beep.NOISE2]=5, [beep.NOISE3]=6, [beep.NOISE4]=9, [beep.NOISE5]=10, [beep.NOISE6]=13, [beep.NOISE7]=15}

--[[ Creates a note structure. This should be used within notes data table. (see usage section of beep.Audio:playSong())
    @param freq number: The note's frequency in Hertz.
    @param duration number: The note's duration in seconds.
    @param type string: The note's type. Can be beep.SQUARE, beep.SINE or beep.NOISE.
-- ]]
function beep.note(freq, duration, type)
   exp.expect(1, freq, "number")
   exp.range(freq, 0)
   exp.expect(2, duration, "number")
   exp.range(freq , 0)
   exp.expect(3, type, "string")

    return {
        frequency = freq,
        duration  = duration,
        type      = type
    }
end

--[[ Creates a fade in/out note structure. This should be used within notes data table. (see usage section of beep.Audio:playSong())
     The fading direction will be computed at runtime, i.e: if the target volume is lower than the current volume, the note will fade
     in otherwise it will fade out.
    @param freq number: The note's frequency in Hertz.
    @param duration number: The note's duration in seconds.
    @param type string: The note's type. Can be beep.SQUARE, beep.SINE or beep.NOISE.
    @param targetVolume number: The target fade in/out volume.
-- ]]
function beep.fnote(freq, duration, type, targetVolume)
    exp.expect(1, freq, "number")
    exp.range(freq, 0)
    exp.expect(2, duration, "number")
    exp.range(freq , 0)
    exp.expect(3, type, "string")
    exp.expect(4, targetVolume, "number")
    exp.range(targetVolume, 0, 127)

    return {
        frequency  = freq,
        duration   = duration,
        type       = type,
        fadeTarget = targetVolume
    }
end

--[[ Creates a volume structure. This should be used within notes data table. (see usage section of beep.Audio:playSong())
    @param volume number: The new volume to be set.
-- ]]
function beep.volume(volume)
   exp.expect(1, volume, "number")
   exp.range(volume, 0, 127)

    return {
        volume = volume,
        type   = beep.VOLUME
    }
end

--[[ Creates a loop start structure. This should be used within notes data table. (see usage section of beep.Audio:playSong())
     startLoop() must be followed by it's associated endLoop().
    @param count number: Loop iterations count
    @usage Create a loop of notes.

        local data = {
            [1]={
                beep.volume(10),
                beep.startLoop(10), -- Here the content between startLoop(10) and endLoop() will be repeated 10 times.
                beep.note(1000, 0.5, beep.SQUARE),
                beep.note(2000, 0.5, beep.SQUARE),
                beep.endLoop()
            }
        }
-- ]]
function beep.startLoop(count)
    exp.expect(1, count, "number")
    
    return {
        type = beep.START_LOOP,
        loopCount = count
    }
end

--[[ Creates a loop end structure. This should be used within notes data table. (see usage section of beep.Audio:playSong())
     endLoop() must be preceded by it's associated startLoop().
     @usage See startLoop().
-- ]]
function beep.endLoop()
    return {
        type = beep.END_LOOP
    }
end

beep.Audio = {}

--[[ Creates a new Audio player with the provided speakers.
     The ordering of the speakers in the list will be the channel ordering (see usage below)
    @param speakers table: The speaker list.
    @usage Create a new Audio player.

        local spk1 = peripheral.wrap("right")
        local spk2 = peripheral.wrap("left")

        local audio = beep.Audio:new({spk1, spk2}) -- spk1 will be channel 1 and spk2, channel 2
-- ]]
function beep.Audio:new(speakers)
    local newAudio = {}
    setmetatable(newAudio, self)
    self.__index = self

   exp.expect(1, speakers, "table", "nil")

    if type(speakers) == "table" then
        local seen = {}
        for i = 1, #speakers do
            local name = getmetatable(speakers[i]).name
            for j = 1, #seen do
                if seen[j] == name then
                    io.stderr:write("Duplicate speaker found.")
                    return nil
                end
            end
            seen[i] = name
            speakers[i]["volume"] = 50
            speakers[i]["buffer"] = {}
        end
    end

    newAudio.nbChannels = #speakers
    newAudio.speakers = speakers

    return newAudio
end

--[[ Set the volume of a channel.
     On Audio playback object creation, the volume is set to 50
    @param channel number: The channel's number.
    @param newVolume number: The new channel's volume (must be between 0 and 127 included).
    @usage Set the volume of channel 1.

        local audio = beep.Audio:new({spk1, spk2, spk3})

        audio:setVolume(1, 100)
--]]
function beep.Audio:setVolume(channel, newVolume)
   exp.expect(1, channel, "number")
   exp.range(channel, 1, self.nbChannels)
   exp.expect(2, newVolume, "number")
   exp.range(newVolume, 0, 127)
    
    self.speakers[channel].volume = newVolume
end

--[[ Plays a note on a specific channel.
    @param channel number: The channel's number.
    @param note table: A table containing the note to be played.
    @usage Create a note and play it on channel 1.

        local audio = beep.Audio:new({spk1, spk2, spk3})
        local note = beep.note(440, 1, beep.SINE)

        audio:playNote(1, note)
--]]
function beep.Audio:playNote(channel, note)
   exp.expect(1, channel, "number")
   exp.range(channel, 1, self.nbChannels)
   exp.expect(2, note, "table")

    local spk = self.speakers[channel]
    
    if note.type == beep.SINE then
        w.sine(spk, note.frequency, note.duration, note.fadeTarget)
    elseif note.type == beep.SQUARE then
        w.square(spk, note.frequency, note.duration, note.fadeTarget)
    elseif string.find(note.type, "noise") ~= nil then
        w.noise(spk, note.frequency, note.duration, noises[note.type], note.fadeTarget)
    else
        print(string.format("Type %s does not exists!", note.type))
    end
end

--[[ Plays notes loaded into the data table for one channel.
    @param channel number: The channel's number.
    @param data table: A table containing the notes for each channels to be played.
    @usage Create a note data table containing data for one channel and play it on channel 1.

        local audio = beep.Audio:new({spk1, spk2, spk3})
        local data = {            
            beep.volume(20),
            beep.note(440, 1, beep.SQUARE)
        }
        audio:playChannel(1, data)
--]]
function beep.Audio:playChannel(channel, data)
    exp.expect(1, channel, "number")
    exp.range(channel, 0, self.nbChannels)
    exp.expect(2, data, "table")

    for i=1, #data do
        local note = data[i]

        if note.type == beep.VOLUME then
            self:setVolume(channel, note.volume)
            goto continue
        end

        self:playNote(channel, note)
        ::continue::
    end
end

--[[ Plays a song from a data table loaded with notes associated to channels numbers.
     This will play the notes for each channel simultaneously.
    @param data table: A table containing the notes for each channels to be played.
    @usage Create a note data table containing data for channel 1 and 3 and play it.

        local audio = beep.Audio:new({spk1, spk2, spk3})
        local data = {
            [1]={
                beep.volume(20),
                beep.note(440, 1, beep.SQUARE)
            }
            [3]={
                beep.volume(60),
                beep.note(880, 1, beep.SINE)
            }
        }
        audio:playSong(data)
--]]
function beep.Audio:playSong(data)
   exp.expect(1, data, "table")

    local fns = {}
    for i = 1, self.nbChannels do
        if data[i] then
            local parsed = parseChannel(i, data[i])
            if parsed then
                table.insert(fns, function() self:playChannel(i, parsed) end)
            else
                return
            end
        end
    end
    
    parallel.waitForAll(table.unpack(fns))
end

function parseChannel(channel, data)
    local parsed = {}
    local callStack = {}
    
    for i=1, #data do
        local note = data[i]

        if note.type == beep.START_LOOP then
            table.insert(callStack, {startIndex=#parsed + 1, loopCount=note.loopCount, line=i})
        elseif note.type == beep.END_LOOP then
            if #callStack == 0 then
                io.stderr:write(string.format("Error in channel %d: Too many endLoop() or missing startLoop() at line %d.\n", channel, i))
                return
            end
            local loop = table.remove(callStack)

            for j=1, loop.loopCount-1 do
                for k=loop.startIndex, #parsed do
                    table.insert(parsed, parsed[k])
                end
            end
        else
            table.insert(parsed, data[i])
        end
    end

    if #callStack ~= 0 then
        for i=1, #callStack do
            local call = callStack[i]
            io.stderr:write(string.format("Error in channel %d: missing endLoop() for loop at line %d.\n", channel, call.line))
        end
        return
    end

    return parsed    
end

return beep

--[[
    TODO: #3 Add vibrato (repeated, fast change of frequency over time), with depth and rate paramters.
    TODO: #6 Add frequency shift to a target frequency over time (duration)
-- ]]
