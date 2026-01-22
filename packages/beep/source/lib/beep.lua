local expect = require("cc.expect")
local SAMPLE_RATE = 48000

--- @export
local beep = {}

--- Emit a beep through an attached speaker.
--- @param speaker table: The speaker that should be used to play the beep
--- @param freq number: The beep frequency
--- @param volume number: The volume from 0 (muted) to 127 (full volume)
--- @param duration number: The duration of the beep in seconds
function beep.beep(speaker, freq, volume, duration)
    expect.expect(1, speaker, "table")
    expect.expect(2, freq, "number")
    expect.expect(3, volume, "number")
    expect.expect(4, duration, "number")

    if freq < 0 then
        return "freq should be greater than or equal to 0"
    end
    if volume < 0 or volume > 127 then
        return "volume should be a value between 0 and 127"
    end
    if duration < 0 then
        return "duration shoudl be greater than or equal to 0"
    end
    
    local incr = freq / SAMPLE_RATE
    local dur = math.floor(SAMPLE_RATE * duration)
    local index, prev_index = 0, 0
    local buff = {}
    local square = false

    for i = 1, dur do
        if prev_index < 0.5 and index >= 0.5 then
            square = not square
        end
        if square then buff[i] = volume else buff[i] = 0 end
        prev_index = index
        index = index + incr
        if index > 1.0 then index = index - 1.0 end
    end

    while not speaker.playAudio(buff) do
        os.pullEvent("speaker_audio_empty")
    end
    
end

return beep