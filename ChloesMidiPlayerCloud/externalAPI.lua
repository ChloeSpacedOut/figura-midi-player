-- midi player cloud by chloespacedout
-- version 1.0

local midiPlayer = require("midiPlayer")
local midiParser = require("midiParser")
local midi = require("midiAPI")
local soundfont = require("soundfont")

nameplate.ALL:setText("Midi Player Cloud")

local instance = {}
instance.__index = instance

function instance:new(ID,target)
    self = setmetatable({},instance)
    self.ID = ID
    self.activeSong = nil
    self.isRemoved = false
    self.target = target
    self.volume = 1
    self.attenuation = 1
    self.midi = midi
    self.soundfont = soundfont
    self.lastSysTime = client.getSystemTime()
    self.lastUpdated = client.getSystemTime()
    self.songs = {}
    self.tracks = {}
    self.channels = {}
    self.parseProjects = {}
    return self
end

function instance:remove()
    for _,track in pairs(self.tracks) do
        for _,note in pairs(track) do
            note:stop()
        end
    end
    if self.activeSong then
        self.songs[self.activeSong]:remove()
    end
    self.isRemoved = true
    midiPlayer.instances[self.ID] = nil
end

function instance:newSong(name,midiData)
    local song = midi.song:new(self,name,midiData)
    self.songs[name] = song
    return song
end

function instance:setTarget(target)
    self.target = target
    return self
end

function instance:getTarget()
    return self.target
end

function instance:setVolume(volume)
    self.volume = math.clamp(volume,0,1)
    return self
end

function instance:getVolume()
    return self.volume
end

function instance:getPermissionLevel()
    return avatar:getPermissionLevel()
end

function instance:setOnMidiEvent(func)
    self.onMidiEvent = func
    return self
end

function instance:setShouldKillInstance(func)
    self.shouldKillInstance = func
    return self
end

local function newInstance(ID,target)
    local addedInstance = instance:new(ID,target)
    if midiPlayer.instances[ID] then
        midiPlayer.instances[ID]:remove()
    end
    midiPlayer.instances[ID] = addedInstance
    return addedInstance
end

local function listSounds()
    return sounds:getCustomSounds()
end

local function getSound(id)
    return sounds[id]
end

function events.world_render()
    for ID,currentInstance in pairs(midiPlayer.instances) do
        midiPlayer.updatePlayer(currentInstance)
    end
end

function events.world_tick()
    for ID,currentInstance in pairs(midiPlayer.instances) do
        if currentInstance.shouldKillInstance then
            if currentInstance:shouldKillInstance() then
                currentInstance:remove()
            end
        end
        midiParser.updateParser(currentInstance,midi)
    end
end

avatar:store("newInstance",newInstance)
avatar:store("listSounds",listSounds)
avatar:store("getSound",getSound)
avatar:store("sessionID",client.generateUUID())