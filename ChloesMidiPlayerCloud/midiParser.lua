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

local function readVariableLengthInt(buffer,bufferLength)
    local startPos = buffer:getPosition()
    repeat
        local val = buffer:read()
        local signBit = bit32.extract(val,7)
    until signBit == 0 or buffer:getPosition() == bufferLength
    local endPos = buffer:getPosition()
    buffer:setPosition(startPos)
    local bits = readBits(buffer,endPos - startPos)
    local num = variableLengthBitsToNum(bits)
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
            hours = buffer:read(),
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
            data = buffer:readBase64(eventLength)
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
    [0x8] = function(buffer,currentTrack,deltaTime,channel)
        table.insert(currentTrack.sequence,{
            type = "noteOff",
            deltaTime = deltaTime,
            channel = channel,
            key = bitsToNum(readBits(buffer,1),0,6),
            velocity = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0x9] = function(buffer,currentTrack,deltaTime,channel)
        table.insert(currentTrack.sequence,{
            type = "noteOn",
            deltaTime = deltaTime,
            channel = channel,
            key = bitsToNum(readBits(buffer,1),0,6),
            velocity = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xA] = function(buffer,currentTrack,deltaTime,channel)
        table.insert(currentTrack.sequence,{
            type = "polyphonicKeyPressure",
            deltaTime = deltaTime,
            channel = channel,
            key = bitsToNum(readBits(buffer,1),0,6),
            pressure = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xB] = function(buffer,currentTrack,deltaTime,channel)
        table.insert(currentTrack.sequence,{
            type = "controllerChange",
            deltaTime = deltaTime,
            channel = channel,
            controllerNumber = bitsToNum(readBits(buffer,1),0,6),
            controllerValue = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xC] = function(buffer,currentTrack,deltaTime,channel)
        table.insert(currentTrack.sequence,{
            type = "programChange",
            deltaTime = deltaTime,
            channel = channel,
            newProgramNumber = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xD] = function(buffer,currentTrack,deltaTime,channel)
        table.insert(currentTrack.sequence,{
            type = "channelKeyPressure",
            deltaTime = deltaTime,
            channel = channel,
            channelPressureValue = bitsToNum(readBits(buffer,1),0,6)
        })
    end,
    [0xE] = function(buffer,currentTrack,deltaTime,channel)
        local leastSignificantByte = readBits(buffer,1)
        local mostSignificantByte = readBits(buffer,1)
        local pitchBend = {}
        for  i = 1,7 do
            pitchBend[i] = leastSignificantByte[i]
        end
        for  i = 1,7 do
            pitchBend[i + 7] = mostSignificantByte[i]
        end
        table.insert(currentTrack.sequence,{
            type = "pitchBend",
            deltaTime = deltaTime,
            channel = channel,
            pitchBend = bitsToNum(pitchBend,0,13)
        })
    end
}

midiParser.sysexEvents = {
    [0xF0] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "sysEx",
            deltaTime = deltaTime,
            data = buffer:readBase64(eventLength)
        })
    end,
    [0xF7] = function(buffer,currentTrack,deltaTime,eventLength)
        table.insert(currentTrack.sequence,{
            type = "sysExEscape",
            deltaTime = deltaTime,
            data = buffer:readBase64(eventLength)
        })
    end
}

midiParser.project = {}
midiParser.project.__index = midiParser.project

function midiParser.project:new(midiSong,speed,shouldQueueSong)
    self = setmetatable({},midiParser.project)
    if not speed then speed = 1 end
    self.ID = midiSong.ID
    self.shouldQueueSong = shouldQueueSong
    self.midiData = midiSong.rawSong
    self.song = midiSong
    self.song.parseProject = self
    self.buffer = data:createBuffer()
    self.buffer:writeByteArray(self.midiData)
    self.buffer:setPosition(0)
    self.lastBufferPos = 0
    self.currentChunk = 0
    self.chunkSize = 1000 * speed
    self.numEvents = 0
    self.eventProgress = 0
    self.hasReadHeader = false
    self.hasParsedMidi = false
    self.hasBakedTimes = false
    self.currentTrack = nil
    self.lastStatusBits = nil
    self.lastChannel = nil
    self.warns = {}
    return self
end

function midiParser.project:remove()
    self.buffer:close()
    self.song.parseProject = nil
    midiParser.projects[self.ID] = nil
end

local function exitParser(project)
    project.song.loaded = true
    project.song.isLoading = false
    if project.shouldQueueSong then
        project.song:play()
    end
    if #project.warns ~= 0 then
        log("Warns created when parsing " .. project.ID,project.warns)
    end
    project:remove()
end

function midiParser.updateParser(midi)
    for _,project in pairs(midiParser.projects) do
        local buffer = project.buffer
        if buffer:isClosed() then
            if project then
                project:remove()
            end
            break
        end
        local bufferLength = buffer:getLength()
        project.currentChunk = project.currentChunk + 1
        if not project.hasReadHeader then
            local fileHeader = buffer:readString(4)
            if fileHeader == "MThd" then
                project.hasReadHeader = true
                buffer:setPosition(buffer:getPosition()+4)
                project.song.format = buffer:readShort()
                project.song.numTracks = buffer:readShort()
                local bits = readBits(buffer,2)
                if bits[16] == 0 then
                    project.song.ticksPerQuarterNote = bitsToNum(bits,0,14)
                elseif bits[16] == 1 then -- untested
                    project.song.framesPerSecond = math.abs(bitsToNum(bits,8,14) - 128)
                    project.song.ticksPerFrame = bitsToNum(bits,0,7)
                end
            else
                log("Midi file header was invalid, cancled parsing " .. project.ID .. ". Recieved data: " .. fileHeader)
                project:remove()
                return
            end
        elseif not project.hasParsedMidi then
            project.song.loadProgress = math.clamp(buffer:getPosition()/ project.buffer:getLength() / 2,0,1)
            if not project.currentTrack then
                local trackHeader = buffer:readString(4)
                if trackHeader == "MTrk" then
                    project.currentTrack = midi.track:new()
                    project.currentTrack.length = buffer:readInt()
                    project.currentTrack.eventStartPos = buffer:getPosition()
                else
                    local warn = "Failed reading track header at position " .. string.format("%X", buffer:getPosition()) .. " with value " .. trackHeader
                    table.insert(project.warns, warn)
                end
            end
            if project.currentTrack then
                repeat
                    local deltaTime = readVariableLengthInt(buffer)
                    local nextByte = buffer:read()
                    if nextByte == 255 then
                        local type = buffer:read()
                        local eventLength = readVariableLengthInt(buffer)
                        --log("metaEvent",nextByte,string.format("%X", type),eventLength,string.format("%X", buffer:getPosition()))
                        if midiParser.metaEvents[type] then
                            midiParser.metaEvents[type](buffer, project.currentTrack, deltaTime, eventLength)
                        else
                            buffer:readBase64(eventLength)
                        end
                    else
                        buffer:setPosition(buffer:getPosition() - 1)
                        local statusByte = buffer:read()
                        buffer:setPosition(buffer:getPosition() - 1)
                        local nextBits = readBits(buffer, 1)
                        local statusBits = bitsToNum(nextBits, 4, 7)
                        local channel = bitsToNum(nextBits, 0, 3)
                        if midiParser.voiceMessages[statusBits] then
                            --log("voiceMessage",string.format("%X", statusBits),channel,string.format("%X", buffer:getPosition()))
                            midiParser.voiceMessages[statusBits](buffer, project.currentTrack, deltaTime, channel)
                            project.lastStatusBits = statusBits
                            project.lastChannel = channel
                        elseif midiParser.sysexEvents[statusByte] then
                            local eventLength = readVariableLengthInt(buffer)
                            --log("sysexEvent",string.format("%X", statusByte),eventLength,string.format("%X", buffer:getPosition()))
                            midiParser.sysexEvents[statusByte](buffer, project.currentTrack, deltaTime, eventLength)
                        else
                            if bit32.extract(statusBits, 7) == 0 and project.lastStatusBits then
                                buffer:setPosition(buffer:getPosition() - 1)
                                --log("compactVoiceMessage",string.format("%X", project.lastStatusBits),project.lastChannel,string.format("%X", buffer:getPosition()))
                                midiParser.voiceMessages[project.lastStatusBits](buffer, project.currentTrack, deltaTime,project.lastChannel)
                            else
                                local warn = "Failed reading byte " .. string.format("%X", buffer:getPosition() - 1) .. " with value " .. string.format("%X", nextByte)
                                table.insert(project.warns, warn)
                            end
                        end
                    end
                until ((buffer:getPosition() - project.currentTrack.eventStartPos) >= project.currentTrack.length) or (buffer:getPosition() >= (project.currentChunk * project.chunkSize) or (buffer:getPosition() == bufferLength))
                if not ((buffer:getPosition() - project.currentTrack.eventStartPos) < project.currentTrack.length) then
                    table.insert(project.song.tracks, project.currentTrack)
                    project.currentTrack = nil
                end
                local bufferEndPos = buffer:getPosition()
                if bufferEndPos == project.lastBufferPos then
                    buffer:setPosition(bufferEndPos + 1)
                end
            end
            project.lastBufferPos = buffer:getPosition()
            if project.lastBufferPos == bufferLength then
                project.hasParsedMidi = true
                project.currentChunk = 0
                for _,track in pairs(project.song.tracks) do
                    project.numEvents = project.numEvents + #track.sequence
                end
            end
        elseif not project.hasBakedTimes then
            local chunkSize = project.chunkSize / 50
            project.song.loadProgress = math.clamp(0.5 + (project.eventProgress / project.numEvents) / 2,0,1)
            for i = (project.currentChunk - 1) * chunkSize + 1,project.currentChunk * chunkSize do
                local clock = i * project.song.ticksPerQuarterNote
                local isSongEnded = true
                for trackID, activeTrack in pairs(project.song.tracks) do
                    if not activeTrack.isEnded then
                        isSongEnded = false
                        for j = activeTrack.sequenceIndex, #activeTrack.sequence do
                            if not activeTrack.lastEventTime then
                                activeTrack.lastEventTime = clock
                            end
                            local eventDeltaTime = clock - activeTrack.lastEventTime
                            local targetDelta = activeTrack.sequence[j].deltaTime
                            if targetDelta > 100000000 then -- i hate midi
                                targetDelta = 0
                            end
                            if eventDeltaTime >= targetDelta then
                                project.eventProgress = project.eventProgress + 1
                                local timePassed = targetDelta * (project.song.tempo / (project.song.ticksPerQuarterNote * 1000))
                                activeTrack.trackLength = activeTrack.trackLength + timePassed
                                if activeTrack.sequence[j].type == "setTempo" then
                                    project.song.tempo = activeTrack.sequence[j].tempo
                                elseif activeTrack.sequence[j].type == "endOfTrack" then
                                    activeTrack.isEnded = true
                                end
                                activeTrack.lastEventTime = clock - (eventDeltaTime - targetDelta)
                            else
                                if not project.song.bakedQuarterNotes[i] then
                                    project.song.bakedQuarterNotes[i] = {}
                                end
                                project.song.bakedQuarterNotes[i].tempo = project.song.tempo
                                project.song.bakedQuarterNotes[i].clock = clock
                                project.song.bakedQuarterNotes[i][trackID] = {
                                    sequenceIndex = j,
                                    lastEventTime = activeTrack.lastEventTime,
                                    time = activeTrack.trackLength
                                }
                                activeTrack.sequenceIndex = j
                                break
                            end
                        end
                    else
                        --log(activeTrack.sequenceIndex,#activeTrack.sequence)
                    end
                end
                if isSongEnded then
                    local maxLength = 0
                    for _,track in pairs(project.song.tracks) do
                        if track.trackLength > maxLength then
                            maxLength = track.trackLength
                        end
                        track.lastEventTime = 0
                        track.sequenceIndex = 1
                        track.isEnded = false
                    end
                    project.song.length = maxLength
                    project.song.lengthQuarterNotes = #project.song.bakedQuarterNotes
                    project.hasBakedTimes = true
                    project.song.tempo = 500000
                    project.song.clock = 0
                    exitParser(project)
                    break
                end
            end
        end
    end
end

function midiParser.readMidi(midiSong,speed,shouldQueueSong)
    midiParser.projects[midiSong.ID] = midiParser.project:new(midiSong,speed,shouldQueueSong)
end

return midiParser