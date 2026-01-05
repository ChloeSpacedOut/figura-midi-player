--#REGION global
--#REGION setup
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
    limitRoleback = 5,
    localMode = false
}
--#ENDREGION
--#REGION midi player cloud setup
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
--#ENDREGION
--#REGION decompress midi
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

midiPlayer.decompressProject = {}
midiPlayer.decompressProject.__index = midiPlayer.decompressProject

function midiPlayer.decompressProject:new(ID,compressedData)
    self = setmetatable({},midiPlayer.decompressProject)
    self.ID = ID
    self.buffer = data:createBuffer()
    self.buffer:writeByteArray(compressedData)
    self.buffer:setPosition(0)
    self.bufferLength = self.buffer:getLength()
    self.patternIndexEnd = readVariableLengthInt(self.buffer,self.bufferLength) + self.buffer:getPosition()
    self.patternIndex = {}
    self.hasReadPatternIndex = false
    self.hasReadPatterns = false
    self.currentChunk = 0
    self.chunkSize = 1000
    self.decompressedData = ""
    for i = 0,255 do
        table.insert(self.patternIndex,string.char(i))
    end
    return self
end

midiPlayer.decompressProjects = {}

function midiPlayer.decompressProject:remove()
    self.buffer:close()
    midiPlayer.decompressProjects[self.ID] = nil
end

function events.tick()
    for _,project in pairs(midiPlayer.decompressProjects) do
        local buffer = project.buffer
        project.currentChunk = project.currentChunk + 1
        if not project.hasReadPatternIndex then
            repeat
                local index = readVariableLengthInt(buffer,project.bufferLength)
                local numBytes = readVariableLengthInt(buffer,project.bufferLength)
                local bytes = buffer:readByteArray(numBytes)
                project.patternIndex[index] = bytes
                if buffer:getPosition() == project.patternIndexEnd then
                    project.hasReadPatternIndex = true
                end
            until (buffer:getPosition() == project.patternIndexEnd) or (buffer:getPosition() >= (project.currentChunk * project.chunkSize)) or (buffer:getPosition() == project.bufferLength)
        elseif not project.hasReadPatterns then
            repeat
                local index = readVariableLengthInt(buffer,project.bufferLength)
                if project.patternIndex[index] then
                   project.decompressedData = project.decompressedData .. project.patternIndex[index]
                end
                if project.bufferLength == buffer:getPosition() then
                    midiPlayer.instance.songs[project.ID].rawSong = project.decompressedData
                    project.hasReadPatterns = true
                    project:remove()
                    midiPlayer.instance.songs[project.ID]:load()
                    if host:isHost() then
                        midiPlayer.songs[project.ID].state = "PARSING"
                    end
                    break
                end
            until project.bufferLength == buffer:getPosition() or (buffer:getPosition() >= (project.currentChunk * project.chunkSize))
        end
    end
end
--#ENDREGION
--#REGION pings
function pings.sendSong(ID,currentChunk,isLastChunk,data)
    if not midiPlayer.instance then return end
    if not midiPlayer.instance.songs[ID] then
        midiPlayer.instance:newSong(ID,"")
        midiPlayer.instance.songs[ID].songChunks = {}
    end
    midiPlayer.instance.songs[ID].songChunks[currentChunk] = data
    if isLastChunk then
        local compressedSong = ""
        for _,chunk in ipairs(midiPlayer.instance.songs[ID].songChunks) do
            compressedSong = compressedSong .. chunk
        end
        midiPlayer.decompressProjects[ID] = midiPlayer.decompressProject:new(ID,compressedSong)
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
--#ENDREGION
--#ENDREGION
--#REGION host only
--#REGION setup
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
local localMode = config:load("localMode")
if localMode then
    midiPlayer.localMode = localMode
end
function events.tick()
    if midiPlayer.instance then
        for k,v in pairs(midiPlayer.instance.songs) do
            if v.loaded and (midiPlayer.songs[v.ID].state ~= "LOCAL_PROCESSED" and midiPlayer.songs[v.ID].state ~= "GLOBAL") then
                if midiPlayer.instance.songs[v.ID].localMode then
                    midiPlayer.songs[v.ID].state = "LOCAL_PROCESSED"
                else
                    midiPlayer.songs[v.ID].state = "GLOBAL"
                end
            end
        end
    end
end
--#ENDREGION
--#REGION action wheel
local uploadStateLookup = {
    LOCAL = function(name)
        return ":cross_mark:§c "
    end,
    COMPRESSING = function(name)
        local project = midiPlayer.compressProjects[name]
        local progress = 0
        if not project.hasGeneratedPatterns then
            progress = math.floor(((project.currentChunk * project.chunkSize) / project.bufferLength) * 25)
        elseif not project.hasReadPatterns then
            progress = 25 + math.floor(((project.currentChunk * project.chunkSize) / project.bufferLength) * 25)
        elseif not project.hasPurgedEmptys then
            progress = 50 + math.floor(((project.currentChunk * project.chunkSize) / project.patternIndexLength) * 5)
        elseif not project.hasGeneratedIndexString then
            local chunkSize = math.floor(project.chunkSize / 16)
            progress = 55 + math.floor(((project.currentChunk * chunkSize) / project.patternIndexLength) * 22)
        elseif not project.hasGeneratedOrderString then
            local chunkSize = math.floor(project.chunkSize / 16)
            progress = 77 + math.floor(((project.currentChunk * chunkSize) / #project.patternOrder) * 23)
        end
        return ":loading: :envelope:§e [" .. progress .. "%] "
    end,
    QUEUED = function(name)
        return ":0h:§7 "
    end,
    UPLOADING = function(name)
        local song = midiPlayer.songs[name]
        return ":loading: :www:§b [" .. math.floor((song.currentChunk / song.totalChunks) * 100) .. "%] "
    end,
    DECOMPRESSING = function(name)
        local project = midiPlayer.decompressProjects[name]
        local progress = math.floor(((project.currentChunk * project.chunkSize) / project.bufferLength) * 100)
        return ":loading: :folder_paper:§e [" .. progress .. "%] "
    end,
    PARSING = function(name)
        local project = midiPlayer.instance.midiParser.projects[name]
        local progress = math.floor(((project.currentChunk * project.chunkSize) / project.buffer:getLength()) * 100)
        return ":loading: :cd:§e [" .. progress .. "%] "
    end,
    GLOBAL = function(name)
        return ":checkmark:§a "
    end,
    LOCAL_PROCESSED = function(name)
        return ":folder:§e "
    end
}

local playStateLookup = {
    PLAYING = "§d:music2: ▶ ",
    PAUSED = "§d:music2: ⏸ "
}

local function generateSongSelector()
    local songTitle = "song selector \n"
    local selectedPage = math.floor((midiPlayer.selectedSong - 1) / midiPlayer.pageSize)
    for k,name in pairs(midiPlayer.songIndex) do
        local uploadState = midiPlayer.songs[name].state
        local playState
        if midiPlayer.instance and midiPlayer.instance.songs[name] then
            playState = midiPlayer.instance.songs[name].state
        end
        local stateIndicator = uploadStateLookup[uploadState](name)
        if playStateLookup[playState] then
            stateIndicator = playStateLookup[playState]
        end
        if string.len(name) > 40 then
            name = string.sub(name,0,40) .. "..."
        end
        local currentPage = math.floor((k - 1) / midiPlayer.pageSize)
        if currentPage == selectedPage then
            if k == midiPlayer.selectedSong then
                songTitle = songTitle .. "§r→ " .. stateIndicator .. "§r§n" .. name .. "\n§r"
            else
                songTitle = songTitle .. "   " .. stateIndicator .. name  .. "\n"
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
        midiPlayer.pingSize = math.max(0,midiPlayer.pingSize + (scroll * 5))
        config:save("pingSize",midiPlayer.pingSize)
        actions.pingSize:setTitle("ping size \n" .. tostring(midiPlayer.pingSize) .. " b/s")
    end)

actions.limitRoleback = midiPlayer.settings:newAction()
    :setTitle("ratelimit roleback \n" .. tostring(midiPlayer.limitRoleback) .. " pings")
    :setOnScroll(function(scroll) 
        midiPlayer.limitRoleback = math.max(0,midiPlayer.limitRoleback + (scroll))
        config:save("limitRoleback",midiPlayer.limitRoleback)
        actions.limitRoleback:setTitle("limit roleback \n" .. tostring(midiPlayer.limitRoleback) .. " pings")
    end)

actions.localMode = midiPlayer.settings:newAction()
    :setTitle("local mode")
    :setOnToggle(function(bool) 
        midiPlayer.localMode = bool
        config:save("localMode",midiPlayer.localMode)
    end)
    :setToggled(midiPlayer.localMode)

function midiPlayer:addMidiPlayer(page)
    midiPlayer.returnPage = page
    actions.midiPlayer = page:newAction()
        :setTitle("Midi Player\nERROR: Midi player avatar is not loaded")
end


function events.tick()
    local actionWheelOpen = action_wheel:isEnabled()
    local currentPage = action_wheel:getCurrentPage():getTitle()
    local selectedAction = action_wheel:getSelected()
    if actionWheelOpen and currentPage == "midiPlayerPage" and selectedAction == 3 then
        generateSongSelector()
    end
end
--#ENDREGION
--#REGION song setup
midiPlayer.song = {}
midiPlayer.song.__index = midiPlayer.song

function midiPlayer.song:new(name,rawData)    
    self = setmetatable({},midiPlayer.song)
    self.ID = name
    self.rawData = rawData
    self.state = "LOCAL"
    self.currentChunk = 0
    self.nameLength = string.len(name)
    self.pingSize = midiPlayer.pingSize
    return self
end
--#ENDREGION
--#REGION compress midi
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

local function reverse(tab)
    for i = 1, #tab/2, 1 do
        tab[i], tab[#tab-i+1] = tab[#tab-i+1], tab[i]
    end
    return tab
end


local function toBits(num,bits)
    local t = {} -- will contain the bits        
    for b = bits, 1, -1 do
        t[b] = math.fmod(num, 2)
        num = math.floor((num - t[b]) / 2)
    end
    return reverse(t)
end

function numToVarLengthInt(num)
    local numBits = math.max(1, select(2, math.frexp(num)))
    local numBytes = math.ceil(numBits / 7)
    local bits = toBits(num,numBits)
    for i = 1, (numBytes - 1) do
        i = (numBytes - i) * 7 + 1
        if i ~= 8 then 
            table.insert(bits,i,1)
        else   
            table.insert(bits,i,0)
        end
    end
    for i = 1, numBytes * 8 do
        i = (numBytes * 8 ) - i + 1
        if not bits[i] then
            if i % 8 ~= 0 then 
                bits[i] = 0
            else
                if numBytes ~= 1 then
                    bits[i] = 1
                else
                    bits[i] = 0
                end
            end
        end
    end
    local bitVal = 0
    local val = ""
    for i = 1, #bits do
        bitVal = bitVal + bits[i] * 2 ^ ((i - 1) % 8)
        if i % 8 == 0 then
            val = val .. string.char(bitVal)
            bitVal = 0
        end
    end
    return string.reverse(val)
end

midiPlayer.compressProject = {}
midiPlayer.compressProject.__index = midiPlayer.compressProject

function midiPlayer.compressProject:new(ID,decompressedData)
    self = setmetatable({},midiPlayer.compressProject)
    self.ID = ID
    self.patternIndex = {}
    self.patternIndexLength = nil
    self.existingPatterns = {}
    for i = 0,255 do
        table.insert(self.patternIndex,string.char(i))
        self.existingPatterns[string.char(i)] = #self.patternIndex
    end
    self.buffer = data:createBuffer()
    self.buffer:writeByteArray(decompressedData)
    self.buffer:setPosition(0)
    self.bufferLength = self.buffer:getLength()
    self.readBytes = ""
    self.patternCount = {}
    self.patternOrder = {}
    self.compressedData = ""
    self.patternIndexString = ""
    self.patternOrderString = ""
    self.currentChunk = 0
    self.chunkSize = 1000
    self.hasGeneratedPatterns = false
    self.hasReadPatterns = false
    self.hasPurgedEmptys = false
    self.hasGeneratedIndexString = false
    self.hasGeneratedOrderString = false
    return self
end

midiPlayer.compressProjects = {}

function midiPlayer.compressProject:remove()
    self.buffer:close()
    midiPlayer.compressProjects[self.ID] = nil
end

function events.tick()
    for _,project in pairs(midiPlayer.compressProjects) do
        local buffer = project.buffer
        project.currentChunk = project.currentChunk + 1
        if not project.hasGeneratedPatterns then
            repeat
                local readBye = buffer:readByteArray(1)
                local currentBytes = project.readBytes .. readBye
                if not project.existingPatterns[currentBytes] then
                    table.insert(project.patternIndex, currentBytes)
                    project.existingPatterns[currentBytes] = #project.patternIndex
                    project.readBytes = ""
                else
                    project.readBytes = currentBytes
                end
                if buffer:getPosition() == project.bufferLength then
                    table.insert(project.patternIndex, currentBytes)
                    project.existingPatterns[currentBytes] = #project.patternIndex
                end
                if buffer:getPosition() == project.bufferLength then
                    buffer:setPosition(0)
                    project.currentChunk = 0
                    project.readBytes = ""
                    for k,v in pairs(project.patternIndex) do
                        project.patternCount[v] = 0
                    end
                    project.hasGeneratedPatterns = true
                end
            until (buffer:getPosition() == project.bufferLength) or (buffer:getPosition() >= (project.currentChunk * project.chunkSize))
        elseif not project.hasReadPatterns then
            repeat
                local currentBytes = project.readBytes ..buffer:readByteArray(1)
                if not project.existingPatterns[currentBytes] then
                    project.patternCount[project.readBytes] = project.patternCount[project.readBytes] + 1
                    table.insert(project.patternOrder, project.existingPatterns[project.readBytes])
                    local bufferPos = buffer:getPosition()
                    if bufferPos ~= project.bufferLength then
                        buffer:setPosition(bufferPos - 1)
                    end
                    project.readBytes = ""
                else
                    project.readBytes = currentBytes
                end
                if buffer:getPosition() == project.bufferLength then
                    if project.readBytes ~= "" then
                        project.patternCount[currentBytes] = project.patternCount[currentBytes] + 1
                        table.insert(project.patternOrder, project.existingPatterns[currentBytes])
                    end
                    project.hasReadPatterns = true
                    project.currentChunk = 0
                    project.patternIndexLength = #project.patternIndex
                    for i = 0, 255 do
                        project.patternIndex[i] = nil
                    end
                end
            until (buffer:getPosition() == project.bufferLength) or (buffer:getPosition() >= (project.currentChunk * project.chunkSize))
        elseif not project.hasPurgedEmptys then
            for i = (project.currentChunk - 1) * project.chunkSize + 1,project.currentChunk * project.chunkSize do
                if i <= project.patternIndexLength then
                    if project.patternIndex[i] then
                        if project.patternCount[project.patternIndex[i]] == 0 then
                            project.patternIndex[i] = nil
                        end
                    end
                else
                    project.hasPurgedEmptys = true
                    project.currentChunk = 0
                    break
                end
            end
        elseif not project.hasGeneratedIndexString then
            local chunkSize = math.floor(project.chunkSize / 16)
            for i = (project.currentChunk - 1) * chunkSize + 1,project.currentChunk * chunkSize do
                if i <= project.patternIndexLength then
                    if project.patternIndex[i] then
                        local pattern = project.patternIndex[i]
                        project.patternIndexString = project.patternIndexString .. numToVarLengthInt(i) .. numToVarLengthInt(string.len(pattern)) .. pattern
                    end
                else
                    project.hasGeneratedIndexString = true
                    project.currentChunk = 0
                    break
                end
            end
        elseif not project.hasGeneratedOrderString then
            local chunkSize = math.floor(project.chunkSize / 16)
            for i = (project.currentChunk - 1) * chunkSize + 1,project.currentChunk * chunkSize do
                if i <= #project.patternOrder then
                    project.patternOrderString = project.patternOrderString .. numToVarLengthInt(project.patternOrder[i])
                else
                    project.hasGeneratedOrderString = true
                    local compressedData = numToVarLengthInt(string.len(project.patternIndexString)) .. project.patternIndexString .. project.patternOrderString
                    local song = midiPlayer.songs[project.ID]
                    table.insert(midiPlayer.pingQueue,song.ID)
                    song.compressedData = compressedData
                    song.totalChunks = math.ceil(string.len(compressedData) / midiPlayer.pingSize)
                    project:remove()
                    song.state = "QUEUED"
                    break
                end
            end
        end
    end
end
--#ENDREGION
--#REGION action wheel controls
function events.MOUSE_PRESS(key,state,bitmast)
    local actionWheelOpen = action_wheel:isEnabled()
    local currentPage = action_wheel:getCurrentPage():getTitle()
    local selectedAction = action_wheel:getSelected()
    if actionWheelOpen and currentPage == "midiPlayerPage" and selectedAction == 3 then
        if state == 1 then
            local selectedSongLocal = midiPlayer.songs[midiPlayer.songIndex[midiPlayer.selectedSong]]
            local selectedSongPinged = midiPlayer.instance.songs[midiPlayer.songIndex[midiPlayer.selectedSong]]
            if key == 0 then
                if midiPlayer.localMode then
                    if selectedSongLocal.state == "LOCAL" then
                        midiPlayer.instance:newSong(selectedSongLocal.ID,selectedSongLocal.rawData)
                        midiPlayer.instance.songs[selectedSongLocal.ID].localMode = true
                        midiPlayer.instance.songs[selectedSongLocal.ID]:load()
                        selectedSongLocal.state = "PARSING"
                    elseif selectedSongLocal.state == "LOCAL_PROCESSED" or selectedSongLocal.state == "GLOBAL" then
                        if selectedSongPinged.state == "STOPPED" or selectedSongPinged.state == "PAUSED" then
                            midiPlayer.instance.songs[selectedSongLocal.ID]:play()
                        elseif selectedSongPinged.state == "PLAYING" then
                            midiPlayer.instance.songs[selectedSongLocal.ID]:pause()
                        end
                    end
                else
                    if selectedSongLocal.state == "LOCAL" or selectedSongLocal.state == "LOCAL_PROCESSED" then
                        if selectedSongPinged then
                            selectedSongPinged:remove()
                        end
                        selectedSongLocal.pingSize = midiPlayer.pingSize
                        midiPlayer.compressProjects[selectedSongLocal.ID] = midiPlayer.compressProject:new(selectedSongLocal.ID,selectedSongLocal.rawData)
                        selectedSongLocal.state = "COMPRESSING"
                    elseif selectedSongLocal.state == "GLOBAL" then
                        if selectedSongPinged.state == "STOPPED" or selectedSongPinged.state == "PAUSED" then
                            pings.updateSong(selectedSongPinged.ID,1)
                        elseif selectedSongPinged.state == "PLAYING" then
                            pings.updateSong(selectedSongPinged.ID,2)
                        end
                    end
                end
            elseif key == 1 then
                if midiPlayer.instance.activeSong then
                    local state = midiPlayer.songs[midiPlayer.instance.activeSong].state
                    if midiPlayer.localMode then
                        if state == "GLOBAL" or state == "LOCAL_PROCESSED" then
                            midiPlayer.instance.songs[midiPlayer.instance.activeSong]:stop()
                        end
                    else
                        if state == "GLOBAL" or state == "LOCAL_PROCESSED" then
                            pings.updateSong(midiPlayer.instance.songs[midiPlayer.instance.activeSong].ID,0)
                        end
                    end
                end
            end
        end
    end
end
--#ENDREGION
--#REGION ping midi
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
        if midiPlayer.songs[queuedSong].state == "QUEUED" then
            midiPlayer.songs[queuedSong].state = "UPLOADING" 
        end
        local currentChunk = midiPlayer.songs[queuedSong].currentChunk
        local pingSize = midiPlayer.songs[queuedSong].pingSize - midiPlayer.songs[queuedSong].nameLength - 9
        local totalChunks = midiPlayer.songs[queuedSong].totalChunks
        local compressedData = midiPlayer.songs[queuedSong].compressedData
        local dataChunk = string.sub(compressedData,currentChunk * pingSize,((currentChunk + 1) * pingSize) - 1)
        local isLastChunk = currentChunk == totalChunks
        if isLastChunk then
            midiPlayer.songs[queuedSong].state = "DECOMPRESSING"
            table.remove(midiPlayer.pingQueue,1)
        else
            midiPlayer.songs[queuedSong].currentChunk = currentChunk + 1
        end
        pings.sendSong(queuedSong,currentChunk + 1,isLastChunk,dataChunk)
    end
end

return midiPlayer
--#ENDREGION