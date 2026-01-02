local midiParser = {
    projects = {}
}

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

midiParser.metaEvents = {
    [0x00] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "sequenceNumber",
            deltaTime = deltaTime,
            sequenceNumber = buffer:readShort()
        })
    end,
    [0x01] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "textEvent",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x02] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "copyrightNotice",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x03] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "sequenceOrTrackName",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x04] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "instrumentName",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x05] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "lyric",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x06] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "marker",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x07] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "cuePoint",
            deltaTime = deltaTime,
            text = buffer:readString(eventLength)
        })
    end,
    [0x20] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "midiChannelPrefix",
            deltaTime = deltaTime,
            channel = buffer:read()
        })
    end,
    [0x2F] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "endOfTrack",
            deltaTime = deltaTime
        })
    end,
    [0x51] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "setTempo",
            deltaTime = deltaTime,
            tempo = bitsToNum(readBits(buffer,3),0,23)
        })
    end,
    [0x54] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "smtpeOffset",
            deltaTime = deltaTime,
            hours = buffer:readShort(),
            minutes = buffer:read(),
            seconds = buffer:read(),
            frames = buffer:read(),
            fractionalFrame = buffer:read()
        })
    end,
    [0x58] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "timeSignature",
            deltaTime = deltaTime,
            numerator = buffer:read(),
            denominator = buffer:read(),
            clocksPerMetronomeTick = buffer:read(),
            noOf32thsNotesPer24MidiClocks = buffer:read()
        })
    end,
    [0x59] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "keySignature",
            deltaTime = deltaTime,
            noOfSharpsOrFlats = buffer:read(),
            majorOrMinorKey = buffer:read()
        })
    end,
    [0x7F] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "sequencerSpecificMetaEvent",
            deltaTime = deltaTime,
            id = buffer:read(),
            data = buffer:readString(eventLength)
        })
    end,
    [0x21] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "midPort",
            deltaTime = deltaTime,
            port = buffer:read()
        })
    end
}

midiParser.voiceMessages = {
    [0x8] = function(buffer,currentTrack,deltaTime,initialBits)
        table.insert(currentTrack.sequence,{
            type = "noteOff",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            key = bitsToNum(readBits(buffer,1),0,6),
            velocity = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0x9] = function(buffer,currentTrack,deltaTime,initialBits)
        table.insert(currentTrack.sequence,{
            type = "noteOn",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            key = bitsToNum(readBits(buffer,1),0,6),
            velocity = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xA] = function(buffer,currentTrack,deltaTime,initialBits)
        table.insert(currentTrack.sequence,{
            type = "polyphonicKeyPressure",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            key = bitsToNum(readBits(buffer,1),0,6),
            pressure = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xB] = function(buffer,currentTrack,deltaTime,initialBits)
        table.insert(currentTrack.sequence,{
            type = "controllerChange",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            controllerNumber = bitsToNum(readBits(buffer,1),0,6),
            controllerValue = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xC] = function(buffer,currentTrack,deltaTime,initialBits)
        table.insert(currentTrack.sequence,{
            type = "programChange",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            newProgramNumber = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xD] = function(buffer,currentTrack,deltaTime,initialBits)
        table.insert(currentTrack.sequence,{
            type = "channelKeyPressure",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            channelPressureValue = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xE] = function(buffer,currentTrack,deltaTime,initialBits)
        table.insert(currentTrack.sequence,{
            type = "pitchBend",
            deltaTime = deltaTime,
            channel = bitsToNum(initialBits,0,3),
            leastSignificantByte = bitsToNum(readBits(buffer,1),0,6),
            mostSignificantByte = bitsToNum(readBits(buffer,1),0,6)
        })
    end
}

midiParser.project = {}
midiParser.project.__index = midiParser.project

function midiParser.project:new(midiSong,shouldQueueSong)
    self = setmetatable({},midiParser.project)
    self.ID = midiSong.ID
    self.shouldQueueSong = shouldQueueSong
    self.midiData = midiSong.rawSong
    self.song = midiSong
    self.buffer = data:createBuffer()
    self.buffer:writeByteArray(self.midiData)
    self.buffer:setPosition(0)
    self.lastBufferPos = 0
    self.currentChunk = 0
    self.chunkSize = 500
    self.hasReadHeader = false
    self.currentTrack = nil
    return self
end

function midiParser.project:remove()
    self.buffer:close()
    midiParser.projects[self.ID] = nil
end

function midiParser.updateParser(midi)
    for _,project in pairs(midiParser.projects) do
        local buffer = project.buffer
        local bufferLength = buffer:getLength()
        project.currentChunk = project.currentChunk + 1
        if buffer:isClosed() then
            project:remove()
            break
        end
        -- read midi header
        if not project.hasReadHeader then
            if buffer:readString(4) == "MThd" then
                project.hasReadHeader = true
                buffer:setPosition(buffer:getPosition()+4)
                project.song.format = buffer:readShort()
                project.song.numTracks = buffer:readShort()
                local bits = readBits(buffer,2)
                if bits[16] == 0 then
                    project.song.ticksPerQuaterNote = bitsToNum(bits,0,14)
                elseif bits[16] == 1 then -- untested
                    project.song.framesPerSecond = math.abs(bitsToNum(bits,8,14) - 128)
                    project.song.ticksPerFrame = bitsToNum(bits,0,7)
                end
            else
                log("Midi file header was invalid")
                project:remove()
                return
            end
        
        end
        -- read track header
        if not project.currentTrack then
            if buffer:readString(4) == "MTrk" then
                project.currentTrack = midi.track:new()
                project.currentTrack.length = buffer:readInt()
                project.currentTrack.eventStartPos = buffer:getPosition()
            else
                -- midi track invalid
            end
        end
        -- read track
        while ((buffer:getPosition() - project.currentTrack.eventStartPos) < project.currentTrack.length) and (buffer:getPosition() < (project.currentChunk * project.chunkSize) and (buffer:getPosition() ~= bufferLength)) do
            project.song.loadAmount = buffer:getPosition()/bufferLength
            local startPos = buffer:getPosition()
            repeat
                local val = buffer:read()
                local signBit = bit32.extract(val,7)
            until signBit == 0 or buffer:getPosition() == bufferLength
            local endPos = buffer:getPosition()
            buffer:setPosition(startPos)
            local deltaBits = readBits(buffer,endPos - startPos)
            local deltaTime = variableLengthBitsToNum(deltaBits)
            buffer:setPosition(endPos)
            local nextByte = buffer:read()
            if nextByte == 255 then
                local type = buffer:read()
                local eventLength = buffer:read()
                if midiParser.metaEvents[type] then
                    midiParser.metaEvents[type](buffer,project.currentTrack,deltaTime,eventLength)
                end
            else
                buffer:setPosition(buffer:getPosition() - 1)
                local nextBits = readBits(buffer,1)
                local statusByte = bitsToNum(nextBits,4,7)
                if midiParser.voiceMessages[statusByte] then
                    midiParser.voiceMessages[statusByte](buffer,project.currentTrack,deltaTime,nextBits)
                else
                    log("Failed reading byte " .. string.format("%X",buffer:getPosition() - 1).." with value " .. string.format("%X",nextByte))
                end
            end
        end
        if not ((buffer:getPosition() - project.currentTrack.eventStartPos) < project.currentTrack.length) then
            table.insert(project.song.tracks, project.currentTrack)
            project.currentTrack = nil
        end
        local bufferEndPos = buffer:getPosition()
        if bufferEndPos == project.lastBufferPos then
            buffer:setPosition(bufferEndPos + 1)
        end
        project.lastBufferPos = buffer:getPosition()

        if bufferEndPos == bufferLength then
            project.song.loaded = true
            project.song.isLoading = false
            if project.shouldQueueSong then
                project.song:play()
            end
            project:remove()
        end
    end
end

function midiParser.readMidi(midiSong,shouldQueueSong)
    midiParser.projects[midiSong.ID] = midiParser.project:new(midiSong,shouldQueueSong)
end

return midiParser