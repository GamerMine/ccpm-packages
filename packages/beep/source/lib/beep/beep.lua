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

local expect = require("cc.expect")
local w = require("/lib/beep/wave")

--- @export
local beep = {}

beep.SINE   = "sine"
beep.SQUARE = "square"
beep.NOISE  = "noise"
beep.VOLUME = "volume"

function beep.note(freq, duration, type)
    expect.expect(1, freq, "number")
    expect.range(freq, 0)
    expect.expect(1, duration, "number")
    expect.range(freq , 0)
    expect.expect(1, type, "string")

    return {
        frequency = freq,
        duration  = duration,
        type      = type
    }
end

function beep.volume(volume)
    expect.expect(1, volume, "number")
    expect.range(volume, 0, 127)

    return {
        volume = volume,
        type   = beep.VOLUME
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
    local volume = {}
    setmetatable(newAudio, self)
    self.__index = self

    expect.expect(1, speakers, "table", "nil")

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
            volume[i] = 50
        end
    end

    newAudio.nbChannels = #speakers
    newAudio.speakers = speakers
    newAudio.volumes = volume

    return newAudio
end

--[[ Set the volume of a channel.
    @param channel number: The channel's number
    @param newVolume number: The new channel's volume (must be between 0 and 127 included)
    @usage Set the volume of channel 1.

        local audio = beep.Audio:new({spk1, spk2, spk3})

        audio:setVolume(1, 50)
--]]
function beep.Audio:setVolume(channel, newVolume)
    expect.expect(1, channel, "number")
    expect.range(channel, 1, self.nbChannels)
    expect.expect(2, newVolume, "number")
    expect.range(newVolume, 0, 127)
    
    self.volumes[channel] = newVolume
end

--[[ Plays a note on a specific channel.
    @param channel number: The channel's number 
    @param note table: A table containing the note to be played
    @usage Create a note and play it on channel 1.

        local audio = beep.Audio:new({spk1, spk2, spk3})
        local note = beep.note(440, 1, beep.SINE)

        audio:playNote(1, note)
--]]
function beep.Audio:playNote(channel, note)
    expect.expect(1, channel, "number")
    expect.range(channel, 1, self.nbChannels)
    expect.expect(2, note, "table")

    local spk = self.speakers[channel]
    local volume = self.volumes[channel]
    
    if note.type == beep.SINE then
        w.sine(spk, note.frequency, volume, note.duration)
    elseif note.type == beep.SQUARE then
        w.square(spk, note.frequency, volume, note.duration)
    elseif note.type == beep.NOISE then
        w.noise(spk, note.frequency, volume, note.duration, 1)
    else
        print(string.format("Type %s does not exists!", note.type))
    end
end

--[[ Plays notes loaded into the data table for one channel.
    @param channel number: The channel's number 
    @param data table: A table containing the notes for each channels to be played
    @usage Create a note data table containing data for one channel and play it on channel 1.

        local audio = beep.Audio:new({spk1, spk2, spk3})
        local data = {            
            beep.volume(20)
            beep.note(440, 1, beep.SQUARE)
        }
        audio:playChannel(1, data)
--]]
function beep.Audio:playChannel(channel, data)
    expect.expect(1, channel, "number")
    expect.range(channel, 0, self.nbChannels)
    expect.expect(2, data, "table")
    
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
     This will play the notes for each channel simultaneously
    @param data table: A table containing the notes for each channels to be played
    @usage Create a note data table containing data for channel 1 and 3 and play it.

        local audio = beep.Audio:new({spk1, spk2, spk3})
        local data = {
            [1]={
                beep.volume(20)
                beep.note(440, 1, beep.SQUARE)
            }
            [3]={
                beep.volume(60)
                beep.note(880, 1, beep.SINE)
            }
        }
        audio:playSong(data)
--]]
function beep.Audio:playSong(data)
    expect.expect(1, data, "table")

    local fns = {}
    for i = 1, self.nbChannels do
        if data[i] then
            table.insert(fns, function() self:playChannel(i, data[i]) end)
        end
    end
    
    parallel.waitForAll(table.unpack(fns))
end

return beep
    
