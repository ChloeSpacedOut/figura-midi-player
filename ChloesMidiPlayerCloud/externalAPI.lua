local midiPlayer = require("midiPlayer")
local midi = require("midiAPI")

local instance = {}
instance.__index = instance

function instance:new()
    self = setmetatable({},instance)
    self.activeSong = nil
    self.songs = {}
    self.tracks = {}
    self.channels = {}
    return self
end

function instance:addSong(name,midiData)
    self.songs[name] = midi.song:new(self,name,midiData)
end

function instance:removeSong(name)
    log('test')
end

function instance:render()
    midiPlayer.render(self)
end

local function newInstance()
    local newInstance = instance:new()
    table.insert(midiPlayer.instances,newInstance)
    return newInstance
end

avatar:store("newInstance",newInstance)