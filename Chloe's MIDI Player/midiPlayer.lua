--[================[
TO DO
- tempo support
- volume support
- instrument support
- channel control messages
- resolve sound not always being cancled (possible an end of track issue?)

]================]

local midiPlayer = {
    directory = "ChloesMidiPlayer",
    songs = {},
    activeSong = nil,
    tracks = {},
    channels = {},
    soundTree = {},
    soundDuration = {}
}


local function getOggDuration(soundID)
    local ogg_bytes = ""
    for k,v in pairs(avatar:getNBT().sounds[soundID]) do
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
            if not midiPlayer.soundTree[tonumber(index)] then
                midiPlayer.soundTree[tonumber(index)] = {}
            end
            if not midiPlayer.soundTree[tonumber(index)][type] then
                midiPlayer.soundTree[tonumber(index)][type] = {}
            end
            if not midiPlayer.soundTree[tonumber(index)][type].notes then
                midiPlayer.soundTree[tonumber(index)][type].notes = {}
            end
            midiPlayer.soundTree[tonumber(index)].template = templateString
            table.insert(midiPlayer.soundTree[tonumber(index)][type].notes,tonumber(note))
        end
    end
end

-- bake pitches
for _,sound in pairs(midiPlayer.soundTree) do
    for k,type in pairs(sound) do
        if k ~= "template" then
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

local song = {}
song.__index = song

local track = {}
track.__index = track

local channel = {}
channel.__index = channel

local note = {}
note.__index = note

function song:new()
    self = setmetatable({},song)
    self.tracks = {}
    self.state = "STOPPED"
    self.tempo = 500000
    self.activeTrack = 1 -- only used for format 2
    return self
end

function song:play()
    self.state = "PLAYING"
    midiPlayer.activeSong = self.ID
    local sysTime = client.getSystemTime()
    for k,v in pairs(self.tracks) do
        v.sequenceIndex = 1
        v.lastEventTime = sysTime
    end
    return self
end

function song:stop()
    midiPlayer.activeSong = nil
    self.state = "STOPPED"
    return self
end

function track:new()
    self = setmetatable({},track)
    self.sequenceIndex = 1
    self.lastEventTime = 0
    self.sequence = {}
    return self
end

function channel:new()
    self = setmetatable({},channel)
    self.instrument = 0
    return self
end


function note:new(pitch,velocity,currentChannel,track,sysTime)
    self = setmetatable({},note)
    self.pitch = pitch
    self.velocity = velocity
    self.channel = currentChannel
    self.track = track
    self.initTime = sysTime
    local channelObject = midiPlayer.channels[currentChannel]
    if not channelObject then
        channelObject = channel:new()
    end
    self.instrument = midiPlayer.soundTree[channelObject.instrument + 1]
    if not self.instrument then
        self.instrument = midiPlayer.soundTree[1]
    end
    local soundSample = self.instrument.Main[pitch].sample
    local template = self.instrument.template
    local soundID = template.."Main."..soundSample
    local soundPitch = self.instrument.Main[pitch].pitch
    if not midiPlayer.soundDuration[soundID] then
        midiPlayer.soundDuration[soundID] = getOggDuration(soundID)
    end
    self.duration = midiPlayer.soundDuration[soundID]
    self.sound = sounds:playSound(soundID,player:getPos(),1,soundPitch)
    return self
end

function note:sustain(sustainTime)
    local template = self.instrument.template
    local soundSample = self.instrument.Sustain[self.pitch].sample
    
    local soundID = template.."Sustain."..soundSample
    local soundPitch = self.instrument.Main[self.pitch].pitch
    self.loopSound = sounds:playSound(soundID,player:getPos(),1,soundPitch,true)
    self.sustainTime = sustainTime 
end

function note:stop()
    self.sound:stop()
    if self.loopSound then
        self.loopSound:stop()
    end
    midiPlayer.tracks[self.track][self.pitch] = nil
end

local midiEvents = {
    noteOn = function(eventData,sysTime,activeTrack,trackID,activeSong)
        midiPlayer.tracks[trackID][eventData.key] = note:new(eventData.key,eventData.velocity,eventData.channel,trackID,sysTime)
        --log(midiPlayer.channels[eventData.channel][eventData.key])
    end,
    noteOff = function(eventData,sysTime,activeTrack,trackID,activeSong)
        if midiPlayer.tracks[trackID][eventData.key] then
            midiPlayer.tracks[trackID][eventData.key]:stop()
        else
            log("warn: tried to end key event while key not pressed",eventData)
        end
    end,
    endOfTrack = function(eventData,sysTime,activeTrack,trackID,activeSong)
        activeSong:stop()
    end,
    setTempo = function(eventData,sysTime,activeTrack,trackID,activeSong)
        activeTrack.tempo = eventData.tempo / (activeSong.ticksPerQuaterNote * 1000)
        activeSong.defaultTempo = eventData.tempo
    end,
    programChange = function(eventData,sysTime,activeTrack,trackID,activeSong)
        if not midiPlayer.channels[eventData.channel] then
            midiPlayer.channels[eventData.channel] = channel:new()
        end
        midiPlayer.channels[eventData.channel].instrument = eventData.newProgramNumber
    end

}

function events.render(delta)
    local sysTime = client.getSystemTime()
    local activeSong = midiPlayer.songs[midiPlayer.activeSong]
    if activeSong and activeSong.state == "PLAYING" then
        for trackID, activeTrack in pairs(activeSong.tracks) do repeat
            if not midiPlayer.tracks[trackID] then
                midiPlayer.tracks[trackID] = {}
            end
            for i = activeTrack.sequenceIndex, #activeTrack.sequence do 
                if (sysTime - activeTrack.lastEventTime) >= (activeTrack.sequence[i].deltaTime * (activeSong.tempo / (activeSong.ticksPerQuaterNote * 855))) then -- fix bug with clubP at *1.25
                    local typeFunction = midiEvents[activeTrack.sequence[i].type]
                    if typeFunction then
                        typeFunction(activeTrack.sequence[i],sysTime,activeTrack,trackID,activeSong)
                        activeTrack.lastEventTime = sysTime
                    end
                else
                    activeTrack.sequenceIndex = i
                    break
                end
             end
        until true end
        for _,channel in pairs(midiPlayer.tracks) do
            for _,note in pairs(channel) do
                if (note.initTime + math.floor(note.duration - 7) <= sysTime) and (not note.loopSound) then -- replace with note end check based on duration
                    note.sound:stop()
                    note:sustain(sysTime)
                elseif note.loopSound then
                    -- divide by 0 check needed
                    --log(note.duration)
                    local val = (1/(note.pitch/12))/((sysTime - note.sustainTime)/100)
                    local pitchMod = ((note.pitch/12) * 500)
                    local fadeVal = math.clamp(8000 - (sysTime - note.sustainTime) - pitchMod,0,8000)
                    note.loopSound:setVolume(math.map(fadeVal,0,8000 - pitchMod,0,1))
                end
            end
        end
    end
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
local voiceMessages = {
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
        midiSong.numTracks = buffer:readShort()
        local bits = readBits(buffer,2)
        if bits[16] == 0 then
            midiSong.ticksPerQuaterNote = bitsToNum(bits,0,14)
        elseif bits[16] == 1 then -- untested
            midiSong.framesPerSecond = math.abs(bitsToNum(bits,8,14) - 128)
            midiSong.ticksPerFrame = bitsToNum(bits,0,7)
        end
        while buffer:readString(4) == "MTrk" do
            local currentTrack = track:new()
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
                        metaEvents[type](buffer,currentTrack,deltaTime,eventLength)
                    end
                else
                    buffer:setPosition(buffer:getPosition() - 1)
                    local nextBits = readBits(buffer,1)
                    local statusByte = bitsToNum(nextBits,4,7)
                    --log(statusByte,nextBits)
                    if voiceMessages[statusByte] then
                        voiceMessages[statusByte](buffer,currentTrack,deltaTime,nextBits)
                    else
                        log("Failed reading byte " .. string.format("%X",buffer:getPosition() - 1).." with value " .. string.format("%X",nextByte))
                    end
                end
            end
            table.insert(midiSong.tracks, currentTrack)
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
    --logTable(midiSong,4)
end

local function getMidiData()
    if not file:isDirectory(midiPlayer.directory) then
        file:mkdir(midiPlayer.directory)
        log('"ChloesMidiPlayer" folder has been created')
    end
    for k,fileName in pairs(file:list(midiPlayer.directory)) do
        local path = midiPlayer.directory.."/"..fileName
        local suffix = string.sub(fileName,-4,-1)
        local name = string.sub(fileName,1,-5)
        if suffix == ".mid" and (not midiPlayer.songs[name]) then
            midiPlayer.songs[name] = song:new()
            midiPlayer.songs[name].ID = name
            local midiData = fast_read_byte_array(path)
            readMidi(midiPlayer.songs[name],midiData)
        end
    end
end

getMidiData()

return midiPlayer
