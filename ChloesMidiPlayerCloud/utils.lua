local utils = {}

local nbt = avatar:getNBT()
function utils.getOggDuration(soundID)
    local ogg_bytes = ""
    for k,v in pairs(nbt.sounds[soundID]) do
        ogg_bytes = ogg_bytes .. string.char(v % 128)
    end

    local vorbis_pos = ogg_bytes:find("vorbis", 1, true)

    local r1, r2, r3, r4 = ogg_bytes:byte(vorbis_pos + 11, vorbis_pos + 14)
    local rate = r1 + r2 * 256 + r3 * 65536 + r4 * 16777216

    local last_oggs = 1
    for pos in ogg_bytes:gmatch("()OggS") do
        last_oggs = pos
    end

    local b1, b2, b3, b4, b5, b6, b7, b8 = ogg_bytes:byte(last_oggs + 6, last_oggs + 13)
    local low = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
    local high = b5 + b6 * 256 + b7 * 65536 + b8 * 16777216
    local granule_pos = low + high * 4294967296

    return (granule_pos * 1000) / rate
end

return utils