if not host:isHost() then return end

local midiPlayer = require("midiPlayerClient")
local mainPage = action_wheel:newPage("mainPage")
action_wheel:setPage(mainPage)

midiPlayer:addMidiPlayer(mainPage)
