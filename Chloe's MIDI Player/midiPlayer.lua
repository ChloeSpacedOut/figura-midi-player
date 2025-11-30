local midPlayer = {
    directory = "ChloesMidiPlayer",
    songs = {}
}

local song = {}
song.__index = song

local chunk = {}
chunk.__index = chunk

function song:new()
    self = setmetatable({},song)
    self.chunks = {}
    return self
end

function chunk:new()
    self = setmetatable({},chunk)
    self.sequence = {}
    return self
end

local function fast_read_byte_array(path)
    local stream = file:openReadStream(path)
    local future = stream:readAsync()
    repeat until future:isDone()
    return future:getValue()--[[@as string]]
end

local function readBits(buffer,numBytes)
    local bufferPos = buffer:getPosition()
    local bits = {}
    for i = 0, (numBytes - 1) do
        buffer:setPosition(bufferPos + (numBytes - 1) - i)
        local currentVal = buffer:read()
        for bit = 0,7 do
            table.insert(bits,bit32.extract(currentVal,bit))
        end
    end
    buffer:setPosition(bufferPos + numBytes)
    return bits
end

local function bitsToNum(bits,start,stop)
    local num = 0
    for i = start, stop do
        num = num + (bits[i + 1] * (2 ^ (i - start)))
    end
    return num
end

local function variableLengthBitsToNum(bits)
    local num = 0
    local power = 0
    for k,v in ipairs(bits) do
        if not ((k) % 8 == 0) then
            num = num + (bits[k] * (2 ^ power))
            power = power + 1
        else
        end
    end
    return num
end

local metaEvents = {
    [0x00] = function(buffer,currentChunk,deltaTime,eventLength)
        currentChunk.sequenceNumber = buffer:readShort()
    end,
    [0x01] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "textEvent",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x02] = function(buffer,currentChunk,deltaTime,eventLength)
        currentChunk.copyrightNotice = buffer:readString(eventLength)
    end,
    [0x03] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "sequenceOrTrackName",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x04] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "instrumentName",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x05] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "lyric",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x06] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "marker",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x07] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "cuePoint",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x20] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "midiChannelPrefix",
            deltaTime = deltaTime,
            channel = buffer:read()
        })
    end,
    [0x2F] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "endOfTrack",
            deltaTime = deltaTime
        })
    end,
    [0x51] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "setTempo",
            deltaTime = deltaTime,
            tempo = bitsToNum(readBits(buffer,3),0,23)
        })
    end,
    [0x54] = function(buffer,currentChunk,deltaTime,eventLength)
        currentChunk.smtpeOffset = {
            hours = buffer:readShort(),
            minutes = buffer:read(),
            seconds = buffer:read(),
            frames = buffer:read(),
            fractionalFrame = buffer:read()
        }
    end,
    [0x58] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "timeSignature",
            deltaTime = deltaTime,
            numerator = buffer:read(),
            denominator = buffer:read(),
            clocksPerMetronomeTick = buffer:read(),
            noOf32thsNotesPer24MidiClocks = buffer:read()
        })
    end,
    [0x59] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "keySignature",
            deltaTime = deltaTime,
            noOfSharpsOrFlats = buffer:read(),
            majorOrMinorKey = buffer:read()
        })
    end,
    [0x7F] = function(buffer,currentChunk,deltaTime,eventLength)
        table.insert(currentChunk.sequence,{
            type = "sequencerSpecificMetaEvent",
            deltaTime = deltaTime,
            id = buffer:read(),
            data = buffer:readString(eventLength)
        })
    end,
}
local voiceMessages = {
    [0x8] = function(buffer,currentChunk,deltaTime,initialBits)
        table.insert(currentChunk.sequence,{
            type = "noteOff",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            key = bitsToNum(readBits(buffer,1),0,6),
            velocity = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0x9] = function(buffer,currentChunk,deltaTime,initialBits)
        table.insert(currentChunk.sequence,{
            type = "noteOn",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            key = bitsToNum(readBits(buffer,1),0,6),
            velocity = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xA] = function(buffer,currentChunk,deltaTime,initialBits)
        table.insert(currentChunk.sequence,{
            type = "polyphonicKeyPressure",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            key = bitsToNum(readBits(buffer,1),0,6),
            pressure = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xB] = function(buffer,currentChunk,deltaTime,initialBits)
        table.insert(currentChunk.sequence,{
            type = "controllerChange",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            controllerNumber = bitsToNum(readBits(buffer,1),0,6),
            controllerValue = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xC] = function(buffer,currentChunk,deltaTime,initialBits)
        table.insert(currentChunk.sequence,{
            type = "programChange",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            newProgramNumber = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xD] = function(buffer,currentChunk,deltaTime,initialBits)
        table.insert(currentChunk.sequence,{
            type = "channelKeyPressure",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            channelPressureValue = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xE] = function(buffer,currentChunk,deltaTime,initialBits)
        table.insert(currentChunk.sequence,{
            type = "pitchBend",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            leastSignificantByte = bitsToNum(readBits(buffer,1),0,6),
            mostSignificantByte = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
}

local function readMidi(midiSong,midiData)
    local buffer = data:createBuffer()
    buffer:writeByteArray(midiData)
    buffer:setPosition(0)
    local bufferLength = buffer:getLength()
    local lastBufferPos = 0
    if buffer:readString(4) == "MThd" then
        buffer:setPosition(buffer:getPosition()+4)
        midiSong.format = buffer:readShort()
        midiSong.tracks = buffer:readShort()
        local bits = readBits(buffer,2)
        if bits[16] == 0 then
            midiSong.ticksPerQuaterNote = bitsToNum(bits,0,14)
        elseif bits[16] == 1 then -- untested
            midiSong.framesPerSecond = math.abs(bitsToNum(bits,8,14) - 128)
            midiSong.ticksPerFrame = bitsToNum(bits,0,7)
        end
        while buffer:readString(4) == "MTrk" do
            local currentChunk = chunk:new()
            local length = buffer:readInt()
            local eventStartPos = buffer:getPosition()
            while (buffer:getPosition() - eventStartPos) < length do
                local startPos = buffer:getPosition()
                repeat
                    local val = buffer:read()
                    local signBit = bit32.extract(val,7)
                until signBit == 0
                local endPos = buffer:getPosition()
                buffer:setPosition(startPos)
                local deltaBits = readBits(buffer,endPos - startPos)
                local deltaTime = variableLengthBitsToNum(deltaBits)
                buffer:setPosition(endPos)
                local nextByte = buffer:read()
                if nextByte == 255 then
                    local type = buffer:read()
                    local eventLength = buffer:read()
                    if metaEvents[type] then
                        metaEvents[type](buffer,currentChunk,deltaTime,eventLength)
                    end
                else
                    buffer:setPosition(buffer:getPosition() - 1)
                    local nextBits = readBits(buffer,1)
                    local statusByte = bitsToNum(nextBits,4,7)
                    --log(statusByte,nextBits)
                    if voiceMessages[statusByte] then
                        voiceMessages[statusByte](buffer,currentChunk,deltaTime,nextBits)
                    else
                        log(nextByte)
                    end
                end
            end
            table.insert(midiSong.chunks, currentChunk)
        end
    else
        log("Midi file was invalid")
    end
    local bufferEndPos = buffer:getPosition()
    if bufferEndPos == lastBufferPos then
        buffer:setPosition(bufferEndPos + 1)
    end
    lastBufferPos = buffer:getPosition()

    buffer:close()
    logTable(midiSong,4)
end

local function getMidiData()
    if not file:isDirectory(midPlayer.directory) then
        file:mkdir(midPlayer.directory)
        log('"ChloesMidiPlayer" folder has been created')
    end
    for k,fileName in pairs(file:list(midPlayer.directory)) do
        local path = midPlayer.directory.."/"..fileName
        local suffix = string.sub(fileName,-4,-1)
        local name = string.sub(fileName,1,-5)
        if suffix == ".mid" and (not midPlayer.songs[name]) then
            midPlayer.songs[name] = song:new()
            local midiData = fast_read_byte_array(path)
            readMidi(midPlayer.songs[name],midiData)
        end
    end
end

getMidiData()
