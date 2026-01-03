-- todo
--[[ 
- add song setTime (in quater notes)
- add song getTime (in quater notes)
- add channel volume
- channel pitch
- test pause
- clear channels at the start of a new song
- check if all channels have ended before song end
- set ping limit being bellow size of name bytes + ping name bytes must be considered
- check why desyncTest and thom errors
 ]]
local instance



local hasFetchedMidis = false
function events.tick()
    
end

if not host:isHost() then return end

local midiPlayer = require("midiPlayerClient")
local mainPage = action_wheel:newPage("mainPage")
action_wheel:setPage(mainPage)

midiPlayer:addMidiPlayer(mainPage)
