local midiParser = require("midiParser")
local soundfont = require("soundfont")
local utils = require("utils")
local midi = {}

midi.song = {}
midi.song.__index = midi.song

midi.track = {}
midi.track.__index = midi.track

midi.channel = {}
midi.channel.__index = midi.channel

midi.note = {}
midi.note.__index = midi.note

function midi.song:new(instnace,ID,rawData)
    self = setmetatable({},midi.song)
    self.ID = ID
    self.instance = instnace
    self.tracks = {}
    self.bakedQuarterNotes = {}
    self.parseProject = nil
    self.state = "STOPPED"
    self.loopState = false
    self.loaded = false
    self.isLoading = false
    self.loadProgress = 0
    self.post = nil
    self.speed = 1
    self.tempo = 500000
    self.activeTrack = 1 -- only used for format 2
    self.clock = 0
    self.lastSysTime = nil
    self.time = 0
    self.length = 0
    self.lengthQuarterNotes = 0
    self.rawSong = rawData
    return self
end

function midi.song:play()
    self.lastSysTime = client.getSystemTime()
    if self.instance.activeSong and (self.instance.activeSong ~= self.ID) then
        self.instance.songs[self.instance.activeSong]:stop()
    end
    if not self.loaded then
        if not self.isLoading then
            midiParser.readMidi(self,1,true)
            self.isLoading = true
            return self
        else
            return self
        end
    end
    if self.state == "PLAYING" then
        return self
    elseif self.state == "PAUSED" then
        self.state = "PLAYING"
        return self
    elseif self.state == "STOPPED" then
        self.state = "PLAYING"
        self.instance.activeSong = self.ID
        for _,track in pairs(self.tracks) do
            track.sequenceIndex = 1
            track.lastEventTime = nil
        end
        return self 
    end
end

function midi.song:stop()
    if not self.loaded then
        return self
    end
    self.instance.activeSong = nil
    self.state = "STOPPED"
    self.tempo = 500000
    self.clock = 0
    self.time = 0
    for _,track in pairs(self.tracks) do
        track.lastEventTime = 0
        track.sequenceIndex = 1
        track.isEnded = false
    end
    for _,track in pairs(self.instance.tracks) do
        for _,note in pairs(track) do
            note:stop()
        end
    end
    for _,channel in pairs(self.instance.channels) do
        channel:remove()
    end
    return self
end

function midi.song:loop()
    self.loopState = true
    return self
end

function midi.song:setLoop(bool)
    self.loopState = bool
    return self
end

function midi.song:getLoop()
    return self.loopState
end

function midi.song:setPost(func)
    self.post = func
    return self
end

function midi.song:setSpeed(speed)
    self.speed = speed
    return self
end

function midi.song:getSpeed()
    return self.speed
end

function midi.song:setTime(quaterNote)
    quaterNote = math.floor(quaterNote % self.lengthQuarterNotes)
    local timeData = self.bakedQuarterNotes[quaterNote]
    self.tempo = timeData.tempo
    self.clock = timeData.clock
    local maxTime = 0
    for trackID,track in pairs(self.tracks) do
        if timeData[trackID] then
            track.sequenceIndex = timeData[trackID].sequenceIndex
            track.lastEventTime = timeData[trackID].lastEventTime
            if timeData[trackID].time > maxTime then
                maxTime = timeData[trackID].time
            end
        end
    end
    self.time = maxTime
    return self
end

function midi.song:getTime()
    return self.clock / self.ticksPerQuarterNote
end

function midi.song:pause()
    if not self.loaded then
        return self
    end
    self.state = "PAUSED"
    for _,track in pairs(self.instance.tracks) do
        for _,note in pairs(track) do
            if note.sound then
                note.sound:setVolume(0)
            end
            if note.loopSound then
                note.loopSound:setVolume(0)
            end
        end
    end
    return self
end


function midi.song:load(speed)
    midiParser.readMidi(self,speed)
    return self
end

function midi.song:remove()
    if self.parseProject then   
        self.parseProject:remove()
    end
    self.instance.songs[self.ID]:stop()
    self.instance.songs[self.ID] = nil
    -- add removing parser projects here
end

function midi.track:new()
    self = setmetatable({},midi.track)
    self.sequenceIndex = 1
    self.lastEventTime = 0
    self.isEnded = false
    self.trackLength = 0
    self.sequence = {}
    return self
end

function midi.channel:new(instance,ID)
    self = setmetatable({},midi.channel)
    self.ID = ID
    self.instance = instance
    self.instrument = 0
    self.pitchBend = 8192
    self.rpnData = {
        paramMSB = nil,
        paramLSB = nil,
        valMSB = nil,
        valLSB = nil
    }
    self.pitchBendRange = 2
    self.volume = 1
    return self
end

function midi.channel:remove()
    self.instance.channels[self.ID] = nil
end

function midi.note:play(instance,pitch,velocity,currentChannel,track,sysTime,pos)
    self = setmetatable({},midi.note)
    if instance.tracks[track][pitch] then
        instance.tracks[track][pitch]:stop()
    end
    self.state = "PLAYING"
    self.instance = instance
    self.pitch = pitch
    self.velocity = velocity/100
    self.channel = currentChannel
    self.track = track
    self.pos = pos
    self.initTime = sysTime
    local channel = instance.channels[currentChannel]
    if not channel then
        channel = midi.channel:new(instance,currentChannel)
        instance.channels[currentChannel] = channel
    end
    if currentChannel ~= 9 then
        self.instrument = soundfont.soundTree[channel.instrument + 1]
    else
        self.instrument = soundfont.soundTree[129]
    end
    if not self.instrument then
        local redundancy = soundfont.redundancyMappings[tostring(channel.instrument + 1)]
        if redundancy then
            self.instrument = soundfont.soundTree[redundancy]
        else
            self.instrument = soundfont.soundTree[1]
        end
    end

    local hasMain = true
    local soundSample,soundPitch,template,soundID
    if self.instrument.Main then
        soundSample = self.instrument.Main[tostring(pitch)].sample
        soundPitch = self.instrument.Main[tostring(pitch)].pitch
        template = self.instrument.template
        soundID = template.."Main."..soundSample
    else
        soundSample = self.instrument.Sustain[tostring(pitch)].sample
        soundPitch = self.instrument.Sustain[tostring(pitch)].pitch
        template = self.instrument.template
        soundID = template.."Sustain."..soundSample
        hasMain = false
    end
    self.soundPitch = soundPitch

    if not soundfont.soundDuration[soundID] then
        soundfont.soundDuration[soundID] = utils.getOggDuration(soundID)
    end

    local targetPos
    if type(instance.target) == "Vector3" then
        targetPos = instance.target
    else
        if not instance.target.getPos then
            return
        end
        targetPos = instance.target:getPos()
    end
    if pos then targetPos = pos end

    self.duration = soundfont.soundDuration[soundID]

    self.sound = sounds[soundID]
    local soundPitch = self.soundPitch * 2^(math.map(channel.pitchBend,0,16383,-channel.pitchBendRange,channel.pitchBendRange)/12)
    self.sound:pos(targetPos):volume(self.velocity * channel.volume * instance.volume):pitch(soundPitch):loop(not hasMain):subtitle("MIDI song plays"):play()
    instance.tracks[track][pitch] = self
    return self
end

function midi.note:sustain()
    if not self.instrument.Sustain then
        self.state = "RELEASED"
        return
    end
    if self.state ~= "RELEASED" then 
        self.state = "SUSTAINING"
    end
    local template = self.instrument.template
    local soundSample = self.instrument.Sustain[tostring(self.pitch)].sample

    local targetPos
    if type(self.instance.target) == "Vector3" then
        targetPos = self.instance.target
    else
        if not self.instance.target.getPos then
            return
        end
        targetPos = self.instance.target:getPos()
    end
    
    local soundID = template.."Sustain."..soundSample
    local channel = self.instance.channels[self.channel]
    if self.instrument.Main then
        self.sound:stop()
        self.loopSound = sounds[soundID]
        local pitch = self.soundPitch * 2^(math.map(channel.pitchBend,0,16383,-channel.pitchBendRange,channel.pitchBendRange)/12)
        self.loopSound:pos(targetPos):volume(self.velocity * channel.volume * self.instance.volume):pitch(pitch):loop(true):subtitle("MIDI song plays"):play()
    else
        self.loopSound = self.sound
    end
end

function midi.note:release(sysTime)
    if self.state == "RELEASED" then return end
    self.state = "RELEASED"
    self.releaseTime = sysTime
end

function midi.note:stop()
    if self.sound then
        self.sound:stop()
    end
    if self.loopSound then
        self.loopSound:stop()
    end
    self.instance.tracks[self.track][self.pitch] = nil
end

midi.events = {
    noteOn = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        if eventData.velocity == 0 then
            eventData.type = "noteOff"
            midi.events.noteOff(instance,eventData,sysTime,activeTrack,trackID,activeSong)
            return
        end
        midi.note:play(instance,eventData.key,eventData.velocity,eventData.channel,trackID,sysTime)
    end,
    noteOff = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        if instance.tracks[trackID][eventData.key] then
            local instrumentIndex = instance.tracks[trackID][eventData.key].instrument.index
            local instrument = soundfont.instruments[instrumentIndex]
            if instrument.resonance ~= 0 then
                instance.tracks[trackID][eventData.key]:release(sysTime)
            else
                instance.tracks[trackID][eventData.key]:stop()
            end
        end
    end,
    endOfTrack = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        activeTrack.isEnded = true
    end,
    setTempo = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        activeSong.tempo = eventData.tempo
    end,
    programChange = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        if not instance.channels[eventData.channel] then
            instance.channels[eventData.channel] = midi.channel:new(instance,eventData.channel)
        end
        instance.channels[eventData.channel].instrument = eventData.newProgramNumber
    end,
    controllerChange = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        if not instance.channels[eventData.channel] then
            instance.channels[eventData.channel] = midi.channel:new(instance,eventData.channel)
        end
        local channel = instance.channels[eventData.channel]
        -- Registered Parameter Number handler
        if (eventData.controllerNumber == 0x64 or eventData.controllerNumber == 0x65) and (channel.rpnData.valMSB or channel.rpnData.valLSB) then
            channel.rpnData = {}
        end
        if eventData.controllerNumber == 0x65 then
            channel.rpnData.paramMSB = eventData.controllerValue
        elseif eventData.controllerNumber == 0x64 then
            channel.rpnData.paramLSB = eventData.controllerValue
        elseif eventData.controllerNumber == 0x6 then
            channel.rpnData.valMSB = eventData.controllerValue
            if channel.rpnData.paramMSB == 0 and channel.rpnData.paramLSB == 0 then
                channel.pitchBendRange = eventData.controllerValue
            end
        end

        -- Channel Volume Control
        if eventData.controllerNumber == 0x7 then
            channel.volume = eventData.controllerValue/100
        end
    end,
    pitchBend = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        if not instance.channels[eventData.channel] then
            instance.channels[eventData.channel] = midi.channel:new(instance,eventData.channel)
        end
        instance.channels[eventData.channel].pitchBend = eventData.pitchBend
    end
}

return midi
