-- todo
--[[ 
- add song setTime (in quater notes)
- add song getTime (in quater notes)
- test pause
 ]]
local instance



local hasFetchedMidis = false
function events.tick()
    
end

function events.render()
    if instance then
        instance:updatePlayer()
    end
end

function events.tick()
    if instance then
        instance:updateParser()
    end
end

local midiPlayer = require("midiPlayer")
local mainPage = action_wheel:newPage("mainPage")
action_wheel:setPage(mainPage)

midiPlayer:addMidiPlayer(mainPage)
