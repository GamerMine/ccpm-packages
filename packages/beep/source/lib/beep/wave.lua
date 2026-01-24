local wave = {}
local SAMPLE_RATE = 48000

function wave.setup_args(freq)
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

    return freqs, incrs, indexes
end

function wave.square(speaker, freq, volume, duration)
    local freqs, incrs, indexes = wave.setup_args(freq)
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

    sleep(0)
end

function wave.sine(speaker, freq, volume, duration)
    local freqs, incrs, indexes = wave.setup_args(freq)
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

    sleep(0)
end

function wave.noise(speaker, freq, volume, duration, noise_type)
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

    sleep(0)
end

return wave
