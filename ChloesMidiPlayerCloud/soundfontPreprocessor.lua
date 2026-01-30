if not host:isHost() then return end
local soundfont = {
    soundTree = {},
    soundDuration = {}
}

soundfont.instruments = {
    [1] = {sustain = 0.97, resonance = 0.3, minVol = 0},
    [4] = {sustain = 0.97, resonance = 0.3, minVol = 0},
    [5] = {sustain = 0.97, resonance = 0.3, minVol = 0},
    [6] = {sustain = 0.9, resonance = 0.1, minVol = 0},
    [7] = {sustain = 0.9, resonance = 0.3, minVol = 0},
    [8] = {sustain = 0.9, resonance = 0.1, minVol = 0},
    [9] = {sustain = 0.85, resonance = 0.6, minVol = 0},
    [10] = {sustain = 0.8, resonance = 1, minVol = 0},
    [11] = {sustain = 0.9, resonance = 1, minVol = 0},
    [12] = {sustain = 0.94, resonance = 0.3, minVol = 0},
    [13] = {sustain = 0.85, resonance = 0.3,minVol = 0},
    [14] = {sustain = 1, resonance = 1, minVol = 0},
    [15] = {sustain = 0.85, resonance = 1, minVol = 0},
    [16] = {sustain = 0.8, resonance = 0.7, minVol = 0},
    [17] = {sustain = 1, resonance = 0.1, minVol = 0},
    [18] = {sustain = 1, resonance = 0.1, minVol = 0},
    [19] = {sustain = 1, resonance = 0.1, minVol = 0},
    [20] = {sustain = 1, resonance = 0.5, minVol = 0},
    [21] = {sustain = 1, resonance = 0.1, minVol = 0},
    [22] = {sustain = 1, resonance = 0.1, minVol = 0},
    [23] = {sustain = 1, resonance = 0.1, minVol = 0},
    [24] = {sustain = 1, resonance = 0.1, minVol = 0},
    [25] = {sustain = 0.94, resonance = 0.3, minVol = 0},
    [26] = {sustain = 0.9, resonance = 0.3, minVol = 0},
    [27] = {sustain = 0.92, resonance = 0.3, minVol = 0},
    [28] = {sustain = 0.92, resonance = 0.3, minVol = 0},
    [29] = {sustain = 0.92, resonance = 0.3, minVol = 0},
    [30] = {sustain = 0.9, resonance = 0.1, minVol = 0.5},
    [31] = {sustain = 1, resonance = 0.1, minVol = 0},
    [32] = {sustain = 0.97, resonance = 0.1, minVol = 0},
    [33] = {sustain = 0.9, resonance = 0.1, minVol = 0.07},
    [34] = {sustain = 0.9, resonance = 0.1, minVol = 0.2},
    [35] = {sustain = 0.9, resonance = 0.1, minVol = 0.2},
    [36] = {sustain = 0.97, resonance = 0.1, minVol = 0},
    [37] = {sustain = 0.97, resonance = 0.1, minVol = 0},
    [38] = {sustain = 0.95, resonance = 0.1, minVol = 0},
    [39] = {sustain = 0.9, resonance = 0.1, minVol = 0},
    [40] = {sustain = 0.94, resonance = 0.1, minVol = 0.1},
    [41] = {sustain = 1, resonance = 0.1, minVol = 0},
    [43] = {sustain = 1, resonance = 0.1, minVol = 0},
    [44] = {sustain = 1, resonance = 0.1, minVol = 0},
    [45] = {sustain = 1, resonance = 0.3, minVol = 0},
    [46] = {sustain = 1, resonance = 1, minVol = 0},
    [47] = {sustain = 0.9, resonance = 1, minVol = 0},
    [48] = {sustain = 1, resonance = 1, minVol = 0},
    [49] = {sustain = 1, resonance = 0.5, minVol = 0},
    [50] = {sustain = 1, resonance = 0.5, minVol = 0},
    [51] = {sustain = 1, resonance = 0.5, minVol = 0},
    [53] = {sustain = 1, resonance = 0.5, minVol = 0},
    [54] = {sustain = 0.94, resonance = 0.5, minVol = 0.5},
    [55] = {sustain = 1, resonance = 0.5, minVol = 0},
    [56] = {sustain = 1, resonance = 1, minVol = 0},
    [57] = {sustain = 1, resonance = 0.1, minVol = 0},
    [58] = {sustain = 1, resonance = 0.1, minVol = 0},
    [59] = {sustain = 1, resonance = 0.1, minVol = 0},
    [60] = {sustain = 1, resonance = 0.1, minVol = 0},
    [61] = {sustain = 1, resonance = 0.1, minVol = 0},
    [62] = {sustain = 1, resonance = 0.1, minVol = 0},
    [63] = {sustain = 1, resonance = 0.1, minVol = 0},
    [64] = {sustain = 1, resonance = 0.1, minVol = 0},
    [65] = {sustain = 1, resonance = 0.1, minVol = 0},
    [66] = {sustain = 1, resonance = 0.05, minVol = 0},
    [67] = {sustain = 1, resonance = 0.05, minVol = 0},
    [68] = {sustain = 1, resonance = 0.05, minVol = 0},
    [69] = {sustain = 1, resonance = 0.05, minVol = 0},
    [70] = {sustain = 1, resonance = 0.05, minVol = 0},
    [71] = {sustain = 1, resonance = 0.05, minVol = 0},
    [72] = {sustain = 1, resonance = 0.1, minVol = 0},
    [73] = {sustain = 1, resonance = 0.1, minVol = 0},
    [74] = {sustain = 1, resonance = 0.1, minVol = 0},
    [75] = {sustain = 1, resonance = 0.05, minVol = 0},
    [76] = {sustain = 1, resonance = 0.05, minVol = 0},
    [77] = {sustain = 1, resonance = 0.1, minVol = 0},
    [78] = {sustain = 1, resonance = 0.1, minVol = 0},
    [79] = {sustain = 1, resonance = 0.3, minVol = 0},
    [80] = {sustain = 1, resonance = 0.05, minVol = 0},
    [81] = {sustain = 1, resonance = 0.05, minVol = 0},
    [82] = {sustain = 1, resonance = 0.05, minVol = 0},
    [83] = {sustain = 1, resonance = 0.1, minVol = 0},
    [84] = {sustain = 1, resonance = 0.1, minVol = 0},
    [85] = {sustain = 1, resonance = 0.05, minVol = 0},
    [86] = {sustain = 1, resonance = 0.2, minVol = 0},
    [87] = {sustain = 1, resonance = 0.3, minVol = 0},
    [88] = {sustain = 1, resonance = 0.1, minVol = 0},
    [89] = {sustain = 0.95, resonance = 0.7, minVol = 0.3},
    [90] = {sustain = 1, resonance = 0.7, minVol = 0},
    [91] = {sustain = 0.95, resonance = 0.3, minVol = 0.5},
    [92] = {sustain = 1, resonance = 0.7, minVol = 0},
    [93] = {sustain = 0.95, resonance = 0.7, minVol = 0.3},
    [94] = {sustain = 0.93, resonance = 0.7, minVol = 0},
    [96] = {sustain = 1, resonance = 0.7, minVol = 0},
    [97] = {sustain = 0.93, resonance = 0.7, minVol = 0},
    [98] = {sustain = 0.97, resonance = 0.7, minVol = 0.5},
    [99] = {sustain = 0.93, resonance = 1, minVol = 0},
    [100] = {sustain = 0.93, resonance = 0.7, minVol = 0.3},
    [101] = {sustain = 0.93, resonance = 0, minVol = 0},
    [102] = {sustain = 1, resonance = 0.8, minVol = 0},
    [103] = {sustain = 1, resonance = 0.8, minVol = 0},
    [104] = {sustain = 1, resonance = 0.8, minVol = 0},
    [105] = {sustain = 0.96, resonance = 0.7, minVol = 0},
    [106] = {sustain = 0.93, resonance = 0.5, minVol = 0},
    [107] = {sustain = 0.85, resonance = 0.5, minVol = 0},
    [108] = {sustain = 0.88, resonance = 1, minVol = 0},
    [109] = {sustain = 1, resonance = 1, minVol = 0},
    [110] = {sustain = 1, resonance = 0.2, minVol = 0},
    [111] = {sustain = 1, resonance = 0.2, minVol = 0},
    [113] = {sustain = 1, resonance = 1, minVol = 0},
    [114] = {sustain = 1, resonance = 1, minVol = 0},
    [115] = {sustain = 1, resonance = 1, minVol = 0},
    [116] = {sustain = 1, resonance = 1, minVol = 0},
    [117] = {sustain = 0.8, resonance = 1, minVol = 0},
    [118] = {sustain = 1, resonance = 1, minVol = 0},
    [119] = {sustain = 1, resonance = 1, minVol = 0},
    [120] = {sustain = 1, resonance = 0.1, minVol = 0},
    [121] = {sustain = 1, resonance = 1, minVol = 0},
    [122] = {sustain = 1, resonance = 1, minVol = 0},
    [123] = {sustain = 1, resonance = 0.8, minVol = 0},
    [124] = {sustain = 0.95, resonance = 0.8, minVol = 0},
    [125] = {sustain = 1, resonance = 0.1, minVol = 0},
    [126] = {sustain = 1, resonance = 0.8, minVol = 0},
    [127] = {sustain = 1, resonance = 0.8, minVol = 0},
    [128] = {sustain = 1, resonance = 1, minVol = 0},
    [129] = {sustain = 1, resonance = 1, minVol = 0},
}
soundfont.redundancyMappings = {
    [2] = 1,
    [3] = 1,
    [42] = 41,
    [52] = 51,
    [95] = 53,
    [112] = 110
}

soundfont.redundancyNames = {
    [2] = "Bright Acoustic Piano",
    [3] = "Electric Grand Piano",
    [42] = "Viola",
    [52] = "SynthStrings 2",
    [95] = "Pad 7 (halo)",
    [112] = "Shanai"
}

-- generate soundTree
for _,soundString in pairs(sounds:getCustomSounds()) do
    if string.sub(soundString,1,7) == "samples" then
        local index,type,note
        local depth = 1
        for string in string.gmatch(soundString,"([^.]*)") do
            if depth == 2 then
                index = string
            elseif depth == 4 then
                type = string
            elseif depth == 5 then
                note = string
            end
            depth = depth + 1
        end
        if note and (type == "Sustain" or type == "Main") then
            local templateString = string.match(soundString, "(.*)%.[^%.]+$")
            templateString = string.match(templateString, "(.*)%.[^%.]+$") .. "."
            if not soundfont.soundTree[tonumber(index)] then
                soundfont.soundTree[tonumber(index)] = {}
            end
            if not soundfont.soundTree[tonumber(index)][type] then
                soundfont.soundTree[tonumber(index)][type] = {}
            end
            if not soundfont.soundTree[tonumber(index)][type].notes then
                soundfont.soundTree[tonumber(index)][type].notes = {}
            end
            soundfont.soundTree[tonumber(index)].template = templateString
            soundfont.soundTree[tonumber(index)].index = tonumber(index)
            table.insert(soundfont.soundTree[tonumber(index)][type].notes,tonumber(note))
        end
    end
end

-- bake pitches
for _,sound in pairs(soundfont.soundTree) do
    for k,type in pairs(sound) do
        if k ~= "template" and k ~= "index" then
            table.sort(type.notes,function(a, b)
                return a < b
            end)
            local currentSample = 1
            for k = 0, 127 do
                local currentSamplePitch = type.notes[currentSample]
                local nextSamplePitch = type.notes[currentSample + 1]
                local maxPitch
                if nextSamplePitch then
                    maxPitch = math.ceil((currentSamplePitch + nextSamplePitch)/2)
                else
                    maxPitch = 127
                end
                type[k] = {sample = currentSamplePitch, pitch = 2^((k - currentSamplePitch)/12)}
                if k >= maxPitch then
                    currentSample = currentSample + 1
                end
            end
        end
    end
end

local soundfontJson = toJson(soundfont)
addScript("soundfont",[===[return(parseJson([[]===]..soundfontJson..[==[]]))]==],"both")