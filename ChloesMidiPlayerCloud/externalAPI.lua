-- midi player cloud by chloespacedout
-- version 1.3

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
    self.shouldKeepAlive = true
    self.shouldKeepAliveClock = 0
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
    for _,song in pairs(self.songs) do
        song:remove()
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

function instance:keepAlive()
    self.shouldKeepAlive = true
    self.shouldKeepAliveClock = 0
    return self
end

local function newInstance(ID,target,avatarInstance)
    if (not ID) or (not tostring(ID)) then
        log("Could not create midi player cloud instance as ID was invalid or not provided")
        return
    end
    ID = tostring(ID)
    local isValidTarget = (type(target) == "PlayerAPI") or (type(target) == "BlockState") or (type(target) == "Vector3")
    if (not target) or (not isValidTarget) then
        log("Could not create midi player cloud instance as target was invalid or not provided")
        return
    end
    if avatarInstance and type(avatarInstance) == "AvatarAPI" then
        local permissionLevel
        local avatarName
        local isSuccessful = pcall(function()
            permissionLevel = avatar.getPermissionLevel(avatarInstance)
            avatarName = avatar.getName(avatarInstance)
        end)
        if not isSuccessful then
            log("Could not create midi player cloud instance as avatar instance was invalid")
            return
        end
        if permissionLevel ~= "MAX" then
            log("Could not create midi player cloud instance as client \"" .. avatarName .. "\" is not set to MAX perms")
            return
        end
    else
        log("Could not create midi player cloud instance as avatar instance was invalid or not provided")
        return
    end
    if avatar:getPermissionLevel() ~= "MAX" then
        log("Could not create midi player cloud instance as midi player cloud is not set to MAX perms")
        return
    end
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
        local isInstanceAlive = true
        if currentInstance.shouldKillInstance then
            if currentInstance:shouldKillInstance() then
                currentInstance:remove()
                isInstanceAlive = false
            end
        end
        if isInstanceAlive then
            midiParser.updateParser(currentInstance)
            currentInstance.shouldKeepAliveClock = currentInstance.shouldKeepAliveClock + 1
            if currentInstance.shouldKeepAliveClock > 20 then
                currentInstance.shouldKeepAlive = false
            end
        end
    end
end

avatar:store("newInstance",newInstance)
avatar:store("listSounds",listSounds)
avatar:store("getSound",getSound)
avatar:store("sessionID",client.generateUUID())