local expect = require("cc.expect")
local SAMPLE_RATE = 48000

--- @export
local beep = {}

function validate_args(speaker, freq, volume, duration)
    expect.expect(1, speaker, "table")
    expect.expect(2, freq, "number", "table")
    expect.expect(3, volume, "number")
    expect.expect(4, duration, "number")

    if type(freq) ~= "table" then
        expect.range(freq, 0)
    end
    expect.range(volume, 0, 127)
    expect.range(duration, 0)
end

--- Emit a beep through an attached speaker.
--- @param speaker table: The speaker that should be used to play the beep
--- @param freq number|table: The beep frequency/frequencies
--- @param volume number: The volume from 0 (muted) to 127 (full volume)
--- @param duration number: The duration of the beep in seconds
function beep.beep(speaker, freq, volume, duration)
    validate_args(speaker, freq, volume, duration)
    
    local freqs = {}
    local incrs = {}
    local indexes = {}
    if type(freq) == "table" then 
        for i = 1, #freq do
            incrs[i] = freq[i] / SAMPLE_RATE
            freqs[i] = freq[i] / SAMPLE_RATE
            indexes[i] = 0
        end
    else 
        freqs = { freq }
        incrs = { freq / SAMPLE_RATE }
        indexes = { 0 }
    end

    local dur = math.floor(SAMPLE_RATE * duration)
    local buff = {}

    for i = 1, dur do
        local mixed = 0
        for j = 1, #freqs do
            if indexes[j] < 0.5 then mixed = mixed + volume else mixed = mixed + (0 - volume) end
            indexes[j] = indexes[j] + incrs[j]
            if indexes[j] > 1.0 then indexes[j] = indexes[j] - 1.0 end
        end

        mixed = mixed / #freqs
        buff[i] = math.floor(mixed)
    end

    while not speaker.playAudio(buff) do
        os.pullEvent("speaker_audio_empty")
    end
end

--- Emit a sine wave through an attached speaker.
--- @param speaker table: The speaker that should be used to play the sine
--- @param freq number|table: The sine frequency/frequencies
--- @param volume number: The volume from 0 (muted) to 127 (full volume)
--- @param duration number: The duration of the sine in seconds
function beep.sine(speaker, freq, volume, duration)
    validate_args(speaker, freq, volume, duration)

    local freqs = {}
    local incrs = {}
    local indexes = {}
    if type(freq) == "table" then 
        for i = 1, #freq do
            incrs[i] = freq[i] / SAMPLE_RATE
            freqs[i] = freq[i] / SAMPLE_RATE
            indexes[i] = 0
        end
    else 
        freqs = { freq }
        incrs = { freq / SAMPLE_RATE }
        indexes = { 0 }
    end

    local dur = math.floor(SAMPLE_RATE * duration)
    local buff = {}

    for i = 1, dur do
        local mixed = 0
        for j = 1, #freqs do
            mixed = mixed + math.sin(2 * math.pi * indexes[j])
            indexes[j] = indexes[j] + incrs[j]
            if indexes[j] > 1.0 then indexes[j] = indexes[j] - 1.0 end
        end

        mixed = mixed / #freqs
        buff[i] = math.floor(volume * mixed)
    end

    while not speaker.playAudio(buff) do
        os.pullEvent("speaker_audio_empty")
    end
end

--- Emit a noise through an attached speaker.
--- @param speaker table: The speaker that should be used to play the noise
--- @param freq number: The noise frequency
--- @param volume number: The volume from 0 (muted) to 127 (full volume)
--- @param duration number: The duration of the noise in seconds
--- @param noise_type number: This value changes the noise sound, the value must be between 1 and 15 included.
function beep.noise(speaker, freq, volume, duration, noise_type)
    validate_args(speaker, freq, volume, duration)
    expect.expect(5, noise_type, "number")
    expect.range(noise_type, 1, 15)
    
    local incr = freq / SAMPLE_RATE
    local dur = math.floor(SAMPLE_RATE * duration)
    local index, prev_index = 0, 0
    local buff = {}
    local poly_16 = 0xFFFF

    for i = 1, dur do
        if bit.band(poly_16, 1) == 0 then buff[i] = 0 - volume else buff[i] = volume end
        prev_index = index
        index = index + incr
        if index > 1.0 then index = index - 1.0 end
        if prev_index < 0.5 and index >= 0.5 then
            poly_16 = bit.bor(bit.blshift(bit.bxor(bit.band(bit.brshift(poly_16, noise_type), 1), bit.band(poly_16, 1)), 15), bit.brshift(poly_16, 1))
        end
    end

    while not speaker.playAudio(buff) do
        os.pullEvent("speaker_audio_empty")
    end
end

return beep