local midiAPI = world.avatarVars()["b0e11a12-eada-4f28-bb70-eb8903219fe5"]
local directory = "ChloesMidiPlayer"
local instance

local function fast_read_byte_array(path)
    local stream = file:openReadStream(path)
    local future = stream:readAsync()
    repeat until future:isDone()
    return future:getValue()--[[@as string]]
end

local function getMidiData(instance)
    if not file:isDirectory(directory) then
        file:mkdir(directory)
        log('"'..directory..'" folder has been created')
    end
    for k,fileName in pairs(file:list(directory)) do
        local path = directory.."/"..fileName
        local suffix = string.sub(fileName,-4,-1)
        local name = string.sub(fileName,1,-5)
        if suffix == ".mid" and (not instance.songs[name]) then
            local midiData = fast_read_byte_array(path)
            instance:addSong(name,midiData)
        end
    end
end

local hasFetchedMidis = false
function events.tick()
    if midiAPI and (not hasFetchedMidis) then
        instance = midiAPI.newInstance()
        getMidiData(instance)
        hasFetchedMidis = true
        instance.songs.spire:play()
        log(instance)
    end
end

function events.render()
    if instance then
        instance:render()
    end
end