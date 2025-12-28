local midiAvatar = "b0e11a12-eada-4f28-bb70-eb8903219fe5"
local directory = "ChloesMidiPlayer"

local midiPlayer = {
    page = action_wheel:newPage("midiPlayerPage"),
    settings = action_wheel:newPage("midiPlayerSettings"),
    returnPage = nil,
    hasMadeInstance = false,
    midiAPI = nil,
    avatarID = {},
    instance = nil,
    songs = {},
    songIndex = {},
    pingQueue = {},
    selectedSong = 1,
    pageSize = 20,
    pingSize = 450,
    limitRoleback = 5
}

midiPlayer.avatarID[1],midiPlayer.avatarID[2],midiPlayer.avatarID[3],midiPlayer.avatarID[4] = client.uuidToIntArray(midiAvatar)

local midiPlayerHeadItem = world.newItem([=[minecraft:player_head{display:{Name:'{"text":"midiHead"}'},SkullOwner:{Id:[I;]=]..midiPlayer.avatarID[1]..","..midiPlayer.avatarID[2]..","..midiPlayer.avatarID[3]..","..midiPlayer.avatarID[4]..[=[]}}]=])
local worldPart = models:newPart("midiPLayerHead","WORLD")
local midiPlayerHeadTask = models.midiPLayerHead:newItem("midiPlayerHead")
midiPlayerHeadTask:setItem(midiPlayerHeadItem)
    :setScale(0)

local actions = {}

function events.render()
    if midiPlayer.instance then
        midiPlayer.instance:updatePlayer()
    end
end

function events.tick()
    if midiPlayer.instance then
        midiPlayer.instance:updateParser()
    end
end

function events.tick()
    if not midiPlayer.hasMadeInstance then
        midiPlayer.midiAPI = world.avatarVars()[midiAvatar]
        if midiPlayer.midiAPI and midiPlayer.midiAPI.newInstance then
            local player = world.getEntity(avatar:getUUID())
            midiPlayer.instance = midiPlayer.midiAPI.newInstance(player:getName(),player)
            midiPlayer.hasMadeInstance = true
            if host:isHost() then
                actions.midiPlayer:setTitle("Midi Player")
                    :setOnLeftClick(function() action_wheel:setPage(midiPlayer.page) end)
            end
        end
    end
end

function pings.sendSong(ID,currentChunk,isLastChunk,data)
    if not midiPlayer.instance then return end
    if not midiPlayer.instance.songs[ID] then
        midiPlayer.instance:newSong(ID,"")
        midiPlayer.instance.songs[ID].songChunks = {}
    end
    midiPlayer.instance.songs[ID].songChunks[currentChunk] = data
    if isLastChunk then
        local rawSong = ""
        for _,chunk in ipairs(midiPlayer.instance.songs[ID].songChunks) do
            rawSong = rawSong .. chunk
        end
        midiPlayer.instance.songs[ID].rawSong = rawSong
    end
end

function pings.updateSong(ID,action)
    if not midiPlayer.instance then return end
    if action == 1 then
        midiPlayer.instance.songs[ID]:play()
    elseif action == 2 then
       midiPlayer.instance.songs[ID]:pause()
    elseif action == 0 then
        midiPlayer.instance.songs[ID]:stop()
    end
end

if not host:isHost() then return end

config:setName("chloesMidiPlayer")
local pingSize = config:load("pingSize")
if pingSize then
    midiPlayer.pingSize = pingSize
end
local limitRoleback = config:load("limitRoleback")
if limitRoleback then
    midiPlayer.limitRoleback = limitRoleback
end


local function generateSongSelector()
    local songTitle = "song selector \n"
    local selectedPage = math.floor((midiPlayer.selectedSong - 1) / midiPlayer.pageSize)
    for k,v in pairs(midiPlayer.songIndex) do
        local currentPage = math.floor((k - 1) / midiPlayer.pageSize)
        if currentPage == selectedPage then
            if k == midiPlayer.selectedSong then
                songTitle = songTitle .. "§r→ "  .. v .. "\n"
            else
                songTitle = songTitle .. ":cross_mark: ".. "§c" .. v .. "\n"
            end
        end
    end
    local lastPage = math.floor((#midiPlayer.songIndex - 1) / midiPlayer.pageSize)
    songTitle = songTitle .. "§rpage " .. selectedPage + 1 .. " of " .. lastPage + 1
    actions.songs:setTitle(songTitle)
end

actions.back = midiPlayer.page:newAction()
    :setTitle("back")
    :setOnLeftClick(function()
        if midiPlayer.returnPage then
            action_wheel:setPage(midiPlayer.returnPage)
        end
    end)
actions.settings = midiPlayer.page:newAction()
    :setTitle("settings")
    :setOnLeftClick(function()
        action_wheel:setPage(midiPlayer.settings)
    end)

actions.songs = midiPlayer.page:newAction()
    :setTitle("songs")
    :setOnScroll(function(scroll)
        midiPlayer.selectedSong = math.clamp(midiPlayer.selectedSong - scroll,1,#midiPlayer.songIndex)
        generateSongSelector()
    end)

actions.settingsBack = midiPlayer.settings:newAction()
    :setTitle("back")
    :setOnLeftClick(function()
        action_wheel:setPage(midiPlayer.page)
    end)

actions.pingSize = midiPlayer.settings:newAction()
    :setTitle("ping size \n" .. tostring(midiPlayer.pingSize) .. " b/s")
    :setOnScroll(function(scroll) 
        midiPlayer.pingSize = midiPlayer.pingSize + (scroll * 5)
        config:save("pingSize",midiPlayer.pingSize)
        actions.pingSize:setTitle("ping size \n" .. tostring(midiPlayer.pingSize) .. " b/s")
    end)

actions.limitRoleback = midiPlayer.settings:newAction()
    :setTitle("limit roleback \n" .. tostring(midiPlayer.limitRoleback) .. " pings")
    :setOnScroll(function(scroll) 
        midiPlayer.limitRoleback = math.max(0,midiPlayer.limitRoleback + (scroll))
        config:save("limitRoleback",midiPlayer.limitRoleback)
        actions.limitRoleback:setTitle("limit roleback \n" .. tostring(midiPlayer.limitRoleback) .. " pings")
    end)

midiPlayer.song = {}
midiPlayer.song.__index = midiPlayer.song

function midiPlayer.song:new(name,rawData)    
    self = setmetatable({},midiPlayer.song)
    self.ID = name
    self.rawData = rawData
    self.isPinged = false
    self.totalChunks = math.floor(string.len(rawData) / midiPlayer.pingSize)
    self.currentChunk = 0
    self.nameLength = string.len(name)
    self.pingSize = midiPlayer.pingSize
    return self
end


function midiPlayer:addMidiPlayer(page)
    midiPlayer.returnPage = page
    actions.midiPlayer = page:newAction()
        :setTitle("Midi Player\nERROR: Midi player avatar is not loaded")
end

local function fast_read_byte_array(path)
    local stream = file:openReadStream(path)
    local future = stream:readAsync()
    repeat until future:isDone()
    return future:getValue()--[[@as string]]
end

local function getMidiData()
    if not file:isDirectory(directory) then
        file:mkdir(directory)
        log('"'..directory..'" folder has been created')
    end
    for k,fileName in pairs(file:list(directory)) do
        local path = directory.."/"..fileName
        local suffix = string.sub(fileName,-4,-1)
        local name = string.sub(fileName,1,-5)
        if suffix == ".mid" and (not midiPlayer.songs[name]) then
            local midiData = fast_read_byte_array(path)
            midiPlayer.songs[name] = midiPlayer.song:new(name,midiData)
            table.insert(midiPlayer.songIndex,name)
        end
    end
end

getMidiData()
table.sort(midiPlayer.songIndex)
generateSongSelector()

function events.MOUSE_PRESS(key,state,bitmast)
    local actionWheelOpen = action_wheel:isEnabled()
    local currentPage = action_wheel:getCurrentPage():getTitle()
    local selectedAction = action_wheel:getSelected()
    if actionWheelOpen and currentPage == "midiPlayerPage" and selectedAction == 3 then
        if state == 1 then
            local selectedSongLocal = midiPlayer.songs[midiPlayer.songIndex[midiPlayer.selectedSong]]
            local selectedSongPinged = midiPlayer.instance.songs[midiPlayer.songIndex[midiPlayer.selectedSong]]
            if key == 0 then
                if not selectedSongLocal.isPinged then
                    table.insert(midiPlayer.pingQueue,selectedSongLocal.ID)
                else
                    if selectedSongPinged.state == "STOPPED" or selectedSongPinged.state == "PAUSED" then
                        pings.updateSong(selectedSongPinged.ID,1)
                    elseif selectedSongPinged.state == "PLAYING" then
                        pings.updateSong(selectedSongPinged.ID,2)
                    end
                end
            elseif key == 1 then
                if midiPlayer.instance.activeSong and selectedSongLocal.isPinged then
                    pings.updateSong(midiPlayer.instance.songs[midiPlayer.instance.activeSong].ID,0)
                end
            end
        end
    end
end

function events.on_play_sound(sound)
    if sound == "minecraft:ui.toast.in" then
        if midiPlayer.pingQueue[1] then
            midiPlayer.songs[midiPlayer.pingQueue[1]].currentChunk = math.max(0,midiPlayer.songs[midiPlayer.pingQueue[1]].currentChunk - midiPlayer.limitRoleback)
        end
    end
end

local clock = 0
function events.tick()
    clock = clock + 1
    if not (clock % 20 == 0) then return end
    local queuedSong = midiPlayer.pingQueue[1]
    if queuedSong then
        local currentChunk = midiPlayer.songs[queuedSong].currentChunk
        local pingSize = midiPlayer.songs[queuedSong].pingSize - midiPlayer.songs[queuedSong].nameLength - 9
        local totalChunks = midiPlayer.songs[queuedSong].totalChunks
        local rawData = midiPlayer.songs[queuedSong].rawData
        local dataChunk = string.sub(rawData,currentChunk * pingSize,((currentChunk + 1) * pingSize) - 1)
        local isLastChunk = currentChunk == totalChunks
        if isLastChunk then
            midiPlayer.songs[queuedSong].isPinged = true
            local newQueue = {}
            for k = 2,#midiPlayer.pingQueue do
                table.insert(newQueue,midiPlayer.pingQueue[k])
            end
            midiPlayer.pingQueue = newQueue
        else
            midiPlayer.songs[queuedSong].currentChunk = currentChunk + 1
        end
        pings.sendSong(queuedSong,currentChunk + 1,isLastChunk,dataChunk)
    end
end

return midiPlayer