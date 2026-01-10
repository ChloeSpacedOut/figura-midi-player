--#REGION global
--#REGION setup
local playerID = {}
playerID[1],playerID[2],playerID[3],playerID[4] = client.uuidToIntArray(client:getViewer():getUUID())

local playerConfig = {
    midiAvatar = "b0e11a12-eada-4f28-bb70-eb8903219fe5",
    directory = "curated_midis/mids"
}

local midiPlayer = {
    page = action_wheel:newPage("midiPlayerPage"),
    settings = action_wheel:newPage("midiPlayerSettings"),
    returnPage = nil,
    hasMadeInstance = false,
    midiAPI = nil,
    avatarID = {},
    instance = nil,
    songs = {},
    directories = {},
    currentDirectory = playerConfig.directory,
    songTree = {},
    pingQueue = {},
    pageSize = 20,
    pingSize = 450,
    limitRoleback = 5,
    localMode = false,
    activeSong = nil,
    isAltModPressed = false,
    isModPressed = false
}
--#ENDREGION
--#REGION utils
local function padNumber(num, length)
    local string = tostring(num)
    while #string < length do
        string = "0" .. string
    end
    return string
end

local function msToTimeString(val)
    local seconds = padNumber(math.floor(val/1000) % 60,2)
    local minutes = padNumber(math.floor(val/(1000 * 60)) % 60,2)


    return minutes .. ":" .. seconds
end
--#ENDREGION
--#REGION midi player cloud setup
midiPlayer.avatarID[1],midiPlayer.avatarID[2],midiPlayer.avatarID[3],midiPlayer.avatarID[4] = client.uuidToIntArray(playerConfig.midiAvatar)

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
        midiPlayer.midiAPI = world.avatarVars()[playerConfig.midiAvatar]
        if midiPlayer.midiAPI and midiPlayer.midiAPI.newInstance then
            local player = world.getEntity(avatar:getUUID())
            midiPlayer.instance = midiPlayer.midiAPI.newInstance(player:getName(),player)
            midiPlayer.hasMadeInstance = true
            if host:isHost() then
                actions.midiPlayer:setTitle("Midi Player")
                    :setOnLeftClick(function() action_wheel:setPage(midiPlayer.page) end)
                    :setItem("minecraft:jukebox")
            end
        end
    end
end
--#ENDREGION
--#REGION song display
local displayParent = models:newPart("midiPlayerDisplay")
local displayCamera = displayParent:newPart("displayCamera","CAMERA")
displayParent:setPos(0,45,0)
local display = displayCamera:newText("songDisplay")
display:setText("")
    :setBackground(true)
    :setAlignment("CENTER")
    :setScale(0.25)
    :setPos(0,4,0)
    :setBackgroundColor(0,0,0,1)

function events.tick()
    local songName = midiPlayer.activeSong
    if songName and string.len(songName) > 40 then
        songName = string.sub(songName,0,40) .. "..."
    end
    if midiPlayer.instance then
        if midiPlayer.instance.activeSong or midiPlayer.instance.songs[midiPlayer.activeSong] then
            local song = midiPlayer.instance.songs[midiPlayer.activeSong]
            local playingType = "§d"
            if host:isHost() then
                if midiPlayer.songs[midiPlayer.activeSong].state == "LOCAL_PROCESSED" then
                    playingType = "§e"
                end
            end
            local playing
            if song.state == "PLAYING" then
                playing = "\n" .. playingType .. ":music2: playing ▶ ["
            elseif song.state == "PAUSED" then
                playing = "\n" .. playingType .. ":music2: paused ⏸ ["
            elseif song.state == "STOPPED" then
                midiPlayer.activeSong = nil
                display:setText()
                    :setVisible(false)
                return
            end
            local playBar = "\n§r"
            local playProgress = math.ceil((song.time / song.length) * 25)
            for i = 1, 25 do
                if i >= playProgress then 
                    playBar = playBar .. "§7█"
                else
                    playBar = playBar .. playingType .. "█"
                end
            end
            local text = songName .. playing .. msToTimeString(song.time) .. "/" .. msToTimeString(song.length) .. "] " .. playBar
            display:setText(text)
                :setVisible(true)
        elseif midiPlayer.activeSong then
            if midiPlayer.instance:getPermissionLevel() ~= "MAX" then
                local text = songName .. "\n§b:music2: playing ▶" .. "\n§cMidi player avatar not set to MAX perm so could not play\nSet 'Midi Player Cloud' to MAX in 'disconnected avatars'"
                display:setText(text)
                    :setVisible(true)
            else
                local text = songName .. "\n§b:music2: playing ▶" .. "\n§cSong not received on client so could not play"
                display:setText(text)
                    :setVisible(true)
            end
        else
            display:setText()
                :setVisible(false)
        end
    else
        if midiPlayer.activeSong then
            local text = songName .. "\n§b:music2: playing ▶" .. "\n§cMidi player avatar not loaded so song could not play\nSet 'Midi Player Cloud' to MAX in 'disconnected avatars'"
            display:setText(text)
                :setVisible(true)
        else
            display:setText()
                :setVisible(false)
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
    if midiPlayer.instance:getPermissionLevel() ~= "MAX" then return end
    if (not midiPlayer.instance.songs[ID]) or (not midiPlayer.instance.songs[ID].songChunks) then
        if currentChunk ~= 1 then return end
        midiPlayer.instance:newSong(ID,"")
        midiPlayer.instance.songs[ID].songChunks = {}
    end
    midiPlayer.instance.songs[ID].songChunks[currentChunk] = data -- THIS CAN ERROR 
    if isLastChunk then
        local compressedSong = ""
        for _,chunk in ipairs(midiPlayer.instance.songs[ID].songChunks) do
            compressedSong = compressedSong .. chunk
        end
        midiPlayer.instance.songs[ID].songChunks = nil
        midiPlayer.decompressProjects[ID] = midiPlayer.decompressProject:new(ID,compressedSong)
    end
end

function pings.updateSong(ID,action)
    if action == 1 then
        if midiPlayer.instance and midiPlayer.instance:getPermissionLevel() == "MAX" and midiPlayer.instance.songs[ID] then
            midiPlayer.instance.songs[ID]:play()
        end
        midiPlayer.activeSong = ID
    elseif action == 2 then
        if midiPlayer.instance and midiPlayer.instance:getPermissionLevel() == "MAX" and midiPlayer.instance.songs[ID] then
            midiPlayer.instance.songs[ID]:pause()
        end
        midiPlayer.activeSong = ID
    elseif action == 0 then
        if midiPlayer.instance and midiPlayer.instance:getPermissionLevel() == "MAX" and midiPlayer.instance.songs[ID] then
            midiPlayer.instance.songs[ID]:stop()
        end
        midiPlayer.activeSong = nil
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
local midiPlayerHead = models:newPart("midiPlayerHead","Skull")
local emojiHeadParent = midiPlayerHead:newPart("emojiHeadParent")
local emojiHead = emojiHeadParent:newText("emojiHead")
midiPlayerHead:setScale(1.5)
    :setRot(32, -45, 0)
    :setPos(10, 10, 0)
local pivotOffset = vec(-4,-3.5,0)
emojiHeadParent:setPos(pivotOffset)
emojiHead:setPos(-pivotOffset)
local function getEmojiHead(emoji,rot)
    return world.newItem([=[minecraft:player_head{display:{Name:'{"text":"]=].."emoji_"..rot.."_"..emoji..[=["}'},SkullOwner:{Id:[I;]=]..playerID[1]..","..playerID[2]..","..playerID[3]..","..playerID[4]..[=[]}}]=])
end

function events.skull_render(delta,blockstate,itemstack,entity,string)
    if (not blockstate) and (not entity) and string == "OTHER" then
        local stringData = itemstack:getName()
        if string.sub(stringData,0,5) == "emoji" then
            local rot = string.sub(stringData,7,9)
            emojiHead:setText(":" .. string.sub(stringData,11,-1) .. ":")
            emojiHeadParent:setRot(vec(0,0,tonumber(rot)))
        else
            emojiHead:setText()
        end
    else
        emojiHead:setText()
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
        if not project then return ":loading: :folder_paper:§e " end
        local progress = math.floor(((project.currentChunk * project.chunkSize) / project.bufferLength) * 100)
        return ":loading: :folder_paper:§e [" .. progress .. "%] "
    end,
    PARSING = function(name)
        if not midiPlayer.instance.songs[name] then return ":loading: :cd:§e " end
        local progress = math.floor(midiPlayer.instance.songs[name].loadProgress * 100)
        return ":loading: :cd:§e [" .. progress .. "%] "
    end,
    GLOBAL = function(name)
        return ":checkmark:§a "
    end,
    LOCAL_PROCESSED = function(name)
        return ":paper:§e "
    end
}

local playStateLookup = {
    PLAYING = function(name,colour)
        return colour .. ":music2: ▶ [" .. msToTimeString(midiPlayer.instance.songs[name].time) .. "/" .. msToTimeString(midiPlayer.instance.songs[name].length) .. "] "
    end,
    PAUSED = function(name,colour)
        return colour .. ":music2: ⏸ [" .. msToTimeString(midiPlayer.instance.songs[name].time) .. "/" .. msToTimeString(midiPlayer.instance.songs[name].length) .. "] "
    end
}

local function generateSongSelector()
    
    local directory = midiPlayer.directories[midiPlayer.currentDirectory]
    local folder = directory.ID
    if string.len(folder) > 45 then
        folder =  "..." .. string.sub(folder,-45,-1)
    end
    local songTitle = "§lsong selector\n§7" .. folder .. "\n"
    local selectedPage = math.floor((directory.selectedIndex - 1) / midiPlayer.pageSize)
    local numFolders = #directory.childrenIndex
    local numSongs = #directory.songIndex
    local numIndex = numFolders + numSongs
    for k,childDirectory in pairs(directory.childrenIndex) do
        local currentPage = math.floor((k - 1) / midiPlayer.pageSize)
        if currentPage == selectedPage then
            if k == directory.selectedIndex then
                songTitle = songTitle .. "§r→ :folder: §r§n" .. childDirectory.name .. "\n"
            else
                songTitle = songTitle .. "§r   :folder: §e" .. childDirectory.name .. "\n"
            end
        end
        --log(childDirectory.name)
    end
    
    for k,name in pairs(directory.songIndex) do
        local uploadState = midiPlayer.songs[name].state
        local playState
        if midiPlayer.instance and midiPlayer.instance.songs[name] then
            playState = midiPlayer.instance.songs[name].state
        end
        
        local localState = midiPlayer.songs[name].state
        local colour
        if localState == "GLOBAL" then
            colour = "§d"
        elseif localState == "LOCAL_PROCESSED" then
            colour = "§e"
        end
        local stateIndicator = uploadStateLookup[uploadState](name)
        if playStateLookup[playState] then
            stateIndicator = playStateLookup[playState](name,colour)
        end
        if string.len(name) > 40 then
            name = string.sub(name,0,40) .. "..."
        end
        local currentPage = math.floor((k + numFolders - 1) / midiPlayer.pageSize)
        if currentPage == selectedPage then
            if (k + numFolders) == directory.selectedIndex then
                songTitle = songTitle .. "§r→ " .. stateIndicator .. "§r§n" .. name .. "\n"
            else
                songTitle = songTitle .. "§r   " .. stateIndicator .. name  .. "\n"
            end
        end
    end
    local lastPage = math.floor((#directory.songIndex - 1) / midiPlayer.pageSize)
    songTitle = songTitle .. "§rpage " .. selectedPage + 1 .. " of " .. lastPage + 1
    actions.songs:setTitle(songTitle)
end

actions.back = midiPlayer.page:newAction()
    :setTitle("back")
    :setItem(getEmojiHead("downvote","090"))
    :setColor(vectors.hexToRGB("CE9119"))
    :setHoverColor(vectors.hexToRGB("FFB727"))
    :setOnLeftClick(function()
        if midiPlayer.returnPage then
            action_wheel:setPage(midiPlayer.returnPage)
        end
    end)
actions.settings = midiPlayer.page:newAction()
    :setTitle("settings")
    :setItem(getEmojiHead("wrench","000"))
    :setColor(vectors.hexToRGB("3F3F3F"))
    :setHoverColor(vectors.hexToRGB("525252"))
    :setOnLeftClick(function()
        action_wheel:setPage(midiPlayer.settings)
    end)

actions.songs = midiPlayer.page:newAction()
    :setTitle("songs")
    :setItem(getEmojiHead("music2","000"))
    :setColor(vectors.hexToRGB("371B44"))
    :setHoverColor(vectors.hexToRGB("371B44"))
    :setOnScroll(function(scroll)
        local directory = midiPlayer.directories[midiPlayer.currentDirectory]
        local scrollMod = 1
--[[         if midiPlayer.isAltModPressed then
            scrollMod = midiPlayer.pageSize
        end ]]
        directory.selectedIndex = math.clamp(directory.selectedIndex - scroll * scrollMod,1,#directory.childrenIndex + #directory.songIndex)
        generateSongSelector()
    end)

actions.settingsBack = midiPlayer.settings:newAction()
    :setTitle("back")
    :setItem(getEmojiHead("downvote","090"))
    :setColor(vectors.hexToRGB("CE9119"))
    :setHoverColor(vectors.hexToRGB("FFB727"))
    :setOnLeftClick(function()
        action_wheel:setPage(midiPlayer.page)
    end)

actions.pingSize = midiPlayer.settings:newAction()
    :setTitle("ping size \n" .. tostring(midiPlayer.pingSize) .. " b/s")
    :setItem(getEmojiHead("ping3","000"))
    :setColor(vectors.hexToRGB("1B4429"))
    :setHoverColor(vectors.hexToRGB("1B4429"))
    :setOnScroll(function(scroll) 
        midiPlayer.pingSize = math.max(0,midiPlayer.pingSize + (scroll * 5))
        config:save("pingSize",midiPlayer.pingSize)
        actions.pingSize:setTitle("ping size \n" .. tostring(midiPlayer.pingSize) .. " b/s")
    end)

actions.limitRoleback = midiPlayer.settings:newAction()
    :setTitle("ratelimit roleback \n" .. tostring(midiPlayer.limitRoleback) .. " pings")
    :setItem(getEmojiHead("alarm_clock","000"))
    :setColor(vectors.hexToRGB("441B1B"))
    :setHoverColor(vectors.hexToRGB("441B1B"))
    :setOnScroll(function(scroll) 
        midiPlayer.limitRoleback = math.max(0,midiPlayer.limitRoleback + (scroll))
        config:save("limitRoleback",midiPlayer.limitRoleback)
        actions.limitRoleback:setTitle("ratelimit roleback \n" .. tostring(midiPlayer.limitRoleback) .. " pings")
    end)

actions.localMode = midiPlayer.settings:newAction()
    :setTitle("toggle local mode")
    :setOnToggle(function(bool) 
        midiPlayer.localMode = bool
        config:save("localMode",midiPlayer.localMode)
        if bool then
            actions.localMode:setItem(getEmojiHead("folder","000"))
            actions.localMode:setHoverColor(vectors.hexToRGB("635122"))
        else
            actions.localMode:setItem(getEmojiHead("globe","000"))
            actions.localMode:setHoverColor(vectors.hexToRGB("234463"))
        end
    end)
    :setToggled(midiPlayer.localMode)
    :setColor(vectors.hexToRGB("1B3044"))
    :setToggleColor(vectors.hexToRGB("44391B"))

if midiPlayer.localMode then
    actions.localMode:setItem(getEmojiHead("folder","000"))
    actions.localMode:setHoverColor(vectors.hexToRGB("635122"))
else
    actions.localMode:setItem(getEmojiHead("globe","000"))
    actions.localMode:setHoverColor(vectors.hexToRGB("234463"))
end

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

function midiPlayer.song:new(name,path)  
    self = setmetatable({},midiPlayer.song)
    self.ID = name
    self.path = path
    self.rawData = nil
    self.state = "LOCAL"
    self.currentChunk = 0
    self.nameLength = string.len(name)
    self.pingSize = midiPlayer.pingSize
    return self
end

midiPlayer.directory = {}
midiPlayer.directory.__index = midiPlayer.directory

function midiPlayer.directory:new(directory,name,parent)
    self = setmetatable({},midiPlayer.directory)
    self.ID = directory
    self.name = name
    self.parent = parent
    self.childrenIndex = {}
    self.songIndex = {}
    self.selectedIndex = 1
    return self
end

local function fast_read_byte_array(path)
    local stream = file:openReadStream(path)
    local future = stream:readAsync()
    repeat until future:isDone()
    stream:close()
    return future:getValue()--[[@as string]]
end

local function getMidiData(directory)
    for k,fileName in pairs(file:list(directory.ID)) do
        local path = directory.ID.."/"..fileName
        local suffix = string.sub(fileName,-4,-1)
        local name = string.sub(fileName,1,-5)
        
        if not path:find("%.[^.]-$") then
            midiPlayer.directories[path] = midiPlayer.directory:new(path,fileName,directory)
            table.insert(directory.childrenIndex,midiPlayer.directories[path])
            getMidiData(midiPlayer.directories[path])
        end
        if suffix == ".mid" and (not midiPlayer.songs[name]) then
            midiPlayer.songs[name] = midiPlayer.song:new(name,path)
            table.insert(directory.songIndex,name)
        end
    end
end

if not playerConfig.directory:find("%.[^.]-$") then
    file:mkdir(playerConfig.directory)
end

midiPlayer.directories[playerConfig.directory] = midiPlayer.directory:new(playerConfig.directory,playerConfig.directory)
getMidiData(midiPlayer.directories[playerConfig.directory])
--[[ table.sort(midiPlayer.songIndex)
log(midiPlayer.songIndex) ]]
generateSongSelector()

--#ENDREGION
--#REGION compress midi

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

local cache = {}
function numToVarLengthInt(num)
    if cache[num] then return cache[num] end
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
    cache[num] = string.reverse(val)
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
    self.chunkSize = 1500
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
                    local pingSize = song.pingSize - song.nameLength - 9
                    song.totalChunks = math.floor(string.len(compressedData) / pingSize)
                    project:remove()
                    song.state = "QUEUED"
                    cache = {}
                    break
                end
            end
        end
    end
end
--#ENDREGION
--#REGION action wheel controls
function events.MOUSE_PRESS(key,state)
    local actionWheelOpen = action_wheel:isEnabled()
    local currentPage = action_wheel:getCurrentPage():getTitle()
    local selectedAction = action_wheel:getSelected()
    if actionWheelOpen and currentPage == "midiPlayerPage" and selectedAction == 3 then
        if state == 1 then
            local directory = midiPlayer.directories[midiPlayer.currentDirectory]
            local songIndex = directory.selectedIndex - #directory.childrenIndex
            local selectedSongLocal = midiPlayer.songs[directory.songIndex[songIndex]]
            local selectedSongPinged = midiPlayer.instance.songs[directory.songIndex[songIndex]]
            if key == 0 then
                if directory.selectedIndex <= #directory.childrenIndex then
                    midiPlayer.currentDirectory = directory.childrenIndex[directory.selectedIndex].ID
                else
                    if not selectedSongLocal then return end
                    local localMode = midiPlayer.localMode
                    if midiPlayer.isAltModPressed then
                        localMode = not localMode
                    end
                    if localMode then
                        if selectedSongLocal.state == "LOCAL" then
                            selectedSongLocal.rawData = fast_read_byte_array(selectedSongLocal.path)
                            midiPlayer.instance:newSong(selectedSongLocal.ID, selectedSongLocal.rawData)
                            midiPlayer.instance.songs[selectedSongLocal.ID].localMode = true
                            midiPlayer.instance.songs[selectedSongLocal.ID]:load()
                            selectedSongLocal.state = "PARSING"
                        elseif selectedSongLocal.state == "LOCAL_PROCESSED" or selectedSongLocal.state == "GLOBAL" then
                            if selectedSongPinged.state == "STOPPED" or selectedSongPinged.state == "PAUSED" then
                                midiPlayer.instance.songs[selectedSongLocal.ID]:play()
                                midiPlayer.activeSong = selectedSongLocal.ID
                            elseif selectedSongPinged.state == "PLAYING" then
                                midiPlayer.instance.songs[selectedSongLocal.ID]:pause()
                                midiPlayer.activeSong = selectedSongLocal.ID
                            end
                        end
                    else
                        if selectedSongLocal.state == "LOCAL" then
                            if selectedSongPinged then
                                selectedSongPinged:remove()
                            end
                            selectedSongLocal.pingSize = midiPlayer.pingSize
                            selectedSongLocal.rawData = fast_read_byte_array(selectedSongLocal.path)
                            midiPlayer.compressProjects[selectedSongLocal.ID] = midiPlayer.compressProject:new(selectedSongLocal.ID, selectedSongLocal.rawData)
                            selectedSongLocal.state = "COMPRESSING"
                        elseif selectedSongLocal.state == "GLOBAL" then
                            if selectedSongPinged.state == "STOPPED" or selectedSongPinged.state == "PAUSED" then
                                pings.updateSong(selectedSongPinged.ID, 1)
                            elseif selectedSongPinged.state == "PLAYING" then
                                pings.updateSong(selectedSongPinged.ID, 2)
                            end
                        elseif selectedSongLocal.state == "LOCAL_PROCESSED" then
                            if selectedSongPinged.state == "STOPPED" or selectedSongPinged.state == "PAUSED" then
                                midiPlayer.instance.songs[selectedSongLocal.ID]:play()
                                midiPlayer.activeSong = selectedSongLocal.ID
                            elseif selectedSongPinged.state == "PLAYING" then
                                midiPlayer.instance.songs[selectedSongLocal.ID]:pause()
                                midiPlayer.activeSong = selectedSongLocal.ID
                            end
                        end
                    end
                end
            elseif key == 1 then
                if midiPlayer.isAltModPressed and (directory.selectedIndex > #directory.childrenIndex) then
                    if not selectedSongLocal then return end
                    local songID = directory.songIndex[songIndex]
                    if midiPlayer.compressProjects[songID] then
                        midiPlayer.compressProjects[songID]:remove()
                    end
                    if midiPlayer.decompressProjects[songID] then
                        midiPlayer.decompressProjects[songID]:remove()
                    end
                    if midiPlayer.instance.songs[songID] then
                        midiPlayer.instance.songs[songID]:remove()
                    end
                    midiPlayer.instance.songs[songID] = nil
                    midiPlayer.songs[songID].state = "LOCAL"
                    midiPlayer.songs[songID].currentChunk = 0
                    for index, song in pairs(midiPlayer.pingQueue) do
                        if song == songID then
                            table.remove(midiPlayer.pingQueue, index)
                        end
                    end
                    if midiPlayer.activeSong == songID then
                        midiPlayer.activeSong = nil
                    end
                elseif midiPlayer.isModPressed then
                    if directory.parent then
                        midiPlayer.currentDirectory = directory.parent.ID
                    end
                else
                    if not selectedSongLocal then return end
                    if midiPlayer.instance.activeSong then
                        local state = midiPlayer.songs[midiPlayer.instance.activeSong].state
                        if midiPlayer.localMode then
                            if state == "GLOBAL" or state == "LOCAL_PROCESSED" then
                                midiPlayer.instance.songs[midiPlayer.instance.activeSong]:stop()
                                midiPlayer.activeSong = nil
                            end
                        else
                            if state == "GLOBAL" or state == "LOCAL_PROCESSED" then
                                pings.updateSong(midiPlayer.instance.songs[midiPlayer.instance.activeSong].ID, 0)
                            end
                        end
                    end
                end
            end
        end
    end
end

function events.KEY_PRESS(key,state)
    local actionWheelOpen = action_wheel:isEnabled()
    local currentPage = action_wheel:getCurrentPage():getTitle()
    local selectedAction = action_wheel:getSelected()
    if actionWheelOpen and currentPage == "midiPlayerPage" and selectedAction == 3 then
        if key == 340 then
            if state == 1 or state == 2 then
                midiPlayer.isModPressed = true
                return true
            elseif state == 0 then
                midiPlayer.isModPressed = false
            end
        elseif key == 341 then
            if state == 1 or state == 2 then
                midiPlayer.isAltModPressed = true
                return true
            elseif state == 0 then
                midiPlayer.isAltModPressed = false
            end
        end
    end
    --log(key,state)
    --return true
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
            midiPlayer.songs[queuedSong].compressedData = nil
        else
            midiPlayer.songs[queuedSong].currentChunk = currentChunk + 1
        end
        pings.sendSong(queuedSong,currentChunk + 1,isLastChunk,dataChunk)
    end
end

return midiPlayer
--#ENDREGION