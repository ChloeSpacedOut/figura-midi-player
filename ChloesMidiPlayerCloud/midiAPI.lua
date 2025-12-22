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
    self.tempo = 500000
    self.activeTrack = 1 -- only used for format 2
    self.clock = 0
    self.rawSong = rawData
    return self
end

function midi.song:play()
    self.state = "PLAYING"
    if not next(self.tracks) then
        midiParser.readMidi(self,midi)
    end
    self.instance.activeSong = self.ID
    local sysTime = client.getSystemTime()
    for k,v in pairs(self.tracks) do
        v.sequenceIndex = 1
        v.lastEventTime = nil
    end
    return self
end

function midi.song:stop()
    self.instance.activeSong = nil
    self.state = "STOPPED"
    for _,track in pairs(midiPlayer.tracks) do
        for _,note in pairs(track) do
            note:stop()
        end
    end
    return self
end

function midi.song:read()
    midiParser.readMidi(self,midi)
    return self
end

function midi.track:new()
    self = setmetatable({},midi.track)
    self.sequenceIndex = 1
    self.lastEventTime = 0
    self.sequence = {}
    return self
end

function midi.channel:new()
    self = setmetatable({},midi.channel)
    self.instrument = 0
    return self
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
        channelObject = midi.channel:new()
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
        soundSample = self.instrument.Main[pitch].sample
        soundPitch = self.instrument.Main[pitch].pitch
        template = self.instrument.template
        soundID = template.."Main."..soundSample
    else
        soundSample = self.instrument.Sustain[pitch].sample
        soundPitch = self.instrument.Sustain[pitch].pitch
        template = self.instrument.template
        soundID = template.."Sustain."..soundSample
        hasMain = false
    end
    self.soundPitch = soundPitch

    if not soundfont.soundDuration[soundID] then
        soundfont.soundDuration[soundID] = utils.getOggDuration(soundID)
    end
    self.duration = soundfont.soundDuration[soundID]
    self.sound = sounds:playSound(soundID,player:getPos(),self.velocity,soundPitch,not hasMain)
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
    local soundSample = self.instrument.Sustain[self.pitch].sample
    
    local soundID = template.."Sustain."..soundSample
    local soundPitch = self.instrument.Sustain[self.pitch].pitch
    if self.instrument.Main then
        self.sound:stop()
        self.loopSound = sounds:playSound(soundID,player:getPos(),self.velocity,soundPitch,true)
    else
        self.loopSound = self.sound
    end
end

function midi.note:release(sysTime)
    self.state = "RELEASED"
    self.releaseTime = sysTime
end

function midi.note:stop()
    self.sound:stop()
    if self.loopSound then
        self.loopSound:stop()
    end
    self.instance.tracks[self.track][self.pitch] = nil
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
        activeSong:stop()
    end,
    setTempo = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        activeSong.tempo = eventData.tempo
    end,
    programChange = function(instance,eventData,sysTime,activeTrack,trackID,activeSong)
        if not instance.channels[eventData.channel] then
            instance.channels[eventData.channel] = midi.channel:new()
        end
        instance.channels[eventData.channel].instrument = eventData.newProgramNumber
    end
}

return midi
