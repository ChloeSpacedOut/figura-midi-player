local midiPlayer = require("midiPlayer")
local midiParser = require("midiParser")
local midi = require("midiAPI")

local instance = {}
instance.__index = instance

function instance:new(ID,target)
    self = setmetatable({},instance)
    self.ID = ID
    self.activeSong = nil
    self.target = target
    self.midi = midi
    self.lastSysTime = client.getSystemTime()
    self.lastUpdated = client.getSystemTime()
    self.songs = {}
    self.tracks = {}
    self.channels = {}
    return self
end

function instance:remove()
    if self.activeSong then
        self.songs[self.activeSong]:remove()
    end
    midiPlayer.instances[self.ID] = nil
end

function instance:newSong(name,midiData)
    local song = midi.song:new(self,name,midiData)
    self.songs[name] = song
    return song
end

function instance:setTarget(target)
    self.target = target
end

function instance:getTarget()
    return self.target
end

function instance:getPermissionLevel()
    return avatar:getPermissionLevel()
end

function instance:updatePlayer()
    midiPlayer.updatePlayer(self)
    return self
end

function instance:updateParser()
    midiParser.updateParser(midi)
    return self
end

local function newInstance(ID,target)
    local newInstance = instance:new(ID,target)
    if midiPlayer.instances[ID] then
        midiPlayer.instances[ID]:remove()
    end
    midiPlayer.instances[ID] = newInstance
    return newInstance
end

avatar:store("newInstance",newInstance)
avatar:store("sessionID",math.random())