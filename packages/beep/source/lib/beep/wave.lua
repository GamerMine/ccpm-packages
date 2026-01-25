local wave = {}
local SAMPLE_RATE = 48000

local squareIndex = 0
local sineIndex = 0

function wave.play(spk)
    while not spk.playAudio(spk.buffer) do
        os.pullEvent("speaker_audio_empty")
    end
    spk.buffer = {}
end

function wave.square(speaker, freq, duration)
    local incr = freq / SAMPLE_RATE
    local dur = math.floor(SAMPLE_RATE * duration)

    for i = 1, dur do
        local sample = 0
        
        if squareIndex < 0.5 then sample = speaker.volume else sample = (0 - speaker.volume) end
        squareIndex = (squareIndex + incr) % 1

        table.insert(speaker.buffer, sample)
        if #speaker.buffer > 4*1024 then wave.play(speaker) end
    end
    wave.play(speaker)
end

function wave.sine(speaker, freq, duration)
    local incr = freq / SAMPLE_RATE
    local dur = math.floor(SAMPLE_RATE * duration)

    for i = 1, dur do
        local sample = 0

        sample = math.floor(speaker.volume * math.sin(2 * math.pi * sineIndex))
        sineIndex = (sineIndex + incr) % 1

        table.insert(speaker.buffer, sample)
        if #speaker.buffer > 4*1024 then wave.play(speaker) end
    end
    wave.play(speaker)
end

function wave.noise(speaker, freq, duration, noise_type)
    local incr = freq / SAMPLE_RATE
    local dur = math.floor(SAMPLE_RATE * duration)
    local index, prev_index = 0, 0
    local poly_16 = 0xFFFF

    for i = 1, dur do
        if bit.band(poly_16, 1) == 0 then table.insert(speaker.buffer, 0 - speaker.volume) else table.insert(speaker.buff, speaker.volume) end
        prev_index = index
        index = index + incr
        if index > 1.0 then index = index - 1.0 end
        if prev_index < 0.5 and index >= 0.5 then
            poly_16 = bit.bor(bit.blshift(bit.bxor(bit.band(bit.brshift(poly_16, noise_type), 1), bit.band(poly_16, 1)), 15), bit.brshift(poly_16, 1))
        end
        if #speaker.buffer > 4*1024 then wave.play(speaker) end
    end
    wave.play(speaker)
end

return wave
