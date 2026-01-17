if not host:isHost() then return end

local mainPage = action_wheel:newPage("mainPage")
action_wheel:setPage(mainPage)

local midiPlayer = require("midiPlayerClient")
midiPlayer:addMidiPlayer(mainPage)
