-- todo
--[[ 
- add song setTime (in quater notes)
- add song getTime (in quater notes)
- add channel volume
- channel pitch
- test pause
- set ping limit being bellow size of name bytes + ping name bytes must be considered
- importing song stored in avatar
- song info page (length, compression ratio, etc)
- check for playing song when song isn't pinged, or parsing song when song is incomplete
- find the buffers that aren't closing
- fix note sounds remaining after a song ends and a new song is played
- Crouch interactive volume slider with scroll
- Return if player is trusted
- Set parse speed
- Return amount parsed so sandboxed
- check if notes playing on top of themselves should cancle out the previous note. If not, give notes a random ID, and have an index of all the notes to random IDs
- move midi parser to insance, kill all parse projects if instance stops existing (this is the buffer leak issue)
- lower pitch notes should sustain for longer than they currently do (listen to hall of the mountain king)
- function to just get all the sounds in the midi player cloud
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
