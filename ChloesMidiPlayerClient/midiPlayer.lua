local midiPlayer = {
    page = action_wheel:newPage("midiPlayerPage"),
    returnPage = nil,
    directory = "ChloesMidiPlayer",
    hasFetchedMidis = false,
    midiAPI = world.avatarVars()["b0e11a12-eada-4f28-bb70-eb8903219fe5"],
    instance = nil,
    songs = {},
    selectedSong = 1,
    pageSize = 20
}

local actions = {}


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

local function getMidiData(instance)
    if not file:isDirectory(midiPlayer.directory) then
        file:mkdir(midiPlayer.directory)
        log('"'..midiPlayer.directory..'" folder has been created')
    end
    for k,fileName in pairs(file:list(midiPlayer.directory)) do
        local path = midiPlayer.directory.."/"..fileName
        local suffix = string.sub(fileName,-4,-1)
        local name = string.sub(fileName,1,-5)
        if suffix == ".mid" and (not instance.songs[name]) then
            local midiData = fast_read_byte_array(path)
            --log(readString(midiData))
            instance:newSong(name,midiData)
        end
    end
end

local function generateSongSelector()
    local songTitle = "song selector \n"
    local selectedPage = math.floor((midiPlayer.selectedSong - 1) / midiPlayer.pageSize)
    for k,v in pairs(midiPlayer.songs) do
        local currentPage = math.floor((k - 1) / midiPlayer.pageSize)
        if currentPage == selectedPage then
            if k == midiPlayer.selectedSong then
                songTitle = songTitle .. "§r→ "  .. v .. "\n"
            else
                songTitle = songTitle .. ":cross_mark: ".. "§c" .. v .. "\n"
            end
        end
    end
    local lastPage = math.floor((#midiPlayer.songs - 1) / midiPlayer.pageSize)
    songTitle = songTitle .. "§rpage " .. selectedPage + 1 .. " of " .. lastPage + 1
    actions.songs:setTitle(songTitle)
end

function events.MOUSE_PRESS(key,state,bitmast)
    local actionWheelOpen = action_wheel:isEnabled()
    local currentPage = action_wheel:getCurrentPage():getTitle()
    local selectedAction = action_wheel:getSelected()
    if actionWheelOpen and currentPage == "midiPlayerPage" and selectedAction == 3 then
        if state == 1 then
            if key == 0 then
                local selectedSong = midiPlayer.instance.songs[midiPlayer.songs[midiPlayer.selectedSong]]
                if selectedSong.state == "STOPPED" or selectedSong.state == "PAUSED" then
                    selectedSong:play()
                elseif selectedSong.state == "PLAYING" then
                    selectedSong:pause()
                end
            elseif key == 1 then
                if midiPlayer.instance.activeSong then
                    midiPlayer.instance.songs[midiPlayer.instance.activeSong]:stop()
                end
            end
        end
    end
end

actions.back = midiPlayer.page:newAction()
    :setTitle("back")
    :setOnLeftClick(
        function()
            if midiPlayer.returnPage then
                action_wheel:setPage(midiPlayer.returnPage)
            end
        end)
actions.pingRate = midiPlayer.page:newAction()
    :setTitle("ping rate")

actions.songs = midiPlayer.page:newAction()
    :setTitle("songs")
    :setOnScroll(function(scroll)
        midiPlayer.selectedSong = math.clamp(midiPlayer.selectedSong - scroll,1,#midiPlayer.songs)
        generateSongSelector()
    end)

function events.tick()
    if midiPlayer.midiAPI and (not midiPlayer.hasFetchedMidis) then
        local player = world.getEntity(avatar:getUUID())
        midiPlayer.instance = midiPlayer.midiAPI.newInstance(player:getName(),player)
        getMidiData(midiPlayer.instance)
        midiPlayer.hasFetchedMidis = true
        actions.midiPlayer:setTitle("Midi Player")
            :setOnLeftClick(function() action_wheel:setPage(midiPlayer.page) end)
        
        for k,v in pairs(midiPlayer.instance.songs) do
            table.insert(midiPlayer.songs,k)
        end
        table.sort(midiPlayer.songs)
        generateSongSelector()
    end
end

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


return midiPlayer