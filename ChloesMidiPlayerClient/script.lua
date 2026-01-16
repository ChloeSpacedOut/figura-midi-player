-- todo
--[[ 
- set ping limit being bellow size of name bytes + ping name bytes must be considered
- importing song stored in avatar
- song info page (length, compression ratio, etc)
- find the buffers that aren't closing
- Set parse speed
- check if notes playing on top of themselves should cancle out the previous note. If not, give notes a random ID, and have an index of all the notes to random IDs
- move midi parser to insance, kill all parse projects if instance stops existing (this is the buffer leak issue)
- function to just get all the sounds in the midi player cloud
- use just pos as target instead of a task
- check killing instance kills notes
- consider case where player exits render distance then comes back
- midi player height offset
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
