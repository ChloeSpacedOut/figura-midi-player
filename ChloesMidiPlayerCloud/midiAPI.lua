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
    self.state = "STOPPED"
    self.loopState = false
    self.loaded = false
    self.isLoading = false
    self.loadAmount = 0
    self.post = nil
    self.speed = 1
    self.tempo = 500000
    self.activeTrack = 1 -- only used for format 2
    self.clock = 0
    self.rawSong = rawData
    return self
end

function midi.song:play()
    if self.instance.activeSong and (self.instance.activeSong ~= self.ID) then
        self.instance.songs[self.instance.activeSong]:stop()
    end
    if not self.loaded then
        if not self.isLoading then
            midiParser.readMidi(self,true)
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

function midi.song:loop(bool)
    self.loopState = bool
    return self
end

function midi.song:setLoop(bool)
    self.loopState = bool
    return self
end

function midi.song:getLoop()
    return self.loopState
end

function midi.song:setPost(funct)
    self.post = funct
    return self
end

function midi.song:getPost()
    return self.post
end

function midi.song:setSpeed(speed)
    self.speed = speed
    return self
end

function midi.song:getSpeed()
    return self.speed
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


function midi.song:load()
    midiParser.readMidi(self)
    return self
end

function midi.song:remove()
    self.instance.songs[self.ID]:stop()
    self.instance.songs[self.ID] = nil
end

function midi.track:new()
    self = setmetatable({},midi.track)
    self.sequenceIndex = 1
    self.lastEventTime = 0
    self.isEnded = false
    self.sequence = {}
    return self
end

function midi.channel:new(instance,ID)
    self = setmetatable({},midi.channel)
    self.ID = ID
    self.instance = instance
    self.instrument = 0
    return self
end

function midi.channel:remove()
    self.instance.channels[self.ID] = nil
end

function midi.note:play(instance,pitch,velocity,currentChannel,track,sysTime)
    self = setmetatable({},midi.note)
    self.state = "PLAYING"
    self.instance = instance
    self.pitch = pitch
    self.velocity = velocity/100
    self.channel = currentChannel
    self.track = track
    self.initTime = sysTime
    local channelObject = instance.channels[currentChannel]
    if not channelObject then
        channelObject = midi.channel:new(instance,currentChannel)
        instance.channels[currentChannel] = channelObject
    end
    if currentChannel ~= 9 then
        self.instrument = soundfont.soundTree[channelObject.instrument + 1]
    else
        self.instrument = soundfont.soundTree[129]
    end
    if not self.instrument then
        local redundancy = soundfont.redundancyMappings[channelObject.instrument + 1]
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

    if not instance.target then
        return self
    end

    if not instance.target.getPos then
        return self
    end

    self.duration = soundfont.soundDuration[soundID]

    self.sound = sounds[soundID]
    self.sound:pos(instance.target:getPos()):volume(self.velocity):pitch(soundPitch):loop(not hasMain):subtitle("MIDI song plays"):play()
    
    --sounds:playSound(soundID,instance.target:getPos(),self.velocity,soundPitch,not hasMain):setSubtitle("MIDI song plays")
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
    
    local soundID = template.."Sustain."..soundSample
    local soundPitch = self.instrument.Sustain[tostring(self.pitch)].pitch
    if self.instrument.Main then
        self.sound:stop()
        self.loopSound = sounds[soundID]
        self.loopSound:pos(self.instance.target:getPos()):volume(self.velocity):pitch(soundPitch):loop(true):subtitle("MIDI song plays"):play()
        
        --sounds:playSound(soundID,self.instance.target:getPos(),self.velocity,soundPitch,true):setSubtitle("MIDI song plays")
    else
        self.loopSound = self.sound
    end
end

function midi.note:release(sysTime)
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
    self.instance.tracks[self.track][tostring(self.pitch)] = nil
end

midi.events = {
    noteOn = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        if instance.tracks[trackID][eventData.key] then
            instance.tracks[trackID][eventData.key]:stop()
        end
        instance.tracks[trackID][eventData.key] = midi.note:play(instance,eventData.key,eventData.velocity,eventData.channel,trackID,sysTime)
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
    end
}

return midi
