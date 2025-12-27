-- todo
--[[ 
- add song setTime (in quater notes)
- add song getTime (in quater notes)
- add channel volume
- channel pitch
- test pause
 ]]
local instance



local hasFetchedMidis = false
function events.tick()
    
end

if not host:isHost() then return end

local midiPlayer = require("midiPlayer")
local mainPage = action_wheel:newPage("mainPage")
action_wheel:setPage(mainPage)

midiPlayer:addMidiPlayer(mainPage)
